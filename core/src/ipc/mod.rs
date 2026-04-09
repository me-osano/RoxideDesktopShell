pub mod handlers;
pub mod server;

use std::sync::Arc;

use anyhow::Result;
use serde::{Deserialize, Serialize};
use tokio::sync::{broadcast, RwLock};
use tokio_stream::wrappers::BroadcastStream;

use crate::niri::NiriState;
use crate::notify::NotificationStore;
use crate::sysmon::{SystemMonitor, SystemProcesses};
use crate::weather::WeatherSnapshot;

#[derive(Clone)]
pub struct AppState {
    pub inner: Arc<Inner>,
}

pub struct Inner {
    pub sysmon: RwLock<SystemMonitor>,
    pub sysmon_processes: RwLock<SystemProcesses>,
    pub weather: RwLock<Option<WeatherSnapshot>>,
    pub niri: RwLock<NiriState>,
    pub notifications: RwLock<NotificationStore>,
    pub network: crate::network::NetworkManager,
    pub bluetooth: crate::bluetooth::BluetoothManager,
    pub clipboard: crate::clipboard::ClipboardManager,
    pub brightness: crate::brightness::BrightnessManager,
    pub media: crate::media::MediaManager,
    pub events: broadcast::Sender<Event>,
}

impl AppState {
    pub async fn new() -> Result<Self> {
        let (tx, _) = broadcast::channel(256);
        Ok(Self {
            inner: Arc::new(Inner {
                sysmon: RwLock::new(SystemMonitor::default()),
                sysmon_processes: RwLock::new(SystemProcesses::default()),
                weather: RwLock::new(None),
                niri: RwLock::new(NiriState::default()),
                notifications: RwLock::new(NotificationStore::default()),
                network: crate::network::NetworkManager::new(),
                bluetooth: crate::bluetooth::BluetoothManager::new(),
                clipboard: crate::clipboard::ClipboardManager::new(),
                brightness: crate::brightness::BrightnessManager::new(),
                media: crate::media::MediaManager::new(),
                events: tx,
            }),
        })
    }

    pub fn subscribe(&self) -> BroadcastStream<Event> {
        BroadcastStream::new(self.inner.events.subscribe())
    }

    pub fn emit(&self, event: Event) {
        let _ = self.inner.events.send(event);
    }
}

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
    ClipboardUpdated,
    BrightnessUpdated,
    NetworkUpdated,
    BluetoothUpdated,
    MediaPlayerChanged {
        name: String,
    },
}

impl Event {
    pub fn event_type(&self) -> EventType {
        match self {
            Event::SysmonUpdated => EventType::SysmonUpdated,
            Event::WeatherUpdated => EventType::WeatherUpdated,
            Event::NiriWindowFocus { .. } => EventType::NiriWindowFocus,
            Event::NiriWorkspaceChanged { .. } => EventType::NiriWorkspaceChanged,
            Event::NiriWindowsChanged => EventType::NiriWindowsChanged,
            Event::Notification { .. } => EventType::Notification,
            Event::NotificationClosed { .. } => EventType::NotificationClosed,
            Event::ClipboardUpdated => EventType::ClipboardUpdated,
            Event::BrightnessUpdated => EventType::BrightnessUpdated,
            Event::NetworkUpdated => EventType::NetworkUpdated,
            Event::BluetoothUpdated => EventType::BluetoothUpdated,
            Event::MediaPlayerChanged { .. } => EventType::MediaPlayerChanged,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum EventType {
    SysmonUpdated,
    WeatherUpdated,
    NiriWindowFocus,
    NiriWorkspaceChanged,
    NiriWindowsChanged,
    Notification,
    NotificationClosed,
    ClipboardUpdated,
    BrightnessUpdated,
    NetworkUpdated,
    BluetoothUpdated,
    MediaPlayerChanged,
}
