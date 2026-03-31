pub mod handlers;
pub mod server;

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::{broadcast, RwLock};

use crate::niri::NiriState;
use crate::notify::NotificationStore;
use crate::sysmon::SysmonSnapshot;
use crate::weather::WeatherSnapshot;

/// Shared daemon state — cloned cheaply via Arc
#[derive(Clone)]
pub struct AppState {
    pub inner: Arc<Inner>,
}

pub struct Inner {
    pub sysmon: RwLock<SysmonSnapshot>,
    pub weather: RwLock<Option<WeatherSnapshot>>,
    pub niri: RwLock<NiriState>,
    pub notifications: RwLock<NotificationStore>,
    /// Broadcast channel — QML subscribers receive pushed events
    pub events: broadcast::Sender<Event>,
}

impl AppState {
    pub async fn new() -> Result<Self> {
        let (tx, _) = broadcast::channel(256);
        Ok(Self {
            inner: Arc::new(Inner {
                sysmon: RwLock::new(SysmonSnapshot::default()),
                weather: RwLock::new(None),
                niri: RwLock::new(NiriState::default()),
                notifications: RwLock::new(NotificationStore::default()),
                events: tx,
            }),
        })
    }

    pub fn subscribe(&self) -> broadcast::Receiver<Event> {
        self.inner.events.subscribe()
    }

    pub fn emit(&self, event: Event) {
        let _ = self.inner.events.send(event);
    }
}

/// Events pushed to QML over the event stream
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Event {
    SysmonUpdated,
    WeatherUpdated,
    NiriWindowFocus {
        title: String,
        app_id: String,
    },
    NiriWorkspaceChanged {
        id: u64,
        name: Option<String>,
    },
    NiriWindowsChanged,
    Notification {
        id: u32,
        app_name: String,
        summary: String,
        body: String,
        urgency: u8,
    },
    NotificationClosed {
        id: u32,
    },
}

/// Request envelope from QML
#[derive(Debug, Deserialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
pub enum Request {
    Ping,
    Sysmon,
    Weather,
    Search {
        query: String,
        #[serde(default = "default_limit")]
        limit: usize,
    },
    NiriWorkspaces,
    NiriWindows,
    NiriActivateWorkspace {
        id: u64,
    },
    NiriFocusWindow {
        id: u64,
    },
    Launch {
        app_id: String,
    },
    DismissNotification {
        id: u32,
    },
    Subscribe, // Upgrades connection to SSE event stream
}

fn default_limit() -> usize {
    20
}

/// Response envelope to QML
#[derive(Debug, Serialize)]
#[serde(tag = "ok", rename_all = "snake_case")]
pub enum Response {
    Pong,
    Sysmon(crate::sysmon::SysmonSnapshot),
    Weather(Option<crate::weather::WeatherSnapshot>),
    SearchResults(crate::search::SearchResults),
    NiriWorkspaces(Vec<crate::niri::Workspace>),
    NiriWindows(Vec<crate::niri::Window>),
    Done,
    Error { message: String },
}
