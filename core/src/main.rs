mod bluetooth;
mod brightness;
mod clipboard;
mod cli;
mod geolocation;
mod ipc;
mod media;
mod network;
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

    let state = ipc::AppState::new().await?;

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

    let clipboard_state = state.clone();
    tokio::spawn(async move {
        clipboard::ClipboardManager::worker(clipboard_state).await;
    });

    let brightness_state = state.clone();
    tokio::spawn(async move {
        brightness::BrightnessManager::worker(brightness_state).await;
    });

    let network_state = state.clone();
    tokio::spawn(async move {
        network::worker(network_state).await;
    });

    let bluetooth_state = state.clone();
    tokio::spawn(async move {
        bluetooth::worker(bluetooth_state).await;
    });

    ipc::server::serve(state).await?;

    Ok(())
}
