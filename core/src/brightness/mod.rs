use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Device {
    pub id: String,
    pub class: DeviceClass,
    pub name: String,
    pub current: i32,
    pub max: i32,
    pub current_percent: i32,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum DeviceClass {
    Backlight,
    Leds,
    Ddc,
}

impl std::fmt::Display for DeviceClass {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DeviceClass::Backlight => write!(f, "backlight"),
            DeviceClass::Leds => write!(f, "leds"),
            DeviceClass::Ddc => write!(f, "ddc"),
        }
    }
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct BrightnessSnapshot {
    pub available: bool,
    pub devices: Vec<Device>,
    pub selected_device: Option<String>,
}

pub struct BrightnessManager {
    pub state: Arc<RwLock<BrightnessSnapshot>>,
}

impl Clone for BrightnessManager {
    fn clone(&self) -> Self {
        Self {
            state: self.state.clone(),
        }
    }
}

impl BrightnessManager {
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(BrightnessSnapshot {
                available: false,
                devices: Vec::new(),
                selected_device: None,
            })),
        }
    }

    pub async fn refresh_devices(&self) {
        let mut devices = Vec::new();

        if let Ok(sysfs) = SysfsBackend::new() {
            if let Ok(d) = sysfs.get_devices() {
                devices.extend(d);
            }
        }

        if let Ok(mut ddc) = DdcBackend::new() {
            if let Ok(d) = ddc.get_devices() {
                devices.extend(d);
            }
            ddc.close();
        }

        let selected = if devices.is_empty() {
            None
        } else {
            Some(devices[0].id.clone())
        };

        let mut state = self.state.write().await;
        state.devices = devices;
        state.selected_device = selected;
        state.available = !state.devices.is_empty();
    }

    pub async fn get_devices(&self) -> Vec<Device> {
        self.state.read().await.devices.clone()
    }

    pub async fn get_device(&self, device_id: &str) -> Option<Device> {
        self.state.read().await.devices.iter().find(|d| d.id == device_id).cloned()
    }

    pub async fn get_selected_device(&self) -> Option<Device> {
        let state = self.state.read().await;
        state.selected_device.as_ref().and_then(|id| state.devices.iter().find(|d| &d.id == id).cloned())
    }

    pub async fn set_selected_device(&self, device_id: &str) -> Result<(), String> {
        let mut state = self.state.write().await;
        if state.devices.iter().any(|d| d.id == device_id) {
            state.selected_device = Some(device_id.to_string());
            Ok(())
        } else {
            Err("Device not found".to_string())
        }
    }

    pub async fn set_brightness(&self, device_id: &str, percent: f32, exponential: bool, exponent: f64) -> Result<(), String> {
        let device = self.get_device(device_id).await.ok_or("Device not found")?;
        
        let value = if exponential {
            Self::percent_to_value(percent as i32, device.max, exponent)
        } else {
            (percent / 100.0 * device.max as f32) as i32
        };

        match device.class {
            DeviceClass::Backlight | DeviceClass::Leds => {
                let backend = SysfsBackend::new().map_err(|e| e.to_string())?;
                backend.set_brightness(&device_id, value).map_err(|e| e.to_string())?;
            }
            DeviceClass::Ddc => {
                let mut backend = DdcBackend::new().map_err(|e| e.to_string())?;
                backend.set_brightness(&device_id, value)?;
                backend.close();
            }
        }

        self.refresh_devices().await;
        Ok(())
    }

    pub async fn set_brightness_selected(&self, percent: f32, exponential: bool, exponent: f64) -> Result<(), String> {
        let state = self.state.read().await;
        let device_id = state.selected_device.clone().ok_or("No device selected")?;
        drop(state);
        self.set_brightness(&device_id, percent, exponential, exponent).await
    }

    pub async fn increase(&self, delta: f32, exponential: bool, exponent: f64) -> Result<(), String> {
        let device = self.get_selected_device().await.ok_or("No device selected")?;
        let new_percent = (device.current_percent as f32 + delta).min(100.0);
        self.set_brightness_selected(new_percent, exponential, exponent).await
    }

    pub async fn decrease(&self, delta: f32, exponential: bool, exponent: f64) -> Result<(), String> {
        let device = self.get_selected_device().await.ok_or("No device selected")?;
        let new_percent = (device.current_percent as f32 - delta).max(0.0);
        self.set_brightness_selected(new_percent, exponential, exponent).await
    }

    pub async fn get_state(&self) -> BrightnessSnapshot {
        self.state.read().await.clone()
    }

    fn percent_to_value(percent: i32, max: i32, exponent: f64) -> i32 {
        let normalized = percent as f64 / 100.0;
        let scaled = normalized.powf(exponent);
        (scaled * max as f64).round() as i32
    }

    pub async fn worker(state: crate::ipc::AppState) {
        let brightness = state.inner.brightness.clone();
        brightness.refresh_devices().await;
        
        if !brightness.state.read().await.devices.is_empty() {
            tracing::info!("brightness: {} devices available", brightness.state.read().await.devices.len());
        } else {
            tracing::warn!("brightness: no devices found");
        }

        std::future::pending::<()>().await;
    }
}

impl Default for BrightnessManager {
    fn default() -> Self {
        Self::new()
    }
}

pub struct SysfsBackend {
    base_path: PathBuf,
}

impl SysfsBackend {
    pub fn new() -> Result<Self, std::io::Error> {
        Ok(Self {
            base_path: PathBuf::from("/sys"),
        })
    }

    pub fn get_devices(&self) -> Result<Vec<Device>, std::io::Error> {
        let mut devices = Vec::new();

        let backlight_path = self.base_path.join("class/backlight");
        if backlight_path.exists() {
            for entry in std::fs::read_dir(&backlight_path)? {
                let entry = entry?;
                let name = entry.file_name().to_string_lossy().to_string();
                let path = entry.path();

                let max_brightness = Self::read_int(&path.join("max_brightness")).unwrap_or(100);
                let brightness = Self::read_int(&path.join("brightness")).unwrap_or(0);
                let current_percent = if max_brightness > 0 {
                    (brightness * 100) / max_brightness
                } else {
                    0
                };

                devices.push(Device {
                    id: format!("backlight:{}", name),
                    class: DeviceClass::Backlight,
                    name: name.clone(),
                    current: brightness,
                    max: max_brightness,
                    current_percent,
                });
            }
        }

        let leds_path = self.base_path.join("class/leds");
        if leds_path.exists() {
            for entry in std::fs::read_dir(&leds_path)? {
                let entry = entry?;
                let name = entry.file_name().to_string_lossy().to_string();
                let path = entry.path();

                if !path.join("brightness").exists() {
                    continue;
                }

                let max_brightness = Self::read_int(&path.join("max_brightness")).unwrap_or(255);
                let brightness = Self::read_int(&path.join("brightness")).unwrap_or(0);
                let current_percent = if max_brightness > 0 {
                    (brightness * 100) / max_brightness
                } else {
                    0
                };

                devices.push(Device {
                    id: format!("leds:{}", name),
                    class: DeviceClass::Leds,
                    name,
                    current: brightness,
                    max: max_brightness,
                    current_percent,
                });
            }
        }

        Ok(devices)
    }

    fn read_int(path: &std::path::Path) -> Option<i32> {
        std::fs::read_to_string(path).ok()?.trim().parse().ok()
    }

    pub fn set_brightness(&self, device_id: &str, value: i32) -> Result<(), std::io::Error> {
        let parts: Vec<&str> = device_id.splitn(2, ':').collect();
        if parts.len() != 2 {
            return Err(std::io::Error::new(std::io::ErrorKind::InvalidInput, "Invalid device ID"));
        }

        let (class, name) = (parts[0], parts[1]);
        let base = match class {
            "backlight" => self.base_path.join("class/backlight"),
            "leds" => self.base_path.join("class/leds"),
            _ => return Err(std::io::Error::new(std::io::ErrorKind::InvalidInput, "Invalid device class")),
        };

        let path = base.join(name).join("brightness");
        std::fs::write(path, value.to_string())?;
        Ok(())
    }
}

pub struct DdcBackend {
    cache: std::collections::HashMap<String, MonitorInfo>,
}

struct MonitorInfo {
    bus: String,
    address: String,
}

impl DdcBackend {
    pub fn new() -> Result<Self, std::io::Error> {
        Ok(Self {
            cache: std::collections::HashMap::new(),
        })
    }

    pub fn get_devices(&mut self) -> Result<Vec<Device>, std::io::Error> {
        let output = std::process::Command::new("ddcutil")
            .args(["detect", "--brief"])
            .output()?;

        if !output.status.success() {
            return Ok(Vec::new());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut devices = Vec::new();

        let mut current_bus = String::new();
        let mut current_addr = String::new();
        let mut current_name = String::new();

        for line in stdout.lines() {
            let line = line.trim();
            if line.starts_with("Bus") && line.contains("=") {
                if let Some(bus) = line.split('=').nth(1) {
                    current_bus = bus.trim().to_string();
                }
            } else if line.starts_with("Address") && line.contains("=") {
                if let Some(addr) = line.split('=').nth(1) {
                    current_addr = addr.trim().to_string();
                }
            } else if line.starts_with("Monitor") && line.contains("=") {
                if let Some(name) = line.split('=').nth(1) {
                    current_name = name.trim().to_string();
                }
            } else if line.is_empty() || line.starts_with("Invalid") || line.starts_with("DDC") {
                if !current_bus.is_empty() && !current_addr.is_empty() && !current_name.is_empty() {
                    let device_id = format!("ddc:{}", current_name.replace(' ', "_"));
                    let brightness = Self::get_brightness_value(&current_bus, &current_addr);
                    let max = 100;

                    self.cache.insert(device_id.clone(), MonitorInfo {
                        bus: current_bus.clone(),
                        address: current_addr.clone(),
                    });

                    devices.push(Device {
                        id: device_id,
                        class: DeviceClass::Ddc,
                        name: current_name.clone(),
                        current: brightness.unwrap_or(0),
                        max,
                        current_percent: brightness.unwrap_or(0),
                    });
                }
                current_bus.clear();
                current_addr.clear();
                current_name.clear();
            }
        }

        if !current_bus.is_empty() && !current_addr.is_empty() && !current_name.is_empty() {
            let device_id = format!("ddc:{}", current_name.replace(' ', "_"));
            let brightness = Self::get_brightness_value(&current_bus, &current_addr);
            let max = 100;

            self.cache.insert(device_id.clone(), MonitorInfo {
                bus: current_bus,
                address: current_addr,
            });

            devices.push(Device {
                id: device_id,
                class: DeviceClass::Ddc,
                name: current_name,
                current: brightness.unwrap_or(0),
                max,
                current_percent: brightness.unwrap_or(0),
            });
        }

        Ok(devices)
    }

    fn get_brightness_value(bus: &str, address: &str) -> Option<i32> {
        let output = std::process::Command::new("ddcutil")
            .args(["get", "brightness", "-b", bus])
            .output()
            .ok()?;

        if !output.status.success() {
            return None;
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        stdout.lines()
            .find(|l| l.contains("value"))
            .and_then(|l| l.split_whitespace().last())
            .and_then(|s| s.parse().ok())
    }

    pub fn set_brightness(&mut self, device_id: &str, value: i32) -> Result<(), String> {
        let info = self.cache.get(device_id).ok_or("Device not in cache")?;
        
        let output = std::process::Command::new("ddcutil")
            .args(["set", "brightness", "-b", &info.bus, &value.to_string()])
            .output()
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("ddcutil set failed".to_string());
        }

        Ok(())
    }

    pub fn close(&mut self) {
        self.cache.clear();
    }
}