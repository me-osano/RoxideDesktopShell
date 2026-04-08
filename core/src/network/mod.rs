use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct NetworkState {
    pub wifi_enabled: bool,
    pub wifi_connected: bool,
    pub wifi_signal: i32,
    pub ethernet_enabled: bool,
    pub ethernet_connected: bool,
    pub active_connections: Vec<ActiveConnection>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ActiveConnection {
    pub id: String,
    pub name: String,
    pub type_: String,
    pub state: String,
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct NetworkSnapshot {
    pub state: NetworkState,
    pub devices: Vec<NetworkDevice>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NetworkDevice {
    pub interface: String,
    pub device_type: String,
    pub enabled: bool,
    pub connected: bool,
    pub signal: i32,
}

pub struct NetworkManager {
    pub state: Arc<RwLock<NetworkSnapshot>>,
}

impl Clone for NetworkManager {
    fn clone(&self) -> Self {
        Self {
            state: self.state.clone(),
        }
    }
}

impl NetworkManager {
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(NetworkSnapshot {
                state: NetworkState {
                    wifi_enabled: false,
                    wifi_connected: false,
                    wifi_signal: 0,
                    ethernet_enabled: false,
                    ethernet_connected: false,
                    active_connections: Vec::new(),
                },
                devices: Vec::new(),
            })),
        }
    }

    pub async fn set_wifi_enabled(&self, enabled: bool) -> Result<(), String> {
        debug!("network: setting wifi enabled: {}", enabled);
        
        let output = tokio::process::Command::new("nmcli")
            .args(["radio", "wifi", if enabled { "on" } else { "off" }])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("nmcli failed: {}", stderr));
        }

        let mut state = self.state.write().await;
        state.state.wifi_enabled = enabled;
        Ok(())
    }

    pub async fn set_ethernet_enabled(&self, enabled: bool) -> Result<(), String> {
        debug!("network: setting ethernet enabled: {}", enabled);
        let mut state = self.state.write().await;
        state.state.ethernet_enabled = enabled;
        Ok(())
    }

    pub async fn refresh_state(&self) -> Result<(), String> {
        self.refresh_devices().await?;
        self.refresh_radio_state().await
    }

    async fn refresh_radio_state(&self) -> Result<(), String> {
        let output = tokio::process::Command::new("nmcli")
            .args(["-t", "-f", "TYPE,STATE", "device"])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("nmcli device list failed".to_string());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut wifi_connected = false;
        let mut ethernet_connected = false;
        let mut active_connections = Vec::new();

        for line in stdout.lines() {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 2 {
                let device_type = parts[0];
                let state = parts[1];
                
                if state == "connected" {
                    active_connections.push(ActiveConnection {
                        id: format!("{}-{}", device_type, 0),
                        name: device_type.to_string(),
                        type_: device_type.to_string(),
                        state: state.to_string(),
                    });

                    if device_type == "wifi" {
                        wifi_connected = true;
                    } else if device_type == "ethernet" {
                        ethernet_connected = true;
                    }
                }
            }
        }

        let mut state = self.state.write().await;
        state.state.wifi_connected = wifi_connected;
        state.state.ethernet_connected = ethernet_connected;
        state.state.active_connections = active_connections;
        
        Ok(())
    }

    async fn refresh_devices(&self) -> Result<(), String> {
        let output = tokio::process::Command::new("nmcli")
            .args(["-t", "-f", "DEVICE,TYPE,STATE", "device"])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("nmcli device list failed".to_string());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut devices = Vec::new();

        for line in stdout.lines() {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 3 {
                devices.push(NetworkDevice {
                    interface: parts[0].to_string(),
                    device_type: parts[1].to_string(),
                    enabled: parts[2] != "unmanaged",
                    connected: parts[2] == "connected",
                    signal: 0,
                });
            }
        }

        let mut state = self.state.write().await;
        state.devices = devices;
        
        Ok(())
    }

    pub async fn get_state(&self) -> NetworkSnapshot {
        self.state.read().await.clone()
    }

    pub async fn scan_wifi(&self) -> Result<Vec<WifiNetwork>, String> {
        let output = tokio::process::Command::new("nmcli")
            .args(["-t", "-f", "SSID,SECURITY,SIGNAL,IN-USE", "device", "wifi", "list", "--rescan", "yes"])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("nmcli wifi scan failed".to_string());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut networks = Vec::new();

        for line in stdout.lines() {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 4 {
                let ssid = parts[0];
                if !ssid.is_empty() {
                    networks.push(WifiNetwork {
                        ssid: ssid.to_string(),
                        security: parts[1].to_string(),
                        signal: parts[2].parse().unwrap_or(0),
                        connected: parts[3] == "*",
                    });
                }
            }
        }

        Ok(networks)
    }

    pub async fn connect_wifi(&self, ssid: &str, password: Option<&str>) -> Result<(), String> {
        let mut cmd = tokio::process::Command::new("nmcli");
        cmd.arg("device").arg("wifi").arg("connect").arg(ssid);
        
        if let Some(pwd) = password {
            cmd.arg("password").arg(pwd);
        }

        let output = cmd.output().await.map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("nmcli connect failed: {}", stderr));
        }

        Ok(())
    }

    pub async fn disconnect_wifi(&self, ssid: &str) -> Result<(), String> {
        let output = tokio::process::Command::new("nmcli")
            .args(["connection", "down", "id", ssid])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("nmcli disconnect failed: {}", stderr));
        }

        Ok(())
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WifiNetwork {
    pub ssid: String,
    pub security: String,
    pub signal: i32,
    pub connected: bool,
}

impl Default for NetworkManager {
    fn default() -> Self {
        Self::new()
    }
}

pub async fn worker(state: crate::ipc::AppState) {
    let network = state.inner.network.clone();
    
    info!("network: starting worker");
    
    if let Err(e) = network.refresh_state().await {
        tracing::warn!("network: initial refresh failed: {}", e);
    }

    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;
        
        if let Err(e) = network.refresh_state().await {
            tracing::debug!("network: refresh failed: {}", e);
        } else {
            state.emit(crate::ipc::Event::NetworkUpdated);
        }
    }
}
