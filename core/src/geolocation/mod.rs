mod ipapi;

pub use ipapi::IpApiProvider;

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::time::{Duration, Instant};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GeoLocation {
    pub city: String,
    pub country: String,
    pub latitude: f64,
    pub longitude: f64,
}

#[derive(Debug, thiserror::Error)]
pub enum GeoError {
    #[error("Geolocation service unavailable: {0}")]
    Unavailable(String),
    #[error("Rate limited")]
    RateLimited,
}

#[async_trait]
pub trait GeoProvider: Send + Sync {
    async fn locate(&self) -> Result<GeoLocation, GeoError>;
}

pub struct GeoManager<P: GeoProvider> {
    provider: P,
    cache: tokio::sync::RwLock<Option<(GeoLocation, Instant)>>,
    cache_ttl: Duration,
}

impl<P: GeoProvider> GeoManager<P> {
    pub fn new(provider: P) -> Self {
        Self {
            provider,
            cache: tokio::sync::RwLock::new(None),
            cache_ttl: Duration::from_secs(3600), // 1 hour default
        }
    }

    pub fn with_ttl(provider: P, ttl: Duration) -> Self {
        Self {
            provider,
            cache: tokio::sync::RwLock::new(None),
            cache_ttl: ttl,
        }
    }

    pub async fn get_location(&self) -> Result<GeoLocation, GeoError> {
        // Check cache first
        if let Some((loc, cached_at)) = self.cache.read().await.as_ref() {
            if cached_at.elapsed() < self.cache_ttl {
                return Ok(loc.clone());
            }
        }

        let location = self.provider.locate().await?;

        // Update cache
        *self.cache.write().await = Some((location.clone(), Instant::now()));
        Ok(location)
    }

    pub async fn clear_cache(&self) {
        *self.cache.write().await = None;
    }

    pub async fn is_cached(&self) -> bool {
        if let Some((_, cached_at)) = self.cache.read().await.as_ref() {
            cached_at.elapsed() < self.cache_ttl
        } else {
            false
        }
    }
}
