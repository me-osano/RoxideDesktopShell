use anyhow::Result;
use clap::{Parser, Subcommand};

use crate::ipc::server::socket_path;

#[derive(Parser)]
#[command(name = "rustiq", about = "RUSTIQ desktop shell daemon & CLI")]
pub struct Cli {
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
