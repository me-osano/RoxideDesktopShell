use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MediaPlayer {
    pub name: String,
    pub identity: String,
    pub status: PlaybackStatus,
    pub position_ms: u64,
    pub metadata: MediaMetadata,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MediaMetadata {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub art_url: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum PlaybackStatus {
    Playing,
    Paused,
    Stopped,
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct MediaSnapshot {
    pub players: Vec<MediaPlayer>,
    pub active_player: Option<String>,
}

pub struct MediaManager {
    pub state: RwLock<MediaSnapshot>,
}

impl MediaManager {
    pub fn new() -> Self {
        Self {
            state: RwLock::new(MediaSnapshot {
                players: Vec::new(),
                active_player: None,
            }),
        }
    }

    pub async fn list_players(&self) -> Result<Vec<MediaPlayer>, String> {
        let state = self.state.read().await;
        Ok(state.players.clone())
    }

    pub async fn get_player(&self, name: &str) -> Option<MediaPlayer> {
        let state = self.state.read().await;
        state.players.iter().find(|p| &p.name == name).cloned()
    }

    pub async fn play(&self, player: &str) -> Result<(), String> {
        tracing::debug!("media: play {}", player);
        Ok(())
    }

    pub async fn pause(&self, player: &str) -> Result<(), String> {
        tracing::debug!("media: pause {}", player);
        Ok(())
    }

    pub async fn play_pause(&self, player: &str) -> Result<(), String> {
        tracing::debug!("media: play_pause {}", player);
        Ok(())
    }

    pub async fn stop(&self, player: &str) -> Result<(), String> {
        tracing::debug!("media: stop {}", player);
        Ok(())
    }

    pub async fn next(&self, player: &str) -> Result<(), String> {
        tracing::debug!("media: next {}", player);
        Ok(())
    }

    pub async fn previous(&self, player: &str) -> Result<(), String> {
        tracing::debug!("media: previous {}", player);
        Ok(())
    }

    pub async fn seek(&self, player: &str, position_ms: i64) -> Result<(), String> {
        tracing::debug!("media: seek {} to {}ms", player, position_ms);
        Ok(())
    }

    pub async fn set_active(&self, player: &str) -> Result<(), String> {
        let mut state = self.state.write().await;
        state.active_player = Some(player.to_string());
        Ok(())
    }

    pub async fn get_state(&self) -> MediaSnapshot {
        self.state.read().await.clone()
    }
}

impl Default for MediaManager {
    fn default() -> Self {
        Self::new()
    }
}
