use axum::{
    Json,
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
};
use serde::Deserialize;

use crate::ipc::{AppState, Response};

pub async fn ping() -> impl IntoResponse {
    Json(serde_json::json!({ "pong": true, "version": env!("CARGO_PKG_VERSION") }))
}

pub async fn sysmon(State(state): State<AppState>) -> impl IntoResponse {
    let snap = state.inner.sysmon.read().await.clone();
    Json(snap)
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
    // Launch via systemd-run for clean process lifecycle
    let status = tokio::process::Command::new("systemd-run")
        .args(["--user", "--scope", &params.app_id])
        .status()
        .await;

    match status {
        Ok(s) if s.success() => StatusCode::OK.into_response(),
        _ => {
            // Fallback: direct spawn
            let _ = tokio::process::Command::new(&params.app_id).spawn();
            StatusCode::OK.into_response()
        }
    }
}

pub async fn notifications(State(state): State<AppState>) -> impl IntoResponse {
    let store = state.inner.notifications.read().await;
    Json(store.active.clone())
}

pub async fn dismiss_notification(
    State(state): State<AppState>,
    Path(id): Path<u32>,
) -> impl IntoResponse {
    crate::notify::dismiss(&state, id).await;
    StatusCode::OK
}
