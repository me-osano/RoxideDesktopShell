use sysd_proto::{NotifyCmd, Payload, Response, Urgency};
use zbus::Connection;

/// Maps our Urgency enum to freedesktop urgency hint (0=low, 1=normal, 2=critical)
fn urgency_byte(u: &Urgency) -> u8 {
    match u {
        Urgency::Low => 0,
        Urgency::Normal => 1,
        Urgency::Critical => 2,
    }
}

pub async fn handle(cmd: NotifyCmd, conn: &Connection) -> Response {
    match cmd {
        NotifyCmd::Send { summary, body, icon, urgency, timeout } => {
            let app_name = "sysd";
            let replaces_id: u32 = 0;
            let icon_str = icon.as_deref().unwrap_or("");
            let body_str = body.as_deref().unwrap_or("");
            let expire_timeout: i32 = timeout.unwrap_or(3000);

            // Build hints: urgency as a byte variant
            let urgency_val = urgency_byte(urgency.as_ref().unwrap_or(&Urgency::Normal));
            let mut hints = std::collections::HashMap::new();
            hints.insert(
                "urgency",
                zbus::zvariant::Value::U8(urgency_val),
            );

            // actions: empty slice
            let actions: &[&str] = &[];

            let result = conn
                .call_method(
                    Some("org.freedesktop.Notifications"),
                    "/org/freedesktop/Notifications",
                    Some("org.freedesktop.Notifications"),
                    "Notify",
                    &(
                        app_name,
                        replaces_id,
                        icon_str,
                        summary.as_str(),
                        body_str,
                        actions,
                        hints,
                        expire_timeout,
                    ),
                )
                .await;

            match result {
                Ok(msg) => {
                    let id: u32 = msg.body().deserialize().unwrap_or(0);
                    Response::ok(Payload::Notification { id })
                }
                Err(e) => Response::err(format!("notification failed: {e}")),
            }
        }

        NotifyCmd::Close { id } => {
            let result = conn
                .call_method(
                    Some("org.freedesktop.Notifications"),
                    "/org/freedesktop/Notifications",
                    Some("org.freedesktop.Notifications"),
                    "CloseNotification",
                    &(id,),
                )
                .await;
            match result {
                Ok(_) => Response::ok(Payload::Unit),
                Err(e) => Response::err(e.to_string()),
            }
        }

        NotifyCmd::CloseAll => {
            // There's no "close all" in the spec — we signal notification servers
            // by sending urgency=0 notifications to replace, or just no-op.
            Response::err("CloseAll not supported by the freedesktop.Notifications spec directly — close by id")
        }
    }
}
