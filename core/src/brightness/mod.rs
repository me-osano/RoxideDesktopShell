use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct BrightnessSnapshot {
    pub available: bool,
    pub brightness: f32,
    pub max_brightness: i32,
    pub monitors: Vec<MonitorBrightness>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MonitorBrightness {
    pub display: String,
    pub brightness: i32,
    pub max_brightness: i32,
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
                brightness: 0.0,
                max_brightness: 100,
                monitors: Vec::new(),
            })),
        }
    }

    pub async fn check_availability(&self) -> bool {
        let output = tokio::process::Command::new("sh")
            .args(["-c", "command -v ddcutil || command -v ddcci-backlight"])
            .output()
            .await;

        let available = output.map(|o| o.status.success()).unwrap_or(false);
        
        let mut state = self.state.write().await;
        state.available = available;
        
        tracing::debug!("brightness: ddcutil available: {}", available);
        available
    }

    pub async fn get_brightness(&self) -> Result<i32, String> {
        let state = self.state.read().await;
        if !state.available {
            return Err("ddcutil not available".to_string());
        }

        let output = tokio::process::Command::new("ddcutil")
            .args(["get", "brightness", "-t"])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("ddcutil get failed".to_string());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let brightness = stdout
            .lines()
            .next()
            .and_then(|l| l.split_whitespace().last())
            .and_then(|s| s.parse::<i32>().ok())
            .unwrap_or(50);

        Ok(brightness)
    }

    pub async fn set_brightness(&self, value: f32) -> Result<(), String> {
        let state = self.state.read().await;
        if !state.available {
            return Err("ddcutil not available".to_string());
        }
        drop(state);

        let clamped = value.max(0.0).min(1.0);
        let brightness = (clamped * 100.0) as i32;

        let output = tokio::process::Command::new("ddcutil")
            .args(["set", "brightness", &brightness.to_string()])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("ddcutil set failed".to_string());
        }

        let mut state = self.state.write().await;
        state.brightness = clamped;

        Ok(())
    }

    pub async fn worker(state: crate::ipc::AppState) {
        let brightness = state.inner.brightness.clone();
        
        if brightness.check_availability().await {
            tracing::info!("brightness: ddcutil available");
        } else {
            tracing::warn!("brightness: ddcutil not available");
        }

        std::future::pending::<()>().await;
    }

    pub async fn increase(&self, delta: f32) -> Result<(), String> {
        let state = self.state.read().await;
        let current = state.brightness;
        drop(state);
        self.set_brightness(current + delta).await
    }

    pub async fn decrease(&self, delta: f32) -> Result<(), String> {
        let state = self.state.read().await;
        let current = state.brightness;
        drop(state);
        self.set_brightness(current - delta).await
    }

    pub async fn get_state(&self) -> BrightnessSnapshot {
        self.state.read().await.clone()
    }
}

impl Default for BrightnessManager {
    fn default() -> Self {
        Self::new()
    }
}
