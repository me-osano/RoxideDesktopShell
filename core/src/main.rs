mod cli;
mod ipc;
mod niri;
mod notify;
mod search;
mod sysmon;
mod weather;

use anyhow::Result;
use clap::Parser;
use cli::{Cli, Command};
use tracing::info;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<()> {
    // Init logging — RUSTIQ_LOG=debug rustiq daemon
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_env("RUSTIQ_LOG"))
        .init();

    let cli = Cli::parse();

    match cli.command {
        Command::Daemon => run_daemon().await,
        Command::Status => cli::status().await,
        Command::Sysmon => cli::sysmon_snapshot().await,
        Command::Search { query, limit } => cli::search(query, limit).await,
        Command::Weather => cli::weather_snapshot().await,
        Command::Niri { subcommand } => cli::niri_cmd(subcommand).await,
    }
}

async fn run_daemon() -> Result<()> {
    info!("Starting RUSTIQ daemon v{}", env!("CARGO_PKG_VERSION"));

    // Shared app state
    let state = ipc::AppState::new().await?;

    // Spawn background workers
    let sysmon_state = state.clone();
    tokio::spawn(async move {
        sysmon::worker(sysmon_state).await;
    });

    let niri_state = state.clone();
    tokio::spawn(async move {
        niri::worker(niri_state).await;
    });

    let weather_state = state.clone();
    tokio::spawn(async move {
        weather::worker(weather_state).await;
    });

    let search_state = state.clone();
    tokio::spawn(async move {
        search::worker(search_state).await;
    });

    let notify_state = state.clone();
    tokio::spawn(async move {
        notify::worker(notify_state).await;
    });

    // Start IPC server (blocks until shutdown)
    ipc::server::serve(state).await?;

    Ok(())
}
