use anyhow::Result;
use axum::{
    Router,
    extract::State,
    response::sse::{Event as SseEvent, Sse},
    routing::{get, post},
};
use std::{convert::Infallible, path::PathBuf};
use tokio::net::UnixListener;
use tokio_stream::wrappers::BroadcastStream;
use tokio_stream::StreamExt;
use tracing::info;

use crate::ipc::AppState;
use super::handlers;

pub fn socket_path() -> PathBuf {
    let runtime = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(runtime).join("rustiq.sock")
}

pub async fn serve(state: AppState) -> Result<()> {
    let path = socket_path();

    // Remove stale socket
    if path.exists() {
        std::fs::remove_file(&path)?;
    }

    let router = Router::new()
        .route("/ping",              get(handlers::ping))
        .route("/sysmon",            get(handlers::sysmon))
        .route("/weather",           get(handlers::weather))
        .route("/search",            get(handlers::search))
        .route("/niri/workspaces",   get(handlers::niri_workspaces))
        .route("/niri/windows",      get(handlers::niri_windows))
        .route("/niri/workspace/:id/activate", post(handlers::niri_activate_workspace))
        .route("/niri/window/:id/focus",       post(handlers::niri_focus_window))
        .route("/launch",            post(handlers::launch))
        .route("/notifications",     get(handlers::notifications))
        .route("/notifications/:id/dismiss", post(handlers::dismiss_notification))
        .route("/events",            get(sse_handler))  // SSE event stream
        .with_state(state);

    let listener = UnixListener::bind(&path)?;
    info!("RUSTIQ IPC listening on {:?}", path);

    axum::serve(listener, router).await?;
    Ok(())
}

/// SSE endpoint — QML subscribes once and receives all pushed events
async fn sse_handler(
    State(state): State<AppState>,
) -> Sse<impl futures_core::Stream<Item = Result<SseEvent, Infallible>>> {
    let rx = state.subscribe();
    let stream = BroadcastStream::new(rx).filter_map(|msg| {
        msg.ok().and_then(|event| {
            serde_json::to_string(&event).ok().map(|data| {
                Ok(SseEvent::default().data(data))
            })
        })
    });
    Sse::new(stream)
}
