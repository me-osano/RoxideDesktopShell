use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use tracing::{debug, info};
use zbus::{ConnectionBuilder, dbus_interface};

use crate::ipc::{AppState, Event};

static NOTIF_ID: AtomicU32 = AtomicU32::new(1);

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct NotificationStore {
    pub active: Vec<Notification>,
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

/// D-Bus interface implementation
struct NotificationsServer {
    state: AppState,
}

#[dbus_interface(name = "org.freedesktop.Notifications")]
impl NotificationsServer {
    fn get_capabilities(&self) -> Vec<String> {
        vec![
            "body".to_string(),
            "body-markup".to_string(),
            "icon-static".to_string(),
            "persistence".to_string(),
        ]
    }

    async fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        _actions: Vec<String>,
        hints: HashMap<String, zbus::zvariant::Value<'_>>,
        expire_timeout: i32,
    ) -> u32 {
        let id = if replaces_id > 0 {
            replaces_id
        } else {
            NOTIF_ID.fetch_add(1, Ordering::SeqCst)
        };

        let urgency = hints.get("urgency")
            .and_then(|v| v.downcast_ref::<u8>().ok())
            .copied()
            .unwrap_or(1);

        debug!("notification [{id}] from {app_name}: {summary}");

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
            // Replace if same ID, else push
            if let Some(pos) = store.active.iter().position(|n| n.id == id) {
                store.active[pos] = notif;
            } else {
                store.active.push(notif);
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
            "rustiq-notifications".to_string(),
            "RUSTIQ".to_string(),
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

/// Background worker — registers D-Bus service
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
            // Keep alive forever
            std::future::pending::<()>().await;
        }
        Err(e) => {
            tracing::warn!("notifications: D-Bus registration failed: {e}");
            tracing::warn!("Is another notification daemon running?");
        }
    }
}
