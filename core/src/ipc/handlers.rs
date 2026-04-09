use axum::{
    Json,
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
};
use serde::Deserialize;

use crate::ipc::AppState;

pub async fn ping() -> impl IntoResponse {
    Json(serde_json::json!({ "pong": true, "version": env!("CARGO_PKG_VERSION") }))
}

pub async fn shutdown() -> impl IntoResponse {
    std::process::exit(0);
}

pub async fn sysmon(State(state): State<AppState>) -> impl IntoResponse {
    let snap = state.inner.sysmon.read().await.clone();
    Json(snap)
}

pub async fn sysmon_processes(State(state): State<AppState>) -> impl IntoResponse {
    let procs = state.inner.sysmon_processes.read().await.clone();
    Json(procs)
}

pub async fn weather(State(state): State<AppState>) -> impl IntoResponse {
    let snap = state.inner.weather.read().await.clone();
    Json(snap)
}

#[derive(Deserialize)]
pub struct SearchParams {
    pub q: String,
    #[serde(default = "default_limit")]
    pub limit: usize,
}
fn default_limit() -> usize { 20 }

pub async fn search(
    State(state): State<AppState>,
    Query(params): Query<SearchParams>,
) -> impl IntoResponse {
    match crate::search::query(&state, &params.q, params.limit).await {
        Ok(results) => Json(results).into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn niri_workspaces(State(state): State<AppState>) -> impl IntoResponse {
    let niri = state.inner.niri.read().await;
    Json(niri.workspaces.clone())
}

pub async fn niri_windows(State(state): State<AppState>) -> impl IntoResponse {
    let niri = state.inner.niri.read().await;
    Json(niri.windows.clone())
}

pub async fn niri_activate_workspace(
    State(state): State<AppState>,
    Path(id): Path<u64>,
) -> impl IntoResponse {
    match crate::niri::activate_workspace(&state, id).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn niri_focus_window(
    State(state): State<AppState>,
    Path(id): Path<u64>,
) -> impl IntoResponse {
    match crate::niri::focus_window(&state, id).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

#[derive(Deserialize)]
pub struct LaunchParams {
    pub app_id: String,
}

pub async fn launch(
    Json(params): Json<LaunchParams>,
) -> impl IntoResponse {
    let status = tokio::process::Command::new("systemd-run")
        .args(["--user", "--scope", &params.app_id])
        .status()
        .await;

    match status {
        Ok(s) if s.success() => StatusCode::OK.into_response(),
        _ => {
            let _ = tokio::process::Command::new(&params.app_id).spawn();
            StatusCode::OK.into_response()
        }
    }
}

pub async fn notifications(State(state): State<AppState>) -> impl IntoResponse {
    let store = state.inner.notifications.read().await;
    Json(store.active.clone())
}

pub async fn notification_history(State(state): State<AppState>) -> impl IntoResponse {
    let store = state.inner.notifications.read().await;
    Json(store.history.clone())
}

pub async fn dismiss_notification(
    State(state): State<AppState>,
    Path(id): Path<u32>,
) -> impl IntoResponse {
    crate::notify::dismiss(&state, id).await;
    StatusCode::OK
}

pub async fn dismiss_all_notifications(State(state): State<AppState>) -> impl IntoResponse {
    crate::notify::dismiss_all(&state).await;
    StatusCode::OK
}

pub async fn clear_notification_history(State(state): State<AppState>) -> impl IntoResponse {
    crate::notify::clear_history(&state).await;
    StatusCode::OK
}

pub async fn network(State(state): State<AppState>) -> impl IntoResponse {
    let snap = state.inner.network.get_state().await;
    Json(snap)
}

#[derive(Deserialize)]
pub struct WifiParams {
    pub enabled: bool,
}

pub async fn network_wifi(
    State(state): State<AppState>,
    Json(params): Json<WifiParams>,
) -> impl IntoResponse {
    match state.inner.network.set_wifi_enabled(params.enabled).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e).into_response(),
    }
}

pub async fn bluetooth(State(state): State<AppState>) -> impl IntoResponse {
    let snap = state.inner.bluetooth.get_state().await;
    Json(snap)
}

#[derive(Deserialize)]
pub struct BluetoothParams {
    pub enabled: bool,
}

pub async fn bluetooth_set(
    State(state): State<AppState>,
    Json(params): Json<BluetoothParams>,
) -> impl IntoResponse {
    match state.inner.bluetooth.set_enabled(params.enabled).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e).into_response(),
    }
}

pub async fn clipboard_list(State(state): State<AppState>) -> impl IntoResponse {
    match state.inner.clipboard.list(100).await {
        Ok(items) => Json::<Vec<crate::clipboard::ClipboardItem>>(items).into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

#[derive(Deserialize)]
pub struct ClipboardParams {
    pub id: String,
}

pub async fn clipboard_copy(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match state.inner.clipboard.copy(&id).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn clipboard_delete(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match state.inner.clipboard.delete(&id).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn clipboard_wipe(State(state): State<AppState>) -> impl IntoResponse {
    match state.inner.clipboard.wipe().await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn clipboard_decode(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match state.inner.clipboard.decode(&id).await {
        Ok(content) => Json(serde_json::json!({ "content": content })).into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn brightness(State(state): State<AppState>) -> impl IntoResponse {
    let snap = state.inner.brightness.get_state().await;
    Json(snap)
}

#[derive(Deserialize)]
pub struct BrightnessSetParams {
    pub device: Option<String>,
    pub value: f32,
    pub exponential: Option<bool>,
    pub exponent: Option<f64>,
}

pub async fn brightness_set(
    State(state): State<AppState>,
    Json(params): Json<BrightnessSetParams>,
) -> impl IntoResponse {
    let selected = state.inner.brightness.state.read().await.selected_device.clone();
    let device = params.device.unwrap_or_else(|| selected.unwrap_or_default());
    let exponential = params.exponential.unwrap_or(false);
    let exponent = params.exponent.unwrap_or(1.2);

    match state.inner.brightness.set_brightness(&device, params.value, exponential, exponent).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

#[derive(Deserialize)]
pub struct BrightnessDeltaParams {
    pub device: Option<String>,
    pub delta: f32,
    pub exponential: Option<bool>,
    pub exponent: Option<f64>,
}

pub async fn brightness_increase(
    State(state): State<AppState>,
    Json(params): Json<BrightnessDeltaParams>,
) -> impl IntoResponse {
    let exponential = params.exponential.unwrap_or(false);
    let exponent = params.exponent.unwrap_or(1.2);

    match state.inner.brightness.increase(params.delta, exponential, exponent).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn brightness_decrease(
    State(state): State<AppState>,
    Json(params): Json<BrightnessDeltaParams>,
) -> impl IntoResponse {
    let exponential = params.exponential.unwrap_or(false);
    let exponent = params.exponent.unwrap_or(1.2);

    match state.inner.brightness.decrease(params.delta, exponential, exponent).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn brightness_devices(State(state): State<AppState>) -> impl IntoResponse {
    let devices = state.inner.brightness.get_devices().await;
    Json(devices)
}

#[derive(Deserialize)]
pub struct BrightnessSelectParams {
    pub device: String,
}

pub async fn brightness_select(
    State(state): State<AppState>,
    Json(params): Json<BrightnessSelectParams>,
) -> impl IntoResponse {
    match state.inner.brightness.set_selected_device(&params.device).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::NOT_FOUND, e.to_string()).into_response(),
    }
}

pub async fn media(State(state): State<AppState>) -> impl IntoResponse {
    let snap = state.inner.media.get_state().await;
    Json(snap)
}

#[derive(Deserialize)]
pub struct MediaParams {
    pub player: String,
}

pub async fn media_play(
    State(state): State<AppState>,
    Path(player): Path<String>,
) -> impl IntoResponse {
    match state.inner.media.play(&player).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn media_pause(
    State(state): State<AppState>,
    Path(player): Path<String>,
) -> impl IntoResponse {
    match state.inner.media.pause(&player).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn media_play_pause(
    State(state): State<AppState>,
    Path(player): Path<String>,
) -> impl IntoResponse {
    match state.inner.media.play_pause(&player).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn media_stop(
    State(state): State<AppState>,
    Path(player): Path<String>,
) -> impl IntoResponse {
    match state.inner.media.stop(&player).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn media_next(
    State(state): State<AppState>,
    Path(player): Path<String>,
) -> impl IntoResponse {
    match state.inner.media.next(&player).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

pub async fn media_previous(
    State(state): State<AppState>,
    Path(player): Path<String>,
) -> impl IntoResponse {
    match state.inner.media.previous(&player).await {
        Ok(_) => StatusCode::OK.into_response(),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}
