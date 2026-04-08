use serde::{Deserialize, Serialize};
use sysinfo::{Disks, Networks, System};
use tokio::time::{Duration, interval};
use tracing::debug;

use crate::ipc::{AppState, Event};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct SysmonSnapshot {
    pub cpu: CpuInfo,
    pub memory: MemInfo,
    pub network: Vec<NetIface>,
    pub disks: Vec<DiskInfo>,
    pub processes: Vec<ProcessInfo>,
    pub uptime_secs: u64,
    pub load_avg: [f64; 3],
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct CpuInfo {
    pub usage_percent: f32,
    pub per_core: Vec<f32>,
    pub freq_mhz: u64,
    pub brand: String,
    pub core_count: usize,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct MemInfo {
    pub total_kb: u64,
    pub used_kb: u64,
    pub available_kb: u64,
    pub swap_total_kb: u64,
    pub swap_used_kb: u64,
    pub used_percent: f32,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct NetIface {
    pub name: String,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
    pub rx_rate_bps: u64,
    pub tx_rate_bps: u64,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct DiskInfo {
    pub name: String,
    pub mount: String,
    pub total_kb: u64,
    pub used_kb: u64,
    pub used_percent: f32,
    pub fs_type: String,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct ProcessInfo {
    pub pid: u32,
    pub name: String,
    pub cpu_percent: f32,
    pub mem_kb: u64,
    pub status: String,
}

pub async fn worker(state: AppState) {
    let mut sys = System::new_all();
    let mut networks = Networks::new_with_refreshed_list();
    let mut disks = Disks::new_with_refreshed_list();
    let mut ticker = interval(Duration::from_secs(2));

    loop {
        ticker.tick().await;
        sys.refresh_all();
        networks.refresh_list();
        disks.refresh_list();

        let snap = build_snapshot(&sys, &networks, &disks);
        debug!("sysmon: cpu={:.1}% mem={:.1}%", snap.cpu.usage_percent, snap.memory.used_percent);

        *state.inner.sysmon.write().await = snap;
        state.emit(Event::SysmonUpdated);
    }
}

fn build_snapshot(sys: &System, networks: &Networks, disks: &Disks) -> SysmonSnapshot {
    let cpus = sys.cpus();
    let usage = cpus.iter().map(|c| c.cpu_usage()).sum::<f32>() / cpus.len() as f32;

    let cpu = CpuInfo {
        usage_percent: usage,
        per_core: cpus.iter().map(|c| c.cpu_usage()).collect(),
        freq_mhz: cpus.first().map(|c| c.frequency()).unwrap_or(0),
        brand: cpus.first().map(|c| c.brand().to_string()).unwrap_or_default(),
        core_count: cpus.len(),
    };

    let mem = MemInfo {
        total_kb: sys.total_memory() / 1024,
        used_kb: sys.used_memory() / 1024,
        available_kb: sys.available_memory() / 1024,
        swap_total_kb: sys.total_swap() / 1024,
        swap_used_kb: sys.used_swap() / 1024,
        used_percent: sys.used_memory() as f32 / sys.total_memory() as f32 * 100.0,
    };

    let network: Vec<NetIface> = networks
        .iter()
        .map(|(name, data)| NetIface {
            name: name.clone(),
            rx_bytes: data.total_received(),
            tx_bytes: data.total_transmitted(),
            rx_rate_bps: data.received(),
            tx_rate_bps: data.transmitted(),
        })
        .filter(|n| !n.name.starts_with("lo"))
        .collect();

    let disk_list: Vec<DiskInfo> = disks
        .iter()
        .map(|d| DiskInfo {
            name: d.name().to_string_lossy().to_string(),
            mount: d.mount_point().to_string_lossy().to_string(),
            total_kb: d.total_space() / 1024,
            used_kb: (d.total_space() - d.available_space()) / 1024,
            used_percent: (d.total_space() - d.available_space()) as f32 / d.total_space() as f32 * 100.0,
            fs_type: d.file_system().to_string_lossy().to_string(),
        })
        .collect();

    let mut procs: Vec<ProcessInfo> = sys.processes()
        .values()
        .map(|p| ProcessInfo {
            pid: p.pid().as_u32(),
            name: p.name().to_string(),
            cpu_percent: p.cpu_usage(),
            mem_kb: p.memory() / 1024,
            status: format!("{:?}", p.status()),
        })
        .collect();
    procs.sort_by(|a, b| b.cpu_percent.partial_cmp(&a.cpu_percent).unwrap());
    procs.truncate(20);

    let load = System::load_average();

    SysmonSnapshot {
        cpu,
        memory: mem,
        network,
        disks: disk_list,
        processes: procs,
        uptime_secs: System::uptime(),
        load_avg: [load.one, load.five, load.fifteen],
    }
}
