mod bluetooth;
mod brightness;
mod clipboard;
mod cmd;
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
use cmd::{Cmd, Command};
use tracing::info;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_env("ROXIDE_LOG"))
        .init();

    let cmd = Cmd::parse();

    match cmd.command {
        Command::Daemon => run_daemon().await,
        Command::Status => cmd::status().await,
        Command::RunRqs { daemon, session } => cmd::run_rqs(daemon, session).await,
        Command::Restart => cmd::restart_rqs().await,
        Command::Kill => cmd::kill_rqs().await,
        Command::Sysmon { verbose, json } => cmd::sysmon_snapshot(verbose, json).await,
        Command::Search { query, limit } => cmd::search(query, limit).await,
        Command::Weather => cmd::weather_snapshot().await,
        Command::Niri { subcommand } => cmd::niri_cmd(subcommand).await,
        Command::Brightness { subcommand } => cmd::brightness_cmd(subcommand).await,
    }
}

async fn run_daemon() -> Result<()> {
    info!("Starting ROXIDE daemon v{}", env!("CARGO_PKG_VERSION"));

    let state = ipc::AppState::new().await?;

    let sysmon_state = state.clone();
    tokio::spawn(async move {
        sysmon::worker(sysmon_state).await;
    });

    let sysmon_procs_state = state.clone();
    tokio::spawn(async move {
        sysmon::processes_worker(sysmon_procs_state).await;
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
