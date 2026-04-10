use sysd_proto::{NetInterface, NetworkCmd, Payload, Response};
use zbus::Connection;

// We use raw D-Bus calls here to avoid pulling in nm-specific crates.
// NetworkManager lives at org.freedesktop.NetworkManager

async fn nm_get_state(conn: &Connection) -> zbus::Result<u32> {
    let msg = conn
        .call_method(
            Some("org.freedesktop.NetworkManager"),
            "/org/freedesktop/NetworkManager",
            Some("org.freedesktop.DBus.Properties"),
            "Get",
            &("org.freedesktop.NetworkManager", "State"),
        )
        .await?;
    let (state,): (zbus::zvariant::Value,) = msg.body().deserialize()?;
    match state {
        zbus::zvariant::Value::U32(v) => Ok(v),
        _ => Ok(0),
    }
}

async fn nm_connectivity_state(conn: &Connection) -> bool {
    // NM state 70 = NM_STATE_CONNECTED_GLOBAL
    nm_get_state(conn).await.unwrap_or(0) >= 70
}

async fn nm_get_active_connections(conn: &Connection) -> Vec<NetInterface> {
    let mut ifaces = Vec::new();

    let Ok(msg) = conn
        .call_method(
            Some("org.freedesktop.NetworkManager"),
            "/org/freedesktop/NetworkManager",
            Some("org.freedesktop.DBus.Properties"),
            "Get",
            &("org.freedesktop.NetworkManager", "ActiveConnections"),
        )
        .await
    else {
        return ifaces;
    };

    let Ok((paths,)): Result<(zbus::zvariant::Value,), _> = msg.body().deserialize() else {
        return ifaces;
    };

    let zbus::zvariant::Value::Array(arr) = paths else {
        return ifaces;
    };

    for item in arr.iter() {
        let zbus::zvariant::Value::ObjectPath(path) = item else { continue };

        // Get connection type
        let Ok(type_msg) = conn
            .call_method(
                Some("org.freedesktop.NetworkManager"),
                path.as_str(),
                Some("org.freedesktop.DBus.Properties"),
                "Get",
                &("org.freedesktop.NetworkManager.Connection.Active", "Type"),
            )
            .await
        else {
            continue;
        };

        let Ok((type_val,)): Result<(zbus::zvariant::Value,), _> = type_msg.body().deserialize()
        else {
            continue;
        };

        let kind = match &type_val {
            zbus::zvariant::Value::Str(s) => s.to_string(),
            _ => "unknown".into(),
        };

        // Get Id (connection name/SSID)
        let ssid = conn
            .call_method(
                Some("org.freedesktop.NetworkManager"),
                path.as_str(),
                Some("org.freedesktop.DBus.Properties"),
                "Get",
                &("org.freedesktop.NetworkManager.Connection.Active", "Id"),
            )
            .await
            .ok()
            .and_then(|m| m.body().deserialize::<(zbus::zvariant::Value,)>().ok())
            .and_then(|(v,)| match v {
                zbus::zvariant::Value::Str(s) => Some(s.to_string()),
                _ => None,
            });

        ifaces.push(NetInterface {
            name: path.to_string(),
            kind: kind.clone(),
            state: "activated".into(),
            ssid: if kind == "802-11-wireless" { ssid } else { None },
        });
    }

    ifaces
}

async fn nm_wifi_toggle(conn: &Connection, enable: bool) -> zbus::Result<()> {
    conn.call_method(
        Some("org.freedesktop.NetworkManager"),
        "/org/freedesktop/NetworkManager",
        Some("org.freedesktop.DBus.Properties"),
        "Set",
        &(
            "org.freedesktop.NetworkManager",
            "WirelessEnabled",
            zbus::zvariant::Value::Bool(enable),
        ),
    )
    .await?;
    Ok(())
}

pub async fn handle(cmd: NetworkCmd, conn: &Connection) -> Response {
    match cmd {
        NetworkCmd::Status => {
            let connected = nm_connectivity_state(conn).await;
            let interfaces = nm_get_active_connections(conn).await;
            let ssid = interfaces
                .iter()
                .find(|i| i.kind == "802-11-wireless")
                .and_then(|i| i.ssid.clone());
            Response::ok(Payload::Network { connected, ssid, interfaces })
        }

        NetworkCmd::List => {
            let connected = nm_connectivity_state(conn).await;
            let interfaces = nm_get_active_connections(conn).await;
            Response::ok(Payload::Network { connected, ssid: None, interfaces })
        }

        NetworkCmd::Disconnect => {
            // Deactivate all active connections
            let interfaces = nm_get_active_connections(conn).await;
            for iface in &interfaces {
                let _ = conn
                    .call_method(
                        Some("org.freedesktop.NetworkManager"),
                        "/org/freedesktop/NetworkManager",
                        Some("org.freedesktop.NetworkManager"),
                        "DeactivateConnection",
                        &(zbus::zvariant::ObjectPath::try_from(iface.name.as_str())
                            .unwrap_or_else(|_| "/".try_into().unwrap()),),
                    )
                    .await;
            }
            Response::ok(Payload::Unit)
        }

        NetworkCmd::Toggle => {
            // Toggle wifi enabled
            let Ok(msg) = conn
                .call_method(
                    Some("org.freedesktop.NetworkManager"),
                    "/org/freedesktop/NetworkManager",
                    Some("org.freedesktop.DBus.Properties"),
                    "Get",
                    &("org.freedesktop.NetworkManager", "WirelessEnabled"),
                )
                .await
            else {
                return Response::err("failed to get WirelessEnabled");
            };
            let Ok((val,)): Result<(zbus::zvariant::Value,), _> = msg.body().deserialize() else {
                return Response::err("failed to parse WirelessEnabled");
            };
            let current = matches!(val, zbus::zvariant::Value::Bool(true));
            match nm_wifi_toggle(conn, !current).await {
                Ok(_) => Response::ok(Payload::Unit),
                Err(e) => Response::err(e.to_string()),
            }
        }

        NetworkCmd::Connect { ssid, password: _ } => {
            // Full WPA connect requires adding a new connection profile.
            // For now, we attempt to activate by SSID match via nmcli-style call.
            // This is a placeholder — full implementation requires AddAndActivateConnection.
            Response::err(format!(
                "connect to '{ssid}' not yet implemented via D-Bus directly — use `nmcli dev wifi connect '{ssid}'` or implement AddAndActivateConnection"
            ))
        }
    }
}
