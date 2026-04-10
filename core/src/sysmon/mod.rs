use serde::{Deserialize, Serialize};
use sysinfo::{Disks, Networks, ProcessStatus, System};
use tokio::time::{Duration, interval};
use tracing::debug;

use crate::ipc::{AppState, Event};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct SystemMonitor {
    pub cpu: CpuInfo,
    pub memory: MemInfo,
    pub network: Vec<NetIface>,
    pub disks: Vec<DiskInfo>,
    pub processes: Vec<ProcessInfo>,
    pub uptime_secs: u64,
    pub load_avg: [f64; 3],
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct SystemProcesses {
    pub total: usize,
    pub running: usize,
    pub sleeping: usize,
    pub stopped: usize,
    pub zombie: usize,
    pub processes: Vec<ProcessDetail>,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct ProcessDetail {
    pub pid: u32,
    pub name: String,
    pub cmd: Vec<String>,
    pub exe: String,
    pub cpu_percent: f32,
    pub mem_percent: f32,
    pub mem_kb: u64,
    pub virtual_mem_kb: u64,
    pub status: String,
    pub user: String,
    pub start_time: u64,
    pub cpu_usage: f32,
    pub num_threads: usize,
    pub root: String,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct CpuInfo {
    pub usage_percent: f32,
    pub per_core: Vec<f32>,
    pub freq_mhz: u64,
    pub brand: String,
    pub core_count: usize,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
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

pub async fn processes_worker(state: AppState) {
    let mut sys = System::new_all();
    let mut ticker = interval(Duration::from_secs(5));

    loop {
        ticker.tick().await;
        sys.refresh_processes();

        let procs = build_processes(&sys);
        *state.inner.sysmon_processes.write().await = procs;
    }
}

fn build_snapshot(sys: &System, networks: &Networks, disks: &Disks) -> SystemMonitor {
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

    SystemMonitor {
        cpu,
        memory: mem,
        network,
        disks: disk_list,
        processes: procs,
        uptime_secs: System::uptime(),
        load_avg: [load.one, load.five, load.fifteen],
    }
}

pub fn build_processes(sys: &System) -> SystemProcesses {
    let processes = sys.processes();
    let total = processes.len();
    
    let mut running = 0;
    let mut sleeping = 0;
    let mut stopped = 0;
    let mut zombie = 0;
    
    let mut process_details: Vec<ProcessDetail> = processes
        .iter()
        .map(|(pid, p)| {
            let status = match p.status() {
                ProcessStatus::Run => {
                    running += 1;
                    "running"
                }
                ProcessStatus::Sleep => {
                    sleeping += 1;
                    "sleeping"
                }
                ProcessStatus::Stop => {
                    stopped += 1;
                    "stopped"
                }
                ProcessStatus::Zombie => {
                    zombie += 1;
                    "zombie"
                }
                _ => "unknown",
            };
            
            ProcessDetail {
                pid: pid.as_u32(),
                name: p.name().to_string(),
                cmd: p.cmd().iter().map(|s| s.to_string()).collect(),
                exe: p.exe().map(|s| s.to_string_lossy().to_string()).unwrap_or_default(),
                cpu_percent: p.cpu_usage(),
                mem_percent: p.memory() as f32 / sys.total_memory() as f32 * 100.0,
                mem_kb: p.memory() / 1024,
                virtual_mem_kb: p.virtual_memory() / 1024,
                status: status.to_string(),
                user: String::new(),
                start_time: p.start_time(),
                cpu_usage: p.cpu_usage(),
                num_threads: 1,
                root: String::new(),
            }
        })
        .collect();
    
    process_details.sort_by(|a, b| b.cpu_percent.partial_cmp(&a.cpu_percent).unwrap());
    
    SystemProcesses {
        total,
        running,
        sleeping,
        stopped,
        zombie,
        processes: process_details,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_system_monitor_default() {
        let monitor = SystemMonitor::default();
        assert_eq!(monitor.cpu, CpuInfo::default());
        assert_eq!(monitor.memory, MemInfo::default());
        assert!(monitor.network.is_empty());
        assert!(monitor.disks.is_empty());
        assert!(monitor.processes.is_empty());
        assert_eq!(monitor.uptime_secs, 0);
        assert_eq!(monitor.load_avg, [0.0, 0.0, 0.0]);
    }

    #[test]
    fn test_system_processes_default() {
        let procs = SystemProcesses::default();
        assert_eq!(procs.total, 0);
        assert_eq!(procs.running, 0);
        assert_eq!(procs.sleeping, 0);
        assert_eq!(procs.stopped, 0);
        assert_eq!(procs.zombie, 0);
        assert!(procs.processes.is_empty());
    }

    #[test]
    fn test_cpu_info_default() {
        let cpu = CpuInfo::default();
        assert_eq!(cpu.usage_percent, 0.0);
        assert!(cpu.per_core.is_empty());
        assert_eq!(cpu.freq_mhz, 0);
        assert!(cpu.brand.is_empty());
        assert_eq!(cpu.core_count, 0);
    }

    #[test]
    fn test_mem_info_default() {
        let mem = MemInfo::default();
        assert_eq!(mem.total_kb, 0);
        assert_eq!(mem.used_kb, 0);
        assert_eq!(mem.available_kb, 0);
        assert_eq!(mem.swap_total_kb, 0);
        assert_eq!(mem.swap_used_kb, 0);
        assert_eq!(mem.used_percent, 0.0);
    }

    #[test]
    fn test_net_iface_default() {
        let iface = NetIface::default();
        assert!(iface.name.is_empty());
        assert_eq!(iface.rx_bytes, 0);
        assert_eq!(iface.tx_bytes, 0);
        assert_eq!(iface.rx_rate_bps, 0);
        assert_eq!(iface.tx_rate_bps, 0);
    }

    #[test]
    fn test_disk_info_default() {
        let disk = DiskInfo::default();
        assert!(disk.name.is_empty());
        assert!(disk.mount.is_empty());
        assert_eq!(disk.total_kb, 0);
        assert_eq!(disk.used_kb, 0);
        assert_eq!(disk.used_percent, 0.0);
        assert!(disk.fs_type.is_empty());
    }

    #[test]
    fn test_process_info_default() {
        let proc = ProcessInfo::default();
        assert_eq!(proc.pid, 0);
        assert!(proc.name.is_empty());
        assert_eq!(proc.cpu_percent, 0.0);
        assert_eq!(proc.mem_kb, 0);
        assert!(proc.status.is_empty());
    }

    #[test]
    fn test_system_monitor_serialization() {
        let monitor = SystemMonitor {
            cpu: CpuInfo {
                usage_percent: 50.0,
                per_core: vec![50.0],
                freq_mhz: 3000,
                brand: "Test CPU".to_string(),
                core_count: 4,
            },
            memory: MemInfo {
                total_kb: 16_000_000,
                used_kb: 8_000_000,
                available_kb: 8_000_000,
                swap_total_kb: 8_000_000,
                swap_used_kb: 0,
                used_percent: 50.0,
            },
            network: vec![NetIface {
                name: "eth0".to_string(),
                rx_bytes: 1000,
                tx_bytes: 500,
                rx_rate_bps: 100,
                tx_rate_bps: 50,
            }],
            disks: vec![],
            processes: vec![],
            uptime_secs: 3600,
            load_avg: [1.0, 0.5, 0.25],
        };

        let json = serde_json::to_string(&monitor).unwrap();
        assert!(json.contains("\"usage_percent\":50.0"));
        assert!(json.contains("\"brand\":\"Test CPU\""));
        assert!(json.contains("\"name\":\"eth0\""));
        assert!(json.contains("\"uptime_secs\":3600"));
    }

    #[test]
    fn test_cpu_info_serialization() {
        let cpu = CpuInfo {
            usage_percent: 75.5,
            per_core: vec![80.0, 70.0, 75.0, 77.0],
            freq_mhz: 4200,
            brand: "AMD Ryzen 9".to_string(),
            core_count: 8,
        };

        let json = serde_json::to_string(&cpu).unwrap();
        assert!(json.contains("\"usage_percent\":75.5"));
        assert!(json.contains("\"core_count\":8"));
        assert!(json.contains("\"brand\":\"AMD Ryzen 9\""));
    }

    #[test]
    fn test_mem_info_serialization() {
        let mem = MemInfo {
            total_kb: 32_000_000,
            used_kb: 16_000_000,
            available_kb: 16_000_000,
            swap_total_kb: 0,
            swap_used_kb: 0,
            used_percent: 50.0,
        };

        let json = serde_json::to_string(&mem).unwrap();
        assert!(json.contains("\"total_kb\":32000000"));
        assert!(json.contains("\"used_percent\":50.0"));
    }

    #[test]
    fn test_system_processes_serialization() {
        let procs = SystemProcesses {
            total: 150,
            running: 5,
            sleeping: 140,
            stopped: 3,
            zombie: 2,
            processes: vec![
                ProcessDetail {
                    pid: 1234,
                    name: "test_proc".to_string(),
                    cmd: vec!["test_proc".to_string(), "--arg".to_string()],
                    exe: "/usr/bin/test_proc".to_string(),
                    cpu_percent: 10.5,
                    mem_percent: 2.5,
                    mem_kb: 1024,
                    virtual_mem_kb: 2048,
                    status: "running".to_string(),
                    user: "root".to_string(),
                    start_time: 1234567890,
                    cpu_usage: 10.5,
                    num_threads: 2,
                    root: "/".to_string(),
                }
            ],
        };

        let json = serde_json::to_string(&procs).unwrap();
        assert!(json.contains("\"total\":150"));
        assert!(json.contains("\"running\":5"));
        assert!(json.contains("\"sleeping\":140"));
        assert!(json.contains("\"stopped\":3"));
        assert!(json.contains("\"zombie\":2"));
        assert!(json.contains("\"test_proc\""));
    }

    #[test]
    fn test_disk_info_serialization() {
        let disk = DiskInfo {
            name: "sda".to_string(),
            mount: "/".to_string(),
            total_kb: 500_000_000,
            used_kb: 250_000_000,
            used_percent: 50.0,
            fs_type: "ext4".to_string(),
        };

        let json = serde_json::to_string(&disk).unwrap();
        assert!(json.contains("\"name\":\"sda\""));
        assert!(json.contains("\"mount\":\"/\""));
        assert!(json.contains("\"fs_type\":\"ext4\""));
    }

    #[test]
    fn test_net_iface_serialization() {
        let iface = NetIface {
            name: "wlan0".to_string(),
            rx_bytes: 1_000_000,
            tx_bytes: 500_000,
            rx_rate_bps: 10_000,
            tx_rate_bps: 5_000,
        };

        let json = serde_json::to_string(&iface).unwrap();
        assert!(json.contains("\"name\":\"wlan0\""));
        assert!(json.contains("\"rx_bytes\":1000000"));
        assert!(json.contains("\"tx_bytes\":500000"));
    }
}
