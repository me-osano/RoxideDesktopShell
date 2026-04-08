use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct BluetoothState {
    pub enabled: bool,
    pub discovering: bool,
    pub devices: Vec<BluetoothDevice>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BluetoothDevice {
    pub address: String,
    pub name: String,
    pub paired: bool,
    pub connected: bool,
    pub trusted: bool,
    pub rssi: i32,
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct BluetoothSnapshot {
    pub state: BluetoothState,
}

pub struct BluetoothManager {
    pub state: Arc<RwLock<BluetoothSnapshot>>,
}

impl Clone for BluetoothManager {
    fn clone(&self) -> Self {
        Self {
            state: self.state.clone(),
        }
    }
}

impl BluetoothManager {
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(BluetoothSnapshot {
                state: BluetoothState {
                    enabled: false,
                    discovering: false,
                    devices: Vec::new(),
                },
            })),
        }
    }

    pub async fn refresh_state(&self) -> Result<(), String> {
        self.refresh_power_state().await?;
        self.refresh_devices().await
    }

    async fn refresh_power_state(&self) -> Result<(), String> {
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["show"])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("bluetoothctl show failed".to_string());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut enabled = false;
        let mut discovering = false;

        for line in stdout.lines() {
            let line = line.trim();
            if line.starts_with("Powered: ") {
                enabled = line == "Powered: yes";
            } else if line.starts_with("Discovering: ") {
                discovering = line == "Discovering: yes";
            }
        }

        let mut state = self.state.write().await;
        state.state.enabled = enabled;
        state.state.discovering = discovering;
        
        Ok(())
    }

    async fn refresh_devices(&self) -> Result<(), String> {
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["devices", "paired"])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut devices = Vec::new();

        for line in stdout.lines() {
            let line = line.trim();
            if line.starts_with("Device ") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    let address = parts[1].to_string();
                    let name = parts[2..].join(" ");
                    
                    let device_info = self.get_device_info(&address).await;
                    devices.push(device_info);
                }
            }
        }

        let mut state = self.state.write().await;
        state.state.devices = devices;
        
        Ok(())
    }

    async fn get_device_info(&self, address: &str) -> BluetoothDevice {
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["info", address])
            .output()
            .await;

        match output {
            Ok(output) if output.status.success() => {
                let stdout = String::from_utf8_lossy(&output.stdout);
                let mut name = String::new();
                let mut paired = false;
                let mut connected = false;
                let mut trusted = false;
                let mut rssi = 0;

                for line in stdout.lines() {
                    let line = line.trim();
                    if line.starts_with("Name: ") {
                        name = line[6..].to_string();
                    } else if line.starts_with("Paired: ") {
                        paired = line == "Paired: yes";
                    } else if line.starts_with("Connected: ") {
                        connected = line == "Connected: yes";
                    } else if line.starts_with("Trusted: ") {
                        trusted = line == "Trusted: yes";
                    } else if line.starts_with("RSSI: ") {
                        if let Ok(val) = line[7..].trim().parse::<i32>() {
                            rssi = val;
                        }
                    }
                }

                BluetoothDevice {
                    address: address.to_string(),
                    name,
                    paired,
                    connected,
                    trusted,
                    rssi,
                }
            }
            _ => BluetoothDevice {
                address: address.to_string(),
                name: String::new(),
                paired: false,
                connected: false,
                trusted: false,
                rssi: 0,
            },
        }
    }

    pub async fn set_enabled(&self, enabled: bool) -> Result<(), String> {
        debug!("bluetooth: setting enabled: {}", enabled);
        
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["power", if enabled { "on" } else { "off" }])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("bluetoothctl power failed: {}", stderr));
        }

        let mut state = self.state.write().await;
        state.state.enabled = enabled;
        Ok(())
    }

    pub async fn start_discovery(&self) -> Result<(), String> {
        debug!("bluetooth: starting discovery");
        
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["scan", "on"])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("bluetoothctl scan on failed: {}", stderr));
        }

        let mut state = self.state.write().await;
        state.state.discovering = true;
        Ok(())
    }

    pub async fn stop_discovery(&self) -> Result<(), String> {
        debug!("bluetooth: stopping discovery");
        
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["scan", "off"])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("bluetoothctl scan off failed: {}", stderr));
        }

        let mut state = self.state.write().await;
        state.state.discovering = false;
        Ok(())
    }

    pub async fn connect_device(&self, address: &str) -> Result<(), String> {
        debug!("bluetooth: connecting to {}", address);
        
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["connect", address])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("bluetoothctl connect failed: {}", stderr));
        }

        Ok(())
    }

    pub async fn disconnect_device(&self, address: &str) -> Result<(), String> {
        debug!("bluetooth: disconnecting {}", address);
        
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["disconnect", address])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("bluetoothctl disconnect failed: {}", stderr));
        }

        Ok(())
    }

    pub async fn pair_device(&self, address: &str) -> Result<(), String> {
        debug!("bluetooth: pairing with {}", address);
        
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["pair", address])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("bluetoothctl pair failed: {}", stderr));
        }

        Ok(())
    }

    pub async fn trust_device(&self, address: &str) -> Result<(), String> {
        debug!("bluetooth: trusting {}", address);
        
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["trust", address])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("bluetoothctl trust failed: {}", stderr));
        }

        Ok(())
    }

    pub async fn remove_device(&self, address: &str) -> Result<(), String> {
        debug!("bluetooth: removing {}", address);
        
        let output = tokio::process::Command::new("bluetoothctl")
            .args(["remove", address])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("bluetoothctl remove failed: {}", stderr));
        }

        Ok(())
    }

    pub async fn get_state(&self) -> BluetoothSnapshot {
        self.state.read().await.clone()
    }
}

impl Default for BluetoothManager {
    fn default() -> Self {
        Self::new()
    }
}

pub async fn worker(state: crate::ipc::AppState) {
    let bluetooth = state.inner.bluetooth.clone();
    
    info!("bluetooth: starting worker");
    
    if let Err(e) = bluetooth.refresh_state().await {
        tracing::warn!("bluetooth: initial refresh failed: {}", e);
    }

    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(10)).await;
        
        if let Err(e) = bluetooth.refresh_state().await {
            tracing::debug!("bluetooth: refresh failed: {}", e);
        } else {
            state.emit(crate::ipc::Event::BluetoothUpdated);
        }
    }
}
