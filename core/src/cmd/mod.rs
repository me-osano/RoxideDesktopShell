use anyhow::Result;
use clap::{Parser, Subcommand};

use crate::ipc::server::socket_path;

#[derive(Parser)]
#[command(name = "rustiq", about = "RUSTIQ desktop shell daemon & CLI")]
pub struct Cmd {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    /// Start the RUSTIQ daemon
    Daemon,
    /// Check daemon status
    Status,
    /// Print system snapshot
    Sysmon,
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
    /// Run diagnostic checks
    Doctor,
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

/// HTTP client pointed at the daemon's Unix socket
fn client() -> reqwest::Client {
    // reqwest doesn't natively support Unix sockets in stable;
    // in practice, use a tiny hyper/tower client or just `rustiq ipc` via the socket directly.
    // For now, stub — users can also just curl the socket.
    reqwest::Client::new()
}

pub async fn status() -> Result<()> {
    let path = socket_path();
    if path.exists() {
        println!("RUSTIQ daemon: running ({})", path.display());
    } else {
        println!("RUSTIQ daemon: not running");
    }
    Ok(())
}

pub async fn sysmon_snapshot() -> Result<()> {
    println!("Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/sysmon | jq");
    Ok(())
}

pub async fn search(query: String, limit: usize) -> Result<()> {
    println!("Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock 'http://localhost/search?q={query}&limit={limit}' | jq");
    Ok(())
}

pub async fn weather_snapshot() -> Result<()> {
    println!("Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/weather | jq");
    Ok(())
}

pub async fn niri_cmd(subcommand: NiriCommand) -> Result<()> {
    match subcommand {
        NiriCommand::Workspaces => println!("Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/niri/workspaces | jq"),
        NiriCommand::Windows    => println!("Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/niri/windows | jq"),
        NiriCommand::Activate { id } => println!("Use: curl -X POST --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/niri/workspace/{id}/activate"),
        NiriCommand::Focus { id }    => println!("Use: curl -X POST --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/niri/window/{id}/focus"),
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

pub async fn doctor() -> Result<()> {
    println!("RUSTIQ Doctor - Running diagnostic checks...\n");

    let socket_path = socket_path();
    if socket_path.exists() {
        println!("[OK] IPC socket exists at {}", socket_path.display());
    } else {
        println!("[FAIL] IPC socket not found at {}", socket_path.display());
        println!("       Daemon may not be running. Try 'rustiq daemon'");
    }

    if let Ok(devices) = crate::brightness::SysfsBackend::new().and_then(|b| b.get_devices()) {
        if devices.is_empty() {
            println!("[WARN] No brightness devices found");
        } else {
            println!("[OK] Found {} brightness device(s)", devices.len());
            for d in &devices {
                println!("       - {} ({}%)", d.id, d.current_percent);
            }
        }
    }

    if let Ok(output) = std::process::Command::new("niri").arg("--version").output() {
        if output.status.success() {
            let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
            println!("[OK] Niri window manager detected: {}", version);
        }
    }

    println!("\nDoctor check complete.");
    Ok(())
}
