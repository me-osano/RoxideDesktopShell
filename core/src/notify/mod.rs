use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::time::Instant;
use tracing::{debug, info};
use zbus::{ConnectionBuilder, dbus_interface};

use crate::ipc::{AppState, Event};

static NOTIF_ID: AtomicU32 = AtomicU32::new(1);

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct NotificationStore {
    pub active: Vec<Notification>,
    pub history: Vec<Notification>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Notification {
    pub id: u32,
    pub app_name: String,
    pub app_icon: String,
    pub summary: String,
    pub body: String,
    pub urgency: u8,
    pub timeout_ms: i32,
    pub timestamp: i64,
}

impl Notification {
    fn is_duplicate(&self, other: &Notification) -> bool {
        self.app_name == other.app_name
            && self.summary == other.summary
            && self.body == other.body
    }
}

struct NotificationsServer {
    state: AppState,
}

fn extract_urgency(hints: &HashMap<String, zbus::zvariant::OwnedValue>) -> u8 {
    if let Some(v) = hints.get("urgency") {
        if let Ok(val) = v.downcast_ref::<u8>() {
            return val;
        }
        if let Ok(val) = v.downcast_ref::<i32>() {
            return val as u8;
        }
        if let Ok(val) = v.downcast_ref::<u32>() {
            return val as u8;
        }
    }
    1
}

#[dbus_interface(name = "org.freedesktop.Notifications")]
impl NotificationsServer {
    fn get_capabilities(&self) -> Vec<String> {
        vec![
            "body".to_string(),
            "body-markup".to_string(),
            "icon-static".to_string(),
            "persistence".to_string(),
            "action-icons".to_string(),
            "actions".to_string(),
        ]
    }

    async fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        hints: HashMap<String, zbus::zvariant::OwnedValue>,
        expire_timeout: i32,
    ) -> u32 {
        let id = if replaces_id > 0 {
            replaces_id
        } else {
            NOTIF_ID.fetch_add(1, Ordering::SeqCst)
        };

        let urgency = extract_urgency(&hints);

        let notif = Notification {
            id,
            app_name: app_name.clone(),
            app_icon,
            summary: summary.clone(),
            body: body.clone(),
            urgency,
            timeout_ms: expire_timeout,
            timestamp: chrono::Utc::now().timestamp(),
        };

        {
            let mut store = self.state.inner.notifications.write().await;
            
            if replaces_id == 0 {
                if let Some(last) = store.active.last() {
                    if last.is_duplicate(&notif) {
                        debug!("notification [{id}] deduplicated (matches recent)");
                        return last.id;
                    }
                }
            }

            if let Some(pos) = store.active.iter().position(|n| n.id == id) {
                store.active[pos] = notif.clone();
            } else {
                store.active.push(notif.clone());
            }

            store.history.insert(0, notif.clone());
            if store.history.len() > 100 {
                store.history.truncate(100);
            }
        }

        self.state.emit(Event::Notification {
            id,
            app_name,
            summary,
            body,
            urgency,
        });

        id
    }

    async fn close_notification(&self, id: u32) {
        dismiss(&self.state, id).await;
    }

    fn get_server_information(&self) -> (String, String, String, String) {
        (
            "roxide-notifications".to_string(),
            "ROXIDE".to_string(),
            env!("CARGO_PKG_VERSION").to_string(),
            "1.2".to_string(),
        )
    }
}

pub async fn dismiss(state: &AppState, id: u32) {
    let mut store = state.inner.notifications.write().await;
    store.active.retain(|n| n.id != id);
    state.emit(Event::NotificationClosed { id });
}

pub async fn dismiss_all(state: &AppState) {
    let mut store = state.inner.notifications.write().await;
    store.active.clear();
    state.emit(Event::NotificationClosed { id: 0 });
}

pub async fn get_history(state: &AppState) -> Vec<Notification> {
    let store = state.inner.notifications.read().await;
    store.history.clone()
}

pub async fn get_active(state: &AppState) -> Vec<Notification> {
    let store = state.inner.notifications.read().await;
    store.active.clone()
}

pub async fn clear_history(state: &AppState) {
    let mut store = state.inner.notifications.write().await;
    store.history.clear();
}

pub async fn worker(state: AppState) {
    info!("notifications: registering org.freedesktop.Notifications");

    let server = NotificationsServer { state };

    match ConnectionBuilder::session()
        .unwrap()
        .name("org.freedesktop.Notifications")
        .unwrap()
        .serve_at("/org/freedesktop/Notifications", server)
        .unwrap()
        .build()
        .await
    {
        Ok(_conn) => {
            info!("notifications: D-Bus server active");
            std::future::pending::<()>().await;
        }
        Err(e) => {
            tracing::warn!("notifications: D-Bus registration failed: {e}");
            tracing::warn!("Is another notification daemon running?");
        }
    }
}
