mod modules;

use anyhow::Result;
use modules::{bluetooth, brightness, clipboard, network, notifications};
use std::sync::Arc;
use sysd_proto::{socket_path, Request, Response};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tracing::{error, info, warn};

#[derive(Clone)]
struct AppState {
    dbus: Arc<zbus::Connection>,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("sysd=info".parse()?),
        )
        .init();

    let sock_path = socket_path();

    // Clean up stale socket
    if std::path::Path::new(&sock_path).exists() {
        std::fs::remove_file(&sock_path)?;
    }

    let listener = UnixListener::bind(&sock_path)?;
    info!("sysd listening on {sock_path}");

    // Single shared D-Bus session connection
    let dbus = Arc::new(zbus::Connection::session().await?);
    let state = AppState { dbus };

    loop {
        match listener.accept().await {
            Ok((stream, _)) => {
                let state = state.clone();
                tokio::spawn(async move {
                    if let Err(e) = handle_client(stream, state).await {
                        warn!("client error: {e}");
                    }
                });
            }
            Err(e) => error!("accept error: {e}"),
        }
    }
}

async fn handle_client(stream: UnixStream, state: AppState) -> Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();

    while let Some(line) = lines.next_line().await? {
        let line = line.trim().to_string();
        if line.is_empty() {
            continue;
        }

        let response = match serde_json::from_str::<Request>(&line) {
            Ok(req) => {
                info!("← {req:?}");
                dispatch(req, &state).await
            }
            Err(e) => Response::err(format!("parse error: {e}")),
        };

        let mut out = serde_json::to_string(&response)?;
        out.push('\n');
        writer.write_all(out.as_bytes()).await?;
    }

    Ok(())
}

async fn dispatch(req: Request, state: &AppState) -> Response {
    match req {
        Request::Ping => Response::ok(sysd_proto::Payload::Pong),
        Request::Brightness(cmd) => brightness::handle(cmd).await,
        Request::Bluetooth(cmd) => bluetooth::handle(cmd, &state.dbus).await,
        Request::Network(cmd) => network::handle(cmd, &state.dbus).await,
        Request::Clipboard(cmd) => clipboard::handle(cmd).await,
        Request::Notify(cmd) => notifications::handle(cmd, &state.dbus).await,
    }
}
