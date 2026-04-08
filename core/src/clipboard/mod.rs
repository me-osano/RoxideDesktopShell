use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::debug;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ClipboardItem {
    pub id: String,
    pub preview: String,
    pub content: Option<String>,
    pub mime: String,
    pub is_image: bool,
    pub timestamp: i64,
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct ClipboardSnapshot {
    pub available: bool,
    pub items: Vec<ClipboardItem>,
}

pub struct ClipboardManager {
    pub state: Arc<RwLock<ClipboardSnapshot>>,
    pub content_cache: Arc<RwLock<HashMap<String, String>>>,
}

impl Clone for ClipboardManager {
    fn clone(&self) -> Self {
        Self {
            state: self.state.clone(),
            content_cache: self.content_cache.clone(),
        }
    }
}

impl ClipboardManager {
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(ClipboardSnapshot {
                available: false,
                items: Vec::new(),
            })),
            content_cache: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn check_availability(&self) -> bool {
        let output = tokio::process::Command::new("sh")
            .args(["-c", "command -v cliphist"])
            .output()
            .await;

        let available = output.map(|o| o.status.success()).unwrap_or(false);
        
        let mut state = self.state.write().await;
        state.available = available;
        
        debug!("clipboard: cliphist available: {}", available);
        available
    }

    pub async fn list(&self, max_preview_width: usize) -> Result<Vec<ClipboardItem>, String> {
        let state = self.state.read().await;
        if !state.available {
            return Err("cliphist not available".to_string());
        }
        drop(state);

        let output = tokio::process::Command::new("cliphist")
            .args(["list", "-preview-width", &max_preview_width.to_string()])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("cliphist list failed".to_string());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let items: Vec<ClipboardItem> = stdout
            .lines()
            .filter_map(|line| self.parse_cliphist_line(line))
            .collect();

        let mut state = self.state.write().await;
        state.items = items.clone();

        Ok(items)
    }

    fn parse_cliphist_line(&self, line: &str) -> Option<ClipboardItem> {
        let parts: Vec<&str> = line.splitn(2, |c| c == ' ' || c == '\t').collect();
        if parts.is_empty() {
            return None;
        }

        let id = parts.first()?.to_string();
        let preview = parts.get(1).unwrap_or(&"").to_string();
        let lower = preview.to_lowercase();
        let is_image = lower.starts_with("[image]") || lower.contains("binary data");

        let mime = if is_image {
            if lower.contains("png") { "image/png" }
            else if lower.contains("jpg") || lower.contains("jpeg") { "image/jpeg" }
            else if lower.contains("webp") { "image/webp" }
            else if lower.contains("gif") { "image/gif" }
            else { "image/*" }
        } else {
            "text/plain"
        };

        Some(ClipboardItem {
            id,
            preview,
            content: None,
            mime: mime.to_string(),
            is_image,
            timestamp: chrono::Utc::now().timestamp(),
        })
    }

    pub async fn decode(&self, id: &str) -> Result<String, String> {
        let output = tokio::process::Command::new("cliphist")
            .arg("decode")
            .arg(id)
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("cliphist decode failed".to_string());
        }

        let content = String::from_utf8_lossy(&output.stdout).to_string();
        
        let mut cache = self.content_cache.write().await;
        cache.insert(id.to_string(), content.clone());
        
        Ok(content)
    }

    pub async fn copy(&self, id: &str) -> Result<(), String> {
        let output = tokio::process::Command::new("sh")
            .args(["-c", &format!("cliphist decode {} | wl-copy", id)])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("cliphist copy failed".to_string());
        }

        Ok(())
    }

    pub async fn delete(&self, id: &str) -> Result<(), String> {
        let output = tokio::process::Command::new("sh")
            .args(["-c", &format!("echo {} | cliphist delete", id)])
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("cliphist delete failed".to_string());
        }

        let mut cache = self.content_cache.write().await;
        cache.remove(id);

        Ok(())
    }

    pub async fn wipe(&self) -> Result<(), String> {
        let output = tokio::process::Command::new("cliphist")
            .arg("wipe")
            .output()
            .await
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            return Err("cliphist wipe failed".to_string());
        }

        let mut cache = self.content_cache.write().await;
        cache.clear();

        let mut state = self.state.write().await;
        state.items.clear();

        Ok(())
    }

    pub async fn worker(state: crate::ipc::AppState) {
        let clipboard = state.inner.clipboard.clone();
        
        if clipboard.check_availability().await {
            tracing::info!("clipboard: cliphist available, starting worker");
            if let Err(e) = clipboard.list(100).await {
                tracing::warn!("clipboard: initial list failed: {}", e);
            }
        } else {
            tracing::warn!("clipboard: cliphist not available");
        }

        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
            if let Err(e) = clipboard.list(100).await {
                tracing::debug!("clipboard: list failed: {}", e);
            }
        }
    }

    pub async fn get_state(&self) -> ClipboardSnapshot {
        self.state.read().await.clone()
    }
}

impl Default for ClipboardManager {
    fn default() -> Self {
        Self::new()
    }
}
