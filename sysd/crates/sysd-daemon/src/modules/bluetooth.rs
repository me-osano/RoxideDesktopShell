use sysd_proto::{BluetoothCmd, BtDevice, Payload, Response};
use zbus::{proxy, Connection};

// org.bluez.Adapter1 proxy
#[proxy(
    interface = "org.bluez.Adapter1",
    default_service = "org.bluez",
    gen_blocking = false
)]
trait Adapter1 {
    #[zbus(property)]
    fn powered(&self) -> zbus::Result<bool>;
    #[zbus(property)]
    fn set_powered(&self, value: bool) -> zbus::Result<()>;
    async fn start_discovery(&self) -> zbus::Result<()>;
    async fn stop_discovery(&self) -> zbus::Result<()>;
}

// org.bluez.Device1 proxy
#[proxy(
    interface = "org.bluez.Device1",
    default_service = "org.bluez",
    gen_blocking = false
)]
trait Device1 {
    async fn connect(&self) -> zbus::Result<()>;
    async fn disconnect(&self) -> zbus::Result<()>;
    #[zbus(property)]
    fn address(&self) -> zbus::Result<String>;
    #[zbus(property)]
    fn name(&self) -> zbus::Result<String>;
    #[zbus(property)]
    fn connected(&self) -> zbus::Result<bool>;
    #[zbus(property)]
    fn paired(&self) -> zbus::Result<bool>;
}

async fn get_adapter(conn: &Connection) -> zbus::Result<Adapter1Proxy<'static>> {
    // Typical path is /org/bluez/hci0
    Adapter1Proxy::builder(conn)
        .path("/org/bluez/hci0")?
        .build()
        .await
}

async fn list_bt_devices(conn: &Connection) -> anyhow::Result<Vec<BtDevice>> {
    use zbus::fdo::ObjectManagerProxy;

    let mgr = ObjectManagerProxy::builder(conn)
        .destination("org.bluez")?
        .path("/")?
        .build()
        .await?;

    let objects = mgr.get_managed_objects().await?;
    let mut devices = Vec::new();

    for (path, interfaces) in objects {
        if interfaces.contains_key("org.bluez.Device1") {
            let dev = Device1Proxy::builder(conn)
                .destination("org.bluez")?
                .path(path)?
                .build()
                .await?;

            devices.push(BtDevice {
                address: dev.address().await.unwrap_or_default(),
                name: dev.name().await.unwrap_or_else(|_| "Unknown".into()),
                connected: dev.connected().await.unwrap_or(false),
                paired: dev.paired().await.unwrap_or(false),
            });
        }
    }

    Ok(devices)
}

pub async fn handle(cmd: BluetoothCmd, conn: &Connection) -> Response {
    match cmd {
        BluetoothCmd::Status => {
            let adapter = match get_adapter(conn).await {
                Ok(a) => a,
                Err(e) => return Response::err(format!("BlueZ unavailable: {e}")),
            };
            let enabled = adapter.powered().await.unwrap_or(false);
            let devices = list_bt_devices(conn).await.unwrap_or_default();
            Response::ok(Payload::Bluetooth { enabled, devices })
        }

        BluetoothCmd::Toggle => {
            let adapter = match get_adapter(conn).await {
                Ok(a) => a,
                Err(e) => return Response::err(e.to_string()),
            };
            let current = adapter.powered().await.unwrap_or(false);
            match adapter.set_powered(!current).await {
                Ok(_) => Response::ok(Payload::Bluetooth { enabled: !current, devices: vec![] }),
                Err(e) => Response::err(e.to_string()),
            }
        }

        BluetoothCmd::Enable => {
            let adapter = match get_adapter(conn).await {
                Ok(a) => a,
                Err(e) => return Response::err(e.to_string()),
            };
            match adapter.set_powered(true).await {
                Ok(_) => Response::ok(Payload::Unit),
                Err(e) => Response::err(e.to_string()),
            }
        }

        BluetoothCmd::Disable => {
            let adapter = match get_adapter(conn).await {
                Ok(a) => a,
                Err(e) => return Response::err(e.to_string()),
            };
            match adapter.set_powered(false).await {
                Ok(_) => Response::ok(Payload::Unit),
                Err(e) => Response::err(e.to_string()),
            }
        }

        BluetoothCmd::Scan => {
            let adapter = match get_adapter(conn).await {
                Ok(a) => a,
                Err(e) => return Response::err(e.to_string()),
            };
            if let Err(e) = adapter.start_discovery().await {
                return Response::err(e.to_string());
            }
            tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
            let _ = adapter.stop_discovery().await;
            let devices = list_bt_devices(conn).await.unwrap_or_default();
            Response::ok(Payload::Bluetooth { enabled: true, devices })
        }

        BluetoothCmd::ListDevices => {
            let devices = list_bt_devices(conn).await.unwrap_or_default();
            let enabled = get_adapter(conn)
                .await
                .ok()
                .and_then(|a| futures_lite::future::block_on(a.powered()).ok())
                .unwrap_or(false);
            Response::ok(Payload::Bluetooth { enabled, devices })
        }

        BluetoothCmd::Connect { address } => {
            let objects = match get_device_path(conn, &address).await {
                Ok(p) => p,
                Err(e) => return Response::err(e.to_string()),
            };
            let dev = match Device1Proxy::builder(conn)
                .destination("org.bluez")
                .unwrap()
                .path(objects)
                .unwrap()
                .build()
                .await
            {
                Ok(d) => d,
                Err(e) => return Response::err(e.to_string()),
            };
            match dev.connect().await {
                Ok(_) => Response::ok(Payload::Unit),
                Err(e) => Response::err(e.to_string()),
            }
        }

        BluetoothCmd::Disconnect { address } => {
            let path = match get_device_path(conn, &address).await {
                Ok(p) => p,
                Err(e) => return Response::err(e.to_string()),
            };
            let dev = match Device1Proxy::builder(conn)
                .destination("org.bluez")
                .unwrap()
                .path(path)
                .unwrap()
                .build()
                .await
            {
                Ok(d) => d,
                Err(e) => return Response::err(e.to_string()),
            };
            match dev.disconnect().await {
                Ok(_) => Response::ok(Payload::Unit),
                Err(e) => Response::err(e.to_string()),
            }
        }
    }
}

/// Find the D-Bus object path for a device by MAC address
async fn get_device_path(conn: &Connection, address: &str) -> anyhow::Result<zbus::zvariant::OwnedObjectPath> {
    use zbus::fdo::ObjectManagerProxy;

    let mgr = ObjectManagerProxy::builder(conn)
        .destination("org.bluez")?
        .path("/")?
        .build()
        .await?;

    let objects = mgr.get_managed_objects().await?;

    for (path, interfaces) in objects {
        if interfaces.contains_key("org.bluez.Device1") {
            let dev = Device1Proxy::builder(conn)
                .destination("org.bluez")?
                .path(&path)?
                .build()
                .await?;
            if dev.address().await.unwrap_or_default().to_lowercase() == address.to_lowercase() {
                return Ok(path);
            }
        }
    }

    anyhow::bail!("device {address} not found")
}
