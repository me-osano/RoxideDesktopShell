use anyhow::Result;
use axum::extract::Query;
use axum::{
    extract::State,
    response::sse::{Event as SseEvent, Sse},
    routing::{get, post},
    Router,
};
use serde::Deserialize;
use std::path::PathBuf;
use std::str::FromStr;
use tokio::net::TcpListener;
use tokio_stream::StreamExt;
use tracing::info;

use super::handlers;
use crate::ipc::{AppState, EventType};

pub fn socket_path() -> PathBuf {
    let runtime = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(runtime).join("rustiq.sock")
}

pub async fn serve(state: AppState) -> Result<()> {
    let path = socket_path();
    let addr = format!("127.0.0.1:{}", std::env::var("RUSTIQ_PORT").unwrap_or_else(|_| "8765".to_string()));
    let addr_display = addr.clone();

    if path.exists() {
        std::fs::remove_file(&path)?;
    }

    let listener = TcpListener::bind(&addr).await?;
    info!("RUSTIQ IPC listening on {} (-> {})", addr_display, path.display());

    let router = Router::new()
        .route("/events", get(sse_handler))
        .route("/ping", get(handlers::ping))
        .route("/sysmon", get(handlers::sysmon))
        .route("/weather", get(handlers::weather))
        .route("/search", get(handlers::search))
        .route("/niri/workspaces", get(handlers::niri_workspaces))
        .route("/niri/windows", get(handlers::niri_windows))
        .route("/niri/workspaces/:id/activate", post(handlers::niri_activate_workspace))
        .route("/niri/windows/:id/focus", post(handlers::niri_focus_window))
        .route("/launch", post(handlers::launch))
        .route("/notifications", get(handlers::notifications))
        .route("/notifications/history", get(handlers::notification_history))
        .route("/notifications/:id/dismiss", post(handlers::dismiss_notification))
        .route("/notifications/dismiss-all", post(handlers::dismiss_all_notifications))
        .route("/notifications/clear-history", post(handlers::clear_notification_history))
        .route("/network", get(handlers::network))
        .route("/network/wifi", post(handlers::network_wifi))
        .route("/bluetooth", get(handlers::bluetooth))
        .route("/bluetooth/set", post(handlers::bluetooth_set))
        .route("/clipboard/list", get(handlers::clipboard_list))
        .route("/clipboard/:id/copy", post(handlers::clipboard_copy))
        .route("/clipboard/:id/delete", post(handlers::clipboard_delete))
        .route("/clipboard/wipe", post(handlers::clipboard_wipe))
        .route("/clipboard/:id/decode", get(handlers::clipboard_decode))
        .route("/brightness", get(handlers::brightness))
        .route("/brightness", post(handlers::brightness_set))
        .route("/brightness/devices", get(handlers::brightness_devices))
        .route("/brightness/select", post(handlers::brightness_select))
        .route("/brightness/increase", post(handlers::brightness_increase))
        .route("/brightness/decrease", post(handlers::brightness_decrease))
        .route("/media", get(handlers::media))
        .route("/media/:player/play", post(handlers::media_play))
        .route("/media/:player/pause", post(handlers::media_pause))
        .route("/media/:player/play-pause", post(handlers::media_play_pause))
        .route("/media/:player/stop", post(handlers::media_stop))
        .route("/media/:player/next", post(handlers::media_next))
        .route("/media/:player/previous", post(handlers::media_previous))
        .with_state(state);

    axum::serve(listener, router).await?;
    Ok(())
}

async fn sse_handler(
    State(state): State<AppState>,
    Query(params): Query<SseQueryParams>,
) -> Sse<impl tokio_stream::Stream<Item = Result<SseEvent, std::convert::Infallible>>> {
    let _filters = params.filters.map(|f| {
        f.split(',')
            .filter_map(|s| s.parse::<EventType>().ok())
            .collect::<Vec<_>>()
    });

    let stream = state.subscribe()
        .map(|msg| -> Result<SseEvent, std::convert::Infallible> {
            let event = match msg {
                Ok(e) => e,
                Err(_) => return Ok(SseEvent::default()),
            };
            match serde_json::to_string(&event) {
                Ok(data) => Ok(SseEvent::default().data(data)),
                Err(_) => Ok(SseEvent::default()),
            }
        });

    Sse::new(stream)
}

#[derive(Deserialize)]
pub struct SseQueryParams {
    pub filters: Option<String>,
}

impl FromStr for EventType {
    type Err = ();

    fn from_str(input: &str) -> Result<EventType, Self::Err> {
        match input {
            "sysmon_updated" => Ok(EventType::SysmonUpdated),
            "weather_updated" => Ok(EventType::WeatherUpdated),
            "niri_window_focus" => Ok(EventType::NiriWindowFocus),
            "niri_workspace_changed" => Ok(EventType::NiriWorkspaceChanged),
            "niri_windows_changed" => Ok(EventType::NiriWindowsChanged),
            "notification" => Ok(EventType::Notification),
            "notification_closed" => Ok(EventType::NotificationClosed),
            "clipboard_updated" => Ok(EventType::ClipboardUpdated),
            "brightness_updated" => Ok(EventType::BrightnessUpdated),
            "network_updated" => Ok(EventType::NetworkUpdated),
            "bluetooth_updated" => Ok(EventType::BluetoothUpdated),
            "media_player_changed" => Ok(EventType::MediaPlayerChanged),
            _ => Err(()),
        }
    }
}
