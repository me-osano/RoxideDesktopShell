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
use clap::{CommandFactory, Parser};
use clap_complete::Shell;
use cmd::{Cmd, Command};
use tracing::info;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<()> {
    let mut cmd = Cmd::command();
    
    let args: Vec<String> = std::env::args().collect();
    if args.len() >= 2 && args[1] == "completion" {
        if args.len() >= 3 {
            let shell: Shell = args[2].parse().expect("Invalid shell");
            clap_complete::generate(shell, &mut cmd, "roxide", &mut std::io::stdout());
            std::process::exit(0);
        } else {
            eprintln!("Usage: roxide completion <shell>");
            eprintln!("Supported shells: bash, elvish, fish, powershell, zsh");
            std::process::exit(1);
        }
    }

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_env("ROXIDE_LOG"))
        .init();

    let cmd = Cmd::parse();
    info!("Starting ROXIDE CLI v{}", env!("CARGO_PKG_VERSION"));

    match cmd.command {
        Command::Run { daemon, session } => cmd::run(daemon, session).await,
        Command::Daemon => run_daemon().await,
        Command::Stop => cmd::stop().await,
        Command::Status => cmd::status().await,
        Command::Restart => cmd::restart().await,
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
