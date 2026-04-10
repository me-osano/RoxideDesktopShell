use std::os::unix::net::UnixStream;
use std::io::{Read, Write};

use anyhow::Result;
use clap::{Parser, Subcommand};
use serde::Serialize;

use crate::ipc::server::socket_path;

#[derive(Parser)]
#[command(name = "roxide", about = "ROXIDE desktop shell daemon & CLI")]
pub struct Cmd {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    /// Start the ROXIDE daemon
    Daemon,
    /// Check daemon status
    Status,
    /// Run ROXIDE (daemon + Quickshell UI)
    RunRqs {
        /// Run in daemon mode (detached)
        #[arg(short, long)]
        daemon: bool,
        /// Session managed mode (for systemd)
        #[arg(long)]
        session: bool,
    },
    /// Restart ROXIDE (kill and relaunch)
    Restart,
    /// Kill all ROXIDE instances
    Kill,
    /// Print system snapshot with diagnostics
    Sysmon {
        /// Show detailed output including paths and versions
        #[arg(short, long)]
        verbose: bool,
        /// Output results in JSON format
        #[arg(short, long)]
        json: bool,
    },
    /// Search files
    Search {
        query: String,
        #[arg(short, long, default_value = "10")]
        limit: usize,
    },
    /// Print weather snapshot
    Weather,
    /// Niri IPC commands
    Niri {
        #[command(subcommand)]
        subcommand: NiriCommand,
    },
    /// Brightness control
    Brightness {
        #[command(subcommand)]
        subcommand: BrightnessCommand,
    },
}

#[derive(Subcommand)]
pub enum BrightnessCommand {
    /// List all available brightness devices
    List {
        /// Include DDC/I2C monitors (slower)
        #[arg(long)]
        ddc: bool,
    },
    /// Get current brightness for a device
    Get {
        /// Device ID (e.g., backlight:amdgpu_bl1)
        device: String,
        /// Enable DDC/I2C device support
        #[arg(long)]
        ddc: bool,
    },
    /// Set brightness percentage for a device
    Set {
        /// Device ID (e.g., backlight:amdgpu_bl1)
        device: String,
        /// Brightness percentage (0-100)
        percent: f32,
        /// Enable DDC/I2C device support
        #[arg(long)]
        ddc: bool,
        /// Use exponential brightness scaling
        #[arg(long)]
        exponential: bool,
        /// Exponent for exponential scaling (default: 1.2)
        #[arg(long, default_value = "1.2")]
        exponent: f64,
    },
    /// Increase brightness
    Increase {
        /// Percentage to increase
        delta: f32,
        /// Enable exponential brightness scaling
        #[arg(long)]
        exponential: bool,
        /// Exponent for exponential scaling (default: 1.2)
        #[arg(long, default_value = "1.2")]
        exponent: f64,
    },
    /// Decrease brightness
    Decrease {
        /// Percentage to decrease
        delta: f32,
        /// Enable exponential brightness scaling
        #[arg(long)]
        exponential: bool,
        /// Exponent for exponential scaling (default: 1.2)
        #[arg(long, default_value = "1.2")]
        exponent: f64,
    },
}

#[derive(Subcommand)]
pub enum NiriCommand {
    /// List workspaces
    Workspaces,
    /// List windows
    Windows,
    /// Activate a workspace by ID
    Activate { id: u64 },
    /// Focus a window by ID
    Focus { id: u64 },
}

#[derive(Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum CheckStatus {
    Ok,
    Warn,
    Error,
    Info,
}

impl CheckStatus {
    fn icon(&self) -> &'static str {
        match self {
            CheckStatus::Ok => "●",
            CheckStatus::Warn => "●",
            CheckStatus::Error => "●",
            CheckStatus::Info => "○",
        }
    }

    fn color(&self) -> &'static str {
        match self {
            CheckStatus::Ok => "\x1b[32m",
            CheckStatus::Warn => "\x1b[33m",
            CheckStatus::Error => "\x1b[31m",
            CheckStatus::Info => "\x1b[90m",
        }
    }
}

#[derive(Clone, Copy, PartialEq)]
pub enum Category {
    System,
    Versions,
    Installation,
    Compositor,
    OptionalFeatures,
    ConfigFiles,
    Services,
    Environment,
}

impl Category {
    fn as_str(&self) -> &'static str {
        match self {
            Category::System => "System",
            Category::Versions => "Versions",
            Category::Installation => "Installation",
            Category::Compositor => "Compositor",
            Category::OptionalFeatures => "Optional Features",
            Category::ConfigFiles => "Config Files",
            Category::Services => "Services",
            Category::Environment => "Environment",
        }
    }
}

pub struct CheckResult {
    pub category: Category,
    pub name: String,
    pub status: CheckStatus,
    pub message: String,
    pub details: String,
}

#[derive(Default, Serialize)]
pub struct SysmonStatus {
    pub errors: usize,
    pub warnings: usize,
    pub ok: usize,
    pub info: usize,
}

impl SysmonStatus {
    pub fn add(&mut self, result: &CheckResult) {
        match result.status {
            CheckStatus::Ok => self.ok += 1,
            CheckStatus::Warn => self.warnings += 1,
            CheckStatus::Error => self.errors += 1,
            CheckStatus::Info => self.info += 1,
        }
    }

    pub fn has_issues(&self) -> bool {
        self.errors > 0 || self.warnings > 0
    }
}

#[derive(Serialize)]
pub struct SysmonOutputJSON {
    pub summary: SysmonStatus,
    pub results: Vec<CheckResultJSON>,
}

#[derive(Serialize)]
pub struct CheckResultJSON {
    pub category: String,
    pub name: String,
    pub status: String,
    pub message: String,
    pub details: String,
}

impl From<&CheckResult> for CheckResultJSON {
    fn from(r: &CheckResult) -> Self {
        CheckResultJSON {
            category: r.category.as_str().to_string(),
            name: r.name.clone(),
            status: match r.status {
                CheckStatus::Ok => "ok".to_string(),
                CheckStatus::Warn => "warn".to_string(),
                CheckStatus::Error => "error".to_string(),
                CheckStatus::Info => "info".to_string(),
            },
            message: r.message.clone(),
            details: r.details.clone(),
        }
    }
}

const SYSMON_DOCS_URL: &str = "https://roxide.sh/docs/cli-sysmon";

pub async fn status() -> Result<()> {
    let path = socket_path();
    if path.exists() {
        println!("ROXIDE daemon: running ({})", path.display());
    } else {
        println!("ROXIDE daemon: not running");
    }
    Ok(())
}

pub async fn run_rqs(daemon: bool, _session: bool) -> Result<()> {
    let socket = socket_path();
    
    if socket.exists() {
        println!("ROXIDE is already running ({})", socket.display());
        println!("Use 'roxide restart' to restart, or 'roxide kill' to stop first.");
        return Ok(());
    }
    
    println!("Starting ROXIDE daemon...");
    
    let mut cmd = std::process::Command::new("roxide");
    cmd.arg("daemon");
    
    if daemon {
        cmd.spawn()?;
        println!("ROXIDE daemon started in background");
    } else {
        match cmd.spawn() {
            Ok(mut child) => {
                println!("ROXIDE daemon started (PID: {})", child.id());
                let _ = child.wait();
            }
            Err(e) => {
                return Err(anyhow::anyhow!("Failed to start daemon: {}", e));
            }
        }
    }
    
    Ok(())
}

pub async fn restart_rqs() -> Result<()> {
    kill_rqs().await?;
    
    tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
    
    println!("Starting ROXIDE daemon...");
    let mut cmd = std::process::Command::new("roxide");
    cmd.arg("daemon");
    cmd.spawn()?;
    println!("ROXIDE daemon started");
    
    Ok(())
}

pub async fn kill_rqs() -> Result<()> {
    let socket = socket_path();
    
    if !socket.exists() {
        println!("ROXIDE is not running");
        return Ok(());
    }
    
    println!("Stopping ROXIDE daemon...");
    
    if let Ok(mut stream) = UnixStream::connect(&socket) {
        let _ = stream.write_all(b"POST /shutdown HTTP/1.0\r\n\r\n");
    }
    
    tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
    
    if socket.exists() {
        let _ = std::fs::remove_file(&socket);
    }
    
    println!("ROXIDE daemon stopped");
    
    Ok(())
}

pub async fn sysmon_snapshot(verbose: bool, json: bool) -> Result<()> {
    let socket = socket_path();
    if !socket.exists() {
        return Err(anyhow::anyhow!("Daemon not running. Start with 'roxide daemon'"));
    }

    let mut stream = UnixStream::connect(&socket)?;
    stream.write_all(b"GET /sysmon HTTP/1.0\r\n\r\n")?;

    let mut response = String::new();
    use std::io::Read;
    stream.read_to_string(&mut response)?;

    let body = response
        .split("\r\n\r\n")
        .nth(1)
        .unwrap_or(&response);

    let snapshot: crate::sysmon::SystemMonitor = serde_json::from_str(body)
        .map_err(|e| anyhow::anyhow!("Failed to parse sysmon response: {}", e))?;

    if json {
        println!("{}", serde_json::to_string_pretty(&snapshot)?);
    } else {
        print_sysmon_output(&snapshot, verbose);
    }

    print_diagnostics(verbose);

    Ok(())
}

pub async fn search(query: String, limit: usize) -> Result<()> {
    println!("Use: curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock 'http://localhost/search?q={query}&limit={limit}' | jq");
    Ok(())
}

pub async fn weather_snapshot() -> Result<()> {
    println!("Use: curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/weather | jq");
    Ok(())
}

pub async fn niri_cmd(subcommand: NiriCommand) -> Result<()> {
    match subcommand {
        NiriCommand::Workspaces => println!("Use: curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/niri/workspaces | jq"),
        NiriCommand::Windows    => println!("Use: curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/niri/windows | jq"),
        NiriCommand::Activate { id } => println!("Use: curl -X POST --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/niri/workspace/{id}/activate"),
        NiriCommand::Focus { id }    => println!("Use: curl -X POST --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/niri/window/{id}/focus"),
    }
    Ok(())
}

pub async fn brightness_cmd(subcommand: BrightnessCommand) -> Result<()> {
    match subcommand {
        BrightnessCommand::List { ddc } => brightness_list(ddc).await,
        BrightnessCommand::Get { device, ddc } => brightness_get(device, ddc).await,
        BrightnessCommand::Set { device, percent, ddc, exponential, exponent } => {
            brightness_set(device, percent, ddc, exponential, exponent).await
        }
        BrightnessCommand::Increase { delta, exponential, exponent } => {
            brightness_increase(delta, exponential, exponent).await
        }
        BrightnessCommand::Decrease { delta, exponential, exponent } => {
            brightness_decrease(delta, exponential, exponent).await
        }
    }
}

fn percent_to_value(percent: i32, max: i32, exponent: f64) -> i32 {
    let normalized = percent as f64 / 100.0;
    let scaled = normalized.powf(exponent);
    (scaled * max as f64).round() as i32
}

pub async fn brightness_list(ddc: bool) -> Result<()> {
    println!("Device                      Class         Name                   Brightness");
    println!("────────────────────────────────────────────────────────────────────────────────");

    let devices = crate::brightness::SysfsBackend::new()
        .and_then(|b| b.get_devices())
        .unwrap_or_default();

    for device in devices {
        println!("{:<28} {:<12} {:<20} {:>3}%", device.id, device.class, device.name, device.current_percent);
    }

    if ddc {
        if let Ok(mut ddc) = crate::brightness::DdcBackend::new() {
            if let Ok(ddc_devices) = ddc.get_devices() {
                for device in ddc_devices {
                    println!("{:<28} {:<12} {:<20} {:>3}%", device.id, device.class, device.name, device.current_percent);
                }
            }
            ddc.close();
        }
    }

    Ok(())
}

pub async fn brightness_get(device: String, ddc: bool) -> Result<()> {
    let devices = crate::brightness::SysfsBackend::new()
        .and_then(|b| b.get_devices())
        .unwrap_or_default();

    if let Some(d) = devices.iter().find(|d| d.id == device) {
        println!("Device: {} ({})", d.id, d.name);
        println!("Class: {}", d.class);
        println!("Brightness: {}% ({}/{})", d.current_percent, d.current, d.max);
        return Ok(());
    }

    if ddc {
        if let Ok(mut ddc) = crate::brightness::DdcBackend::new() {
            if let Ok(ddc_devices) = ddc.get_devices() {
                if let Some(d) = ddc_devices.iter().find(|d| d.id == device) {
                    println!("Device: {} ({})", d.id, d.name);
                    println!("Class: ddc");
                    println!("Brightness: {}%", d.current_percent);
                    return Ok(());
                }
            }
            ddc.close();
        }
    }

    Err(anyhow::anyhow!("Device not found: {}", device))
}

pub async fn brightness_set(device: String, percent: f32, ddc: bool, exponential: bool, exponent: f64) -> Result<()> {
    let (class, name) = device.split_once(':').ok_or_else(||
        anyhow::anyhow!("Invalid device ID format. Use <class>:<name>, e.g., backlight:amdgpu_bl1"))?;

    let value = if exponential {
        percent_to_value(percent as i32, 100, exponent)
    } else {
        (percent / 100.0 * 100.0) as i32
    };

    match class {
        "backlight" | "leds" => {
            let b = crate::brightness::SysfsBackend::new().map_err(|e| anyhow::anyhow!("{}", e))?;
            b.set_brightness(&device, value).map_err(|e| anyhow::anyhow!("{}", e))?;
        }
        "ddc" => {
            if !ddc {
                return Err(anyhow::anyhow!("Use --ddc flag for DDC devices"));
            }
            let mut b = crate::brightness::DdcBackend::new().map_err(|e| anyhow::anyhow!("{}", e))?;
            b.set_brightness(&device, value as i32).map_err(|e| anyhow::anyhow!("{}", e))?;
            b.close();
        }
        _ => return Err(anyhow::anyhow!("Invalid device class: {}", class)),
    }

    println!("Set {} to {}%", device, percent);
    Ok(())
}

pub async fn brightness_increase(delta: f32, exponential: bool, exponent: f64) -> Result<()> {
    let mut devices = crate::brightness::SysfsBackend::new()
        .and_then(|b| b.get_devices())
        .unwrap_or_default();

    if devices.is_empty() {
        return Err(anyhow::anyhow!("No brightness devices found"));
    }

    let device = devices.remove(0);
    let new_percent = (device.current_percent as f32 + delta).min(100.0);

    let value = if exponential {
        percent_to_value(new_percent as i32, device.max, exponent)
    } else {
        (new_percent / 100.0 * device.max as f32) as i32
    };

    if let Ok(backend) = crate::brightness::SysfsBackend::new() {
        backend.set_brightness(&device.id, value).map_err(|e| anyhow::anyhow!("{}", e))?;
    }

    println!("Increased {} from {}% to {}%", device.id, device.current_percent, new_percent as i32);
    Ok(())
}

pub async fn brightness_decrease(delta: f32, exponential: bool, exponent: f64) -> Result<()> {
    let mut devices = crate::brightness::SysfsBackend::new()
        .and_then(|b| b.get_devices())
        .unwrap_or_default();

    if devices.is_empty() {
        return Err(anyhow::anyhow!("No brightness devices found"));
    }

    let device = devices.remove(0);
    let new_percent = (device.current_percent as f32 - delta).max(0.0);

    let value = if exponential {
        percent_to_value(new_percent as i32, device.max, exponent)
    } else {
        (new_percent / 100.0 * device.max as f32) as i32
    };

    if let Ok(backend) = crate::brightness::SysfsBackend::new() {
        backend.set_brightness(&device.id, value).map_err(|e| anyhow::anyhow!("{}", e))?;
    }

    println!("Decreased {} from {}% to {}%", device.id, device.current_percent, new_percent as i32);
    Ok(())
}

struct OsInfo {
    id: String,
    name: String,
    version: String,
    pretty_name: String,
    architecture: String,
}

fn get_os_info() -> Option<OsInfo> {
    let data = std::fs::read_to_string("/etc/os-release").ok()?;
    let mut info = OsInfo {
        id: String::new(),
        name: String::new(),
        version: String::new(),
        pretty_name: String::new(),
        architecture: std::env::consts::ARCH.to_string(),
    };

    for line in data.lines() {
        if let Some((key, value)) = line.split_once('=') {
            let value = value.trim_matches('"');
            match key {
                "ID" => info.id = value.to_string(),
                "NAME" => info.name = value.to_string(),
                "VERSION_ID" => info.version = value.to_string(),
                "PRETTY_NAME" => info.pretty_name = value.to_string(),
                _ => {}
            }
        }
    }

    if info.id.is_empty() {
        return None;
    }

    if info.pretty_name.is_empty() {
        info.pretty_name = format!("{} {}", info.name, info.version);
    }

    Some(info)
}

fn check_system_info(verbose: bool) -> Vec<CheckResult> {
    let mut results = Vec::new();

    if let Some(os_info) = get_os_info() {
        let (status, message, details) = match os_info.id.as_str() {
            "arch" | "manjaro" | "endeavouros" => (CheckStatus::Ok, os_info.pretty_name.clone(), format!("ID: {}, Version: {}", os_info.id, os_info.version)),
            "fedora" | "rhel" | "centos" => (CheckStatus::Ok, os_info.pretty_name.clone(), format!("ID: {}, Version: {}", os_info.id, os_info.version)),
            "debian" | "ubuntu" | "linuxmint" => (CheckStatus::Ok, os_info.pretty_name.clone(), format!("ID: {}, Version: {}", os_info.id, os_info.version)),
            "opensuse" | "sles" => (CheckStatus::Ok, os_info.pretty_name.clone(), format!("ID: {}, Version: {}", os_info.id, os_info.version)),
            "nixos" => (CheckStatus::Ok, os_info.pretty_name.clone(), "Supported for runtime (install via NixOS module or Flake)".to_string()),
            "gentoo" | "void" | "artix" => (CheckStatus::Ok, os_info.pretty_name.clone(), format!("ID: {}, Version: {}", os_info.id, os_info.version)),
            _ => (CheckStatus::Warn, os_info.pretty_name.clone(), format!("ID: {}, (not fully supported)", os_info.id)),
        };
        results.push(CheckResult {
            category: Category::System,
            name: "Operating System".to_string(),
            status,
            message,
            details: if verbose { details } else { String::new() },
        });
    }

    let arch = std::env::consts::ARCH;
    let arch_status = if arch == "x86_64" || arch == "amd64" || arch == "aarch64" || arch == "arm64" {
        CheckStatus::Ok
    } else {
        CheckStatus::Error
    };
    results.push(CheckResult {
        category: Category::System,
        name: "Architecture".to_string(),
        status: arch_status,
        message: arch.to_string(),
        details: String::new(),
    });

    let wayland_display = std::env::var("WAYLAND_DISPLAY").ok();
    let xdg_session_type = std::env::var("XDG_SESSION_TYPE").ok();

    let (display_status, display_message) = match (wayland_display.as_deref(), xdg_session_type.as_deref()) {
        (Some(_), _) | (_, Some("wayland")) => (CheckStatus::Ok, "Wayland".to_string()),
        (_, Some("x11")) => (CheckStatus::Error, "X11 (ROXIDE requires Wayland)".to_string()),
        _ => (CheckStatus::Warn, "Unknown (ensure you're running Wayland)".to_string()),
    };

    let display_details = match (&wayland_display, &xdg_session_type) {
        (Some(d), _) => format!("WAYLAND_DISPLAY={}", d),
        (_, Some(t)) => format!("XDG_SESSION_TYPE={}", t),
        _ => String::new(),
    };

    results.push(CheckResult {
        category: Category::System,
        name: "Display Server".to_string(),
        status: display_status,
        message: display_message,
        details: display_details,
    });

    results
}

fn check_versions(verbose: bool) -> Vec<CheckResult> {
    let mut results = Vec::new();

    let version = env!("CARGO_PKG_VERSION");
    results.push(CheckResult {
        category: Category::Versions,
        name: "ROXIDE CLI".to_string(),
        status: CheckStatus::Ok,
        message: format!("v{}", version),
        details: if verbose {
            std::env::current_exe()
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_default()
        } else {
            String::new()
        },
    });

    if let Ok(output) = std::process::Command::new("niri").arg("--version").output() {
        if output.status.success() {
            let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
            results.push(CheckResult {
                category: Category::Versions,
                name: "Niri".to_string(),
                status: CheckStatus::Ok,
                message: version,
                details: if verbose {
                    std::process::Command::new("which").arg("niri")
                        .output()
                        .ok()
                        .and_then(|o| if o.status.success() { Some(String::from_utf8_lossy(&o.stdout).trim().to_string()) } else { None })
                        .unwrap_or_default()
                } else {
                    String::new()
                },
            });
        }
    } else {
        results.push(CheckResult {
            category: Category::Versions,
            name: "Niri".to_string(),
            status: CheckStatus::Info,
            message: "Not installed".to_string(),
            details: String::new(),
        });
    }

    let compositors = ["hyprland", "sway", "river", "wayfire", "labwc"];
    for compositor in compositors {
        if std::process::Command::new("which").arg(compositor).output().map(|o| o.status.success()).unwrap_or(false) {
            let version = std::process::Command::new(compositor)
                .arg(if compositor == "river" { "-version" } else { "--version" })
                .output()
                .ok()
                .and_then(|o| {
                    if o.status.success() {
                        Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
                    } else {
                        None
                    }
                })
                .unwrap_or_else(|| "installed".to_string());

            results.push(CheckResult {
                category: Category::Versions,
                name: compositor.to_string(),
                status: CheckStatus::Info,
                message: version,
                details: String::new(),
            });
        }
    }

    results
}

fn check_installation(verbose: bool) -> Vec<CheckResult> {
    let mut results = Vec::new();

    let socket_path = socket_path();
    let socket_exists = socket_path.exists();

    results.push(CheckResult {
        category: Category::Installation,
        name: "IPC Socket".to_string(),
        status: if socket_exists { CheckStatus::Ok } else { CheckStatus::Warn },
        message: if socket_exists {
            format!("Found at {}", socket_path.display())
        } else {
            "Not found (daemon may not be running)".to_string()
        },
        details: String::new(),
    });

    if verbose {
        if let Ok(exe) = std::env::current_exe() {
            results.push(CheckResult {
                category: Category::Installation,
                name: "Executable".to_string(),
                status: CheckStatus::Info,
                message: exe.to_string_lossy().to_string(),
                details: String::new(),
            });
        }
    }

    results
}

fn check_compositor(verbose: bool) -> Vec<CheckResult> {
    let mut results = Vec::new();

    let hyprland_sig = std::env::var("HYPRLAND_INSTANCE_SIGNATURE").ok();
    let niri_socket = std::env::var("NIRI_SOCKET").ok();
    let xdg_desktop = std::env::var("XDG_CURRENT_DESKTOP").ok();

    if let Some(sig) = hyprland_sig {
        results.push(CheckResult {
            category: Category::Compositor,
            name: "Active".to_string(),
            status: CheckStatus::Ok,
            message: format!("Hyprland ({})", &sig[..8]),
            details: String::new(),
        });
    } else if let Some(socket) = niri_socket {
        results.push(CheckResult {
            category: Category::Compositor,
            name: "Active".to_string(),
            status: CheckStatus::Ok,
            message: format!("niri ({})", socket),
            details: String::new(),
        });
    } else if let Some(desktop) = xdg_desktop {
        results.push(CheckResult {
            category: Category::Compositor,
            name: "Active".to_string(),
            status: CheckStatus::Info,
            message: desktop,
            details: String::new(),
        });
    } else {
        results.push(CheckResult {
            category: Category::Compositor,
            name: "Active".to_string(),
            status: CheckStatus::Warn,
            message: "Unknown".to_string(),
            details: String::new(),
        });
    }

    results
}

fn check_optional_deps(verbose: bool) -> Vec<CheckResult> {
    let mut results = Vec::new();

    if let Ok(devices) = crate::brightness::SysfsBackend::new().and_then(|b| b.get_devices()) {
        if devices.is_empty() {
            results.push(CheckResult {
                category: Category::OptionalFeatures,
                name: "Brightness".to_string(),
                status: CheckStatus::Warn,
                message: "No devices found".to_string(),
                details: "Backlight/LED brightness control".to_string(),
            });
        } else {
            results.push(CheckResult {
                category: Category::OptionalFeatures,
                name: "Brightness".to_string(),
                status: CheckStatus::Ok,
                message: format!("{} device(s)", devices.len()),
                details: devices.iter().map(|d| d.id.clone()).collect::<Vec<_>>().join(", "),
            });
        }
    }

    if std::process::Command::new("which")
        .arg("curl")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
    {
        results.push(CheckResult {
            category: Category::OptionalFeatures,
            name: "curl".to_string(),
            status: CheckStatus::Ok,
            message: "Available".to_string(),
            details: "HTTP client for IPC".to_string(),
        });
    }

    if std::process::Command::new("which")
        .arg("jq")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
    {
        results.push(CheckResult {
            category: Category::OptionalFeatures,
            name: "jq".to_string(),
            status: CheckStatus::Ok,
            message: "Available".to_string(),
            details: "JSON processor".to_string(),
        });
    }

    results
}

fn check_config_files(verbose: bool) -> Vec<CheckResult> {
    let mut results = Vec::new();

    let config_dir = dirs::config_dir()
        .map(|p| p.join("roxide"))
        .unwrap_or_default();

    if config_dir.exists() {
        results.push(CheckResult {
            category: Category::ConfigFiles,
            name: "Config Dir".to_string(),
            status: CheckStatus::Ok,
            message: "Found".to_string(),
            details: config_dir.to_string_lossy().to_string(),
        });
    } else {
        results.push(CheckResult {
            category: Category::ConfigFiles,
            name: "Config Dir".to_string(),
            status: CheckStatus::Info,
            message: "Not yet created".to_string(),
            details: config_dir.to_string_lossy().to_string(),
        });
    }

    results
}

fn check_daemon() -> Vec<CheckResult> {
    let socket_path = socket_path();
    let running = socket_path.exists();

    vec![CheckResult {
        category: Category::Installation,
        name: "Daemon".to_string(),
        status: if running { CheckStatus::Ok } else { CheckStatus::Warn },
        message: if running { "Running" } else { "Not running" }.to_string(),
        details: if !running { "Run 'roxide daemon' to start".to_string() } else { String::new() },
    }]
}

fn check_environment_vars(verbose: bool) -> Vec<CheckResult> {
    let mut results = Vec::new();

    if let Some(qt_theme) = std::env::var("QT_QPA_PLATFORMTHEME").ok() {
        results.push(CheckResult {
            category: Category::Environment,
            name: "QT_QPA_PLATFORMTHEME".to_string(),
            status: CheckStatus::Info,
            message: qt_theme,
            details: "Qt platform theme".to_string(),
        });
    } else if verbose {
        results.push(CheckResult {
            category: Category::Environment,
            name: "QT_QPA_PLATFORMTHEME".to_string(),
            status: CheckStatus::Info,
            message: "Not set".to_string(),
            details: "Qt platform theme".to_string(),
        });
    }

    if let Some(qs_icon) = std::env::var("QS_ICON_THEME").ok() {
        results.push(CheckResult {
            category: Category::Environment,
            name: "QS_ICON_THEME".to_string(),
            status: CheckStatus::Info,
            message: qs_icon,
            details: "Quickshell icon theme".to_string(),
        });
    }

    results
}

fn print_results(results: &[CheckResult], verbose: bool) {
    let mut current_category: Option<Category> = None;

    println!("\nROXIDE Sysmon - Diagnostic Checks\n");

    for result in results {
        if Some(result.category) != current_category {
            println!("  {}", result.category.as_str());
            current_category = Some(result.category);
        }

        let icon = result.status.icon();
        let status_str = match result.status {
            CheckStatus::Ok => "\x1b[32m",     // green
            CheckStatus::Warn => "\x1b[33m",   // yellow
            CheckStatus::Error => "\x1b[31m",  // red
            CheckStatus::Info => "\x1b[90m",   // gray
        };

        print!("    {} {} ", format!("{}{}", status_str, icon), result.name);
        print!("{}", "\x1b[0m"); // reset

        let dots_needed = 20usize.saturating_sub(result.name.len());
        print!("{}", ".".repeat(dots_needed));
        println!(" {}", result.message);

        if verbose && !result.details.is_empty() {
            println!("      └─ {}", result.details);
        }
    }
    println!();
}

fn print_results_json(results: &[CheckResult]) {
    let mut status = SysmonStatus::default();
    for r in results {
        status.add(r);
    }

    let output = SysmonOutputJSON {
        summary: status,
        results: results.iter().map(CheckResultJSON::from).collect(),
    };

    println!("{}", serde_json::to_string_pretty(&output).unwrap_or_default());
}

fn print_summary(results: &[CheckResult]) {
    let mut status = SysmonStatus::default();
    for r in results {
        status.add(r);
    }

    println!("──────────────────────────────────────");

    if !status.has_issues() {
        println!("✓ All checks passed!");
    } else {
        let mut parts = Vec::new();
        if status.errors > 0 {
            parts.push(format!("\x1b[31m{} error(s)\x1b[0m", status.errors));
        }
        if status.warnings > 0 {
            parts.push(format!("\x1b[33m{} warning(s)\x1b[0m", status.warnings));
        }
        parts.push(format!("\x1b[32m{} ok\x1b[0m", status.ok));
        println!("{}", parts.join(", "));
    }
    println!();
}

fn print_sysmon_output(snap: &crate::sysmon::SystemMonitor, verbose: bool) {
    println!("\n  System Monitor\n");
    println!("  CPU");
    println!("    Usage: {:.1}%", snap.cpu.usage_percent);
    println!("    Cores: {}", snap.cpu.core_count);
    if verbose {
        println!("    Brand: {}", snap.cpu.brand);
    }
    println!("    Load: {:.2} / {:.2} / {:.2}", snap.load_avg[0], snap.load_avg[1], snap.load_avg[2]);

    println!("\n  Memory");
    println!("    Used: {:.1}% ({} / {} MB)",
        snap.memory.used_percent,
        snap.memory.used_kb / 1024,
        snap.memory.total_kb / 1024);
    println!("    Available: {} MB", snap.memory.available_kb / 1024);
    if snap.memory.swap_total_kb > 0 {
        println!("    Swap: {} / {} MB", snap.memory.swap_used_kb / 1024, snap.memory.swap_total_kb / 1024);
    }

    println!("\n  Disk");
    for disk in &snap.disks {
        println!("    {} ({}) {:.1}% used ({} / {} GB)",
            disk.mount, disk.fs_type, disk.used_percent,
            disk.used_kb / 1024 / 1024, disk.total_kb / 1024 / 1024);
    }

    println!("\n  Network");
    for iface in &snap.network {
        println!("    {}: ↓{} ↓rate:{} B/s  ↑{} ↑rate:{} B/s",
            iface.name,
            format_bytes(iface.rx_bytes),
            format_bytes(iface.rx_rate_bps),
            format_bytes(iface.tx_bytes),
            format_bytes(iface.tx_rate_bps));
    }

    println!("\n  Processes (top 5 CPU)");
    for (i, proc) in snap.processes.iter().take(5).enumerate() {
        println!("    {}: {} {:.1}% CPU {} KB", i + 1, proc.name, proc.cpu_percent, proc.mem_kb / 1024);
    }

    println!("\n  Uptime: {} secs", snap.uptime_secs);
}

fn format_bytes(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;
    const GB: u64 = MB * 1024;

    if bytes >= GB {
        format!("{:.1}GB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.1}MB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.1}KB", bytes as f64 / KB as f64)
    } else {
        format!("{}B", bytes)
    }
}

fn print_diagnostics(verbose: bool) {
    let mut results: Vec<CheckResult> = Vec::new();
    results.extend(check_system_info(verbose));
    results.extend(check_versions(verbose));
    results.extend(check_installation(verbose));
    results.extend(check_compositor(verbose));
    results.extend(check_optional_deps(verbose));
    results.extend(check_config_files(verbose));
    results.extend(check_daemon());
    results.extend(check_environment_vars(verbose));

    println!("\n  Diagnostics\n");
    for result in &results {
        let icon = match result.status {
            CheckStatus::Ok => "\x1b[32m●\x1b[0m",
            CheckStatus::Warn => "\x1b[33m●\x1b[0m",
            CheckStatus::Error => "\x1b[31m●\x1b[0m",
            CheckStatus::Info => "\x1b[90m○\x1b[0m",
        };
        print!("    {} {} ", icon, result.name);
        let dots_needed = 18usize.saturating_sub(result.name.len());
        print!("{}", ".".repeat(dots_needed));
        println!(" {}", result.message);
        if verbose && !result.details.is_empty() {
            println!("      └─ {}", result.details);
        }
    }

    let mut status = SysmonStatus::default();
    for r in &results {
        status.add(r);
    }

    println!("\n  Status:");
    if !status.has_issues() {
        println!("    \x1b[32m✓ All systems operational\x1b[0m");
    } else {
        if status.errors > 0 {
            println!("    \x1b[31m{} error(s)\x1b[0m", status.errors);
        }
        if status.warnings > 0 {
            println!("    \x1b[33m{} warning(s)\x1b[0m", status.warnings);
        }
        println!("    \x1b[32m{} ok\x1b[0m", status.ok);
    }
}
