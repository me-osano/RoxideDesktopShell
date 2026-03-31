<file_path>
Projects/rustiqshell/core/src/dbus/mod.rs
</file_path>

<edit_description>
Add initial DBus integration module
</edit_description>

use zbus::{Connection, Result};
use zbus::dbus_proxy;

/// Proxy for interacting with NetworkManager over DBus
#[dbus_proxy(interface = "org.freedesktop.NetworkManager")]
trait NetworkManager {
    /// Get the version of NetworkManager
    fn version(&self) -> Result<String>;

    /// Enable or disable networking
    fn enable(&self, enable: bool) -> Result<()>;
}

/// Proxy for interacting with BlueZ (Bluetooth) over DBus
#[dbus_proxy(interface = "org.bluez.Adapter1")]
trait BluetoothAdapter {
    /// Set the power state of the Bluetooth adapter
    fn set_powered(&self, powered: bool) -> Result<()>;

    /// Start device discovery
    fn start_discovery(&self) -> Result<()>;

    /// Stop device discovery
    fn stop_discovery(&self) -> Result<()>;
}

/// DBus integration module
pub struct DBusManager {
    connection: Connection,
}

impl DBusManager {
    /// Create a new DBusManager instance
    pub async fn new() -> Result<Self> {
        let connection = Connection::system().await?;
        Ok(Self { connection })
    }

    /// Get the version of NetworkManager
    pub async fn get_network_manager_version(&self) -> Result<String> {
        let proxy = NetworkManagerProxy::new(&self.connection).await?;
        proxy.version().await
    }

    /// Enable or disable networking
    pub async fn set_networking_enabled(&self, enable: bool) -> Result<()> {
        let proxy = NetworkManagerProxy::new(&self.connection).await?;
        proxy.enable(enable).await
    }

    /// Set the power state of the Bluetooth adapter
    pub async fn set_bluetooth_powered(&self, powered: bool) -> Result<()> {
        let proxy = BluetoothAdapterProxy::new(&self.connection).await?;
        proxy.set_powered(powered).await
    }

    /// Start Bluetooth device discovery
    pub async fn start_bluetooth_discovery(&self) -> Result<()> {
        let proxy = BluetoothAdapterProxy::new(&self.connection).await?;
        proxy.start_discovery().await
    }

    /// Stop Bluetooth device discovery
    pub async fn stop_bluetooth_discovery(&self) -> Result<()> {
        let proxy = BluetoothAdapterProxy::new(&self.connection).await?;
        proxy.stop_discovery().await
    }
}
