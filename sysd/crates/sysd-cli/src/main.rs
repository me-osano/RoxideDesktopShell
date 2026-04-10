mod ipc;

use anyhow::Result;
use clap::{Parser, Subcommand};
use sysd_proto::{
    BluetoothCmd, BrightnessCmd, ClipboardCmd, NetworkCmd, NotifyCmd, Request, Urgency,
};

#[derive(Parser)]
#[command(name = "sysd", about = "System control CLI", version)]
struct Cli {
    /// Output raw JSON response
    #[arg(long, global = true)]
    json: bool,

    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Ping the daemon
    Ping,

    /// Screen brightness control
    Brightness {
        #[command(subcommand)]
        action: BrightnessAction,
    },

    /// Bluetooth control
    #[command(alias = "bt")]
    Bluetooth {
        #[command(subcommand)]
        action: BluetoothAction,
    },

    /// Network / Wi-Fi control
    #[command(alias = "net")]
    Network {
        #[command(subcommand)]
        action: NetworkAction,
    },

    /// Clipboard access
    #[command(alias = "clip")]
    Clipboard {
        #[command(subcommand)]
        action: ClipboardAction,
    },

    /// Send desktop notifications
    #[command(alias = "notif")]
    Notify {
        #[command(subcommand)]
        action: NotifyAction,
    },
}

#[derive(Subcommand)]
enum BrightnessAction {
    /// Get current brightness
    Get,
    /// Set brightness (0–100)
    Set { value: u8 },
    /// Increase brightness
    Inc {
        #[arg(default_value = "5")]
        step: u8,
    },
    /// Decrease brightness
    Dec {
        #[arg(default_value = "5")]
        step: u8,
    },
}

#[derive(Subcommand)]
enum BluetoothAction {
    /// Show bluetooth status and devices
    Status,
    /// Toggle bluetooth on/off
    Toggle,
    /// Turn bluetooth on
    On,
    /// Turn bluetooth off
    Off,
    /// Scan for nearby devices (5s)
    Scan,
    /// List known devices
    List,
    /// Connect to a device by MAC
    Connect { address: String },
    /// Disconnect a device by MAC
    Disconnect { address: String },
}

#[derive(Subcommand)]
enum NetworkAction {
    /// Show network status
    Status,
    /// List active connections
    List,
    /// Connect to a Wi-Fi network
    Connect {
        ssid: String,
        #[arg(short, long)]
        password: Option<String>,
    },
    /// Disconnect all active connections
    Disconnect,
    /// Toggle Wi-Fi
    Toggle,
}

#[derive(Subcommand)]
enum ClipboardAction {
    /// Read clipboard contents
    Get,
    /// Write to clipboard
    Set { content: String },
    /// Clear clipboard
    Clear,
}

#[derive(Subcommand)]
enum NotifyAction {
    /// Send a notification
    Send {
        summary: String,
        #[arg(short, long)]
        body: Option<String>,
        #[arg(short, long)]
        icon: Option<String>,
        #[arg(short, long, value_enum, default_value = "normal")]
        urgency: UrgencyCli,
        /// Timeout in ms (-1 = never)
        #[arg(short, long)]
        timeout: Option<i32>,
    },
    /// Close a notification by ID
    Close { id: u32 },
}

#[derive(clap::ValueEnum, Clone)]
enum UrgencyCli {
    Low,
    Normal,
    Critical,
}

impl From<UrgencyCli> for Urgency {
    fn from(u: UrgencyCli) -> Self {
        match u {
            UrgencyCli::Low => Urgency::Low,
            UrgencyCli::Normal => Urgency::Normal,
            UrgencyCli::Critical => Urgency::Critical,
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    let request = match cli.cmd {
        Cmd::Ping => Request::Ping,

        Cmd::Brightness { action } => Request::Brightness(match action {
            BrightnessAction::Get => BrightnessCmd::Get,
            BrightnessAction::Set { value } => BrightnessCmd::Set { value },
            BrightnessAction::Inc { step } => BrightnessCmd::Inc { step },
            BrightnessAction::Dec { step } => BrightnessCmd::Dec { step },
        }),

        Cmd::Bluetooth { action } => Request::Bluetooth(match action {
            BluetoothAction::Status => BluetoothCmd::Status,
            BluetoothAction::Toggle => BluetoothCmd::Toggle,
            BluetoothAction::On => BluetoothCmd::Enable,
            BluetoothAction::Off => BluetoothCmd::Disable,
            BluetoothAction::Scan => BluetoothCmd::Scan,
            BluetoothAction::List => BluetoothCmd::ListDevices,
            BluetoothAction::Connect { address } => BluetoothCmd::Connect { address },
            BluetoothAction::Disconnect { address } => BluetoothCmd::Disconnect { address },
        }),

        Cmd::Network { action } => Request::Network(match action {
            NetworkAction::Status => NetworkCmd::Status,
            NetworkAction::List => NetworkCmd::List,
            NetworkAction::Connect { ssid, password } => NetworkCmd::Connect { ssid, password },
            NetworkAction::Disconnect => NetworkCmd::Disconnect,
            NetworkAction::Toggle => NetworkCmd::Toggle,
        }),

        Cmd::Clipboard { action } => Request::Clipboard(match action {
            ClipboardAction::Get => ClipboardCmd::Get,
            ClipboardAction::Set { content } => ClipboardCmd::Set { content },
            ClipboardAction::Clear => ClipboardCmd::Clear,
        }),

        Cmd::Notify { action } => Request::Notify(match action {
            NotifyAction::Send { summary, body, icon, urgency, timeout } => NotifyCmd::Send {
                summary,
                body,
                icon,
                urgency: Some(urgency.into()),
                timeout,
            },
            NotifyAction::Close { id } => NotifyCmd::Close { id },
        }),
    };

    let response = ipc::send(request).await?;

    if cli.json {
        println!("{}", serde_json::to_string_pretty(&response)?);
        return Ok(());
    }

    // Human-readable output
    use sysd_proto::{Payload, Response};
    match response {
        Response::Err { message } => {
            eprintln!("error: {message}");
            std::process::exit(1);
        }
        Response::Ok(payload) => match payload {
            Payload::Pong => println!("pong"),
            Payload::Unit => println!("ok"),
            Payload::Brightness { percent, raw, max } => {
                println!("brightness: {percent}%  (raw {raw}/{max})");
            }
            Payload::Bluetooth { enabled, devices } => {
                println!("bluetooth: {}", if enabled { "on" } else { "off" });
                for d in &devices {
                    println!(
                        "  {} {}  {}  {}",
                        if d.connected { "●" } else { "○" },
                        d.address,
                        d.name,
                        if d.paired { "(paired)" } else { "" }
                    );
                }
            }
            Payload::Network { connected, ssid, interfaces } => {
                println!("network: {}", if connected { "connected" } else { "disconnected" });
                if let Some(s) = ssid {
                    println!("  ssid: {s}");
                }
                for iface in &interfaces {
                    println!("  {} [{}] {}", iface.name, iface.kind, iface.state);
                }
            }
            Payload::Clipboard { content } => match content {
                Some(c) => println!("{c}"),
                None => println!("(empty)"),
            },
            Payload::Notification { id } => println!("sent notification id={id}"),
        },
    }

    Ok(())
}
