use anyhow::Result;
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tracing::{debug, warn};

use crate::ipc::{AppState, Event};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct NiriState {
    pub workspaces: Vec<Workspace>,
    pub windows: Vec<Window>,
    pub focused_window: Option<Window>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Workspace {
    pub id: u64,
    pub idx: u8,
    pub name: Option<String>,
    pub output: Option<String>,
    pub is_active: bool,
    pub is_focused: bool,
    pub active_window_id: Option<u64>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Window {
    pub id: u64,
    pub title: Option<String>,
    pub app_id: Option<String>,
    pub workspace_id: Option<u64>,
    pub is_focused: bool,
}

fn niri_socket_path() -> Option<String> {
    std::env::var("NIRI_SOCKET").ok()
}

/// Send a request to niri's IPC socket and return raw JSON response
async fn niri_request(req: serde_json::Value) -> Result<serde_json::Value> {
    let path = niri_socket_path().ok_or_else(|| anyhow::anyhow!("NIRI_SOCKET not set"))?;
    let mut stream = UnixStream::connect(&path).await?;

    let msg = serde_json::to_string(&req)? + "\n";
    stream.write_all(msg.as_bytes()).await?;

    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    reader.read_line(&mut line).await?;

    Ok(serde_json::from_str(&line)?)
}

pub async fn activate_workspace(state: &AppState, id: u64) -> Result<()> {
    niri_request(serde_json::json!({
        "Action": { "FocusWorkspace": { "reference": { "Id": id } } }
    })).await?;
    Ok(())
}

pub async fn focus_window(state: &AppState, id: u64) -> Result<()> {
    niri_request(serde_json::json!({
        "Action": { "FocusWindow": { "id": id } }
    })).await?;
    Ok(())
}

async fn fetch_workspaces() -> Result<Vec<Workspace>> {
    let resp = niri_request(serde_json::json!({ "Request": "Workspaces" })).await?;
    let workspaces = resp["Ok"]["Workspaces"]
        .as_array()
        .ok_or_else(|| anyhow::anyhow!("invalid workspaces response"))?
        .iter()
        .map(|w| Workspace {
            id: w["id"].as_u64().unwrap_or(0),
            idx: w["idx"].as_u64().unwrap_or(0) as u8,
            name: w["name"].as_str().map(str::to_string),
            output: w["output"].as_str().map(str::to_string),
            is_active: w["is_active"].as_bool().unwrap_or(false),
            is_focused: w["is_focused"].as_bool().unwrap_or(false),
            active_window_id: w["active_window_id"].as_u64(),
        })
        .collect();
    Ok(workspaces)
}

async fn fetch_windows() -> Result<Vec<Window>> {
    let resp = niri_request(serde_json::json!({ "Request": "Windows" })).await?;
    let windows = resp["Ok"]["Windows"]
        .as_array()
        .ok_or_else(|| anyhow::anyhow!("invalid windows response"))?
        .iter()
        .map(|w| Window {
            id: w["id"].as_u64().unwrap_or(0),
            title: w["title"].as_str().map(str::to_string),
            app_id: w["app_id"].as_str().map(str::to_string),
            workspace_id: w["workspace_id"].as_u64(),
            is_focused: w["is_focused"].as_bool().unwrap_or(false),
        })
        .collect();
    Ok(windows)
}

/// Background worker — subscribes to niri event stream
pub async fn worker(state: AppState) {
    // Initial state fetch
    if let Ok(ws) = fetch_workspaces().await {
        state.inner.niri.write().await.workspaces = ws;
    }
    if let Ok(wins) = fetch_windows().await {
        let focused = wins.iter().find(|w| w.is_focused).cloned();
        let mut niri = state.inner.niri.write().await;
        niri.windows = wins;
        niri.focused_window = focused;
    }

    // Subscribe to event stream
    let path = match niri_socket_path() {
        Some(p) => p,
        None => {
            warn!("NIRI_SOCKET not set — niri IPC disabled");
            return;
        }
    };

    loop {
        match UnixStream::connect(&path).await {
            Ok(mut stream) => {
                // Send event subscription request
                let msg = serde_json::to_string(&serde_json::json!({ "Request": "EventStream" })).unwrap() + "\n";
                if stream.write_all(msg.as_bytes()).await.is_err() {
                    continue;
                }

                let mut reader = BufReader::new(stream);
                let mut line = String::new();

                loop {
                    line.clear();
                    match reader.read_line(&mut line).await {
                        Ok(0) => break, // EOF
                        Ok(_) => handle_niri_event(&state, &line).await,
                        Err(e) => {
                            warn!("niri event stream error: {e}");
                            break;
                        }
                    }
                }
            }
            Err(e) => {
                warn!("niri socket connect failed: {e}");
                tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
            }
        }
    }
}

async fn handle_niri_event(state: &AppState, line: &str) {
    let Ok(val) = serde_json::from_str::<serde_json::Value>(line) else { return };

    // WindowFocusChanged
    if let Some(wfc) = val.get("WindowFocusChanged") {
        let title = wfc["title"].as_str().unwrap_or("").to_string();
        let app_id = wfc["app_id"].as_str().unwrap_or("").to_string();
        debug!("niri: focus -> {app_id}: {title}");

        let window = Window {
            id: wfc["id"].as_u64().unwrap_or(0),
            title: Some(title.clone()),
            app_id: Some(app_id.clone()),
            workspace_id: None,
            is_focused: true,
        };
        state.inner.niri.write().await.focused_window = Some(window);
        state.emit(Event::NiriWindowFocus { title, app_id });
        return;
    }

    // WorkspaceActivated
    if let Some(wa) = val.get("WorkspaceActivated") {
        let id = wa["id"].as_u64().unwrap_or(0);
        let name = wa["name"].as_str().map(str::to_string);

        if let Ok(ws) = fetch_workspaces().await {
            state.inner.niri.write().await.workspaces = ws;
        }
        state.emit(Event::NiriWorkspaceChanged { id, name });
        return;
    }

    // WindowsChanged / WindowOpenedOrChanged / WindowClosed
    if val.get("WindowsChanged").is_some()
        || val.get("WindowOpenedOrChanged").is_some()
        || val.get("WindowClosed").is_some()
    {
        if let Ok(wins) = fetch_windows().await {
            let focused = wins.iter().find(|w| w.is_focused).cloned();
            let mut niri = state.inner.niri.write().await;
            niri.windows = wins;
            if let Some(f) = focused {
                niri.focused_window = Some(f);
            }
        }
        state.emit(Event::NiriWindowsChanged);
    }
}
