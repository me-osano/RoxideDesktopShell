use async_trait::async_trait;
use reqwest::Client;
use std::time::Duration;

use super::{GeoError, GeoLocation, GeoProvider};

pub struct IpApiProvider {
    client: Client,
    endpoint: String,
}

impl IpApiProvider {
    pub fn new() -> Self {
        Self {
            client: Client::builder()
                .timeout(Duration::from_secs(5))
                .build()
                .expect("Failed to create HTTP client"),
            endpoint: "http://ip-api.com/json/?fields=city,country,lat,lon".into(),
        }
    }
}

impl Default for IpApiProvider {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(serde::Deserialize)]
struct IpApiResponse {
    city: String,
    country: String,
    lat: f64,
    lon: f64,
}

#[async_trait]
impl GeoProvider for IpApiProvider {
    async fn locate(&self) -> Result<GeoLocation, GeoError> {
        let resp = self
            .client
            .get(&self.endpoint)
            .send()
            .await
            .map_err(|e| GeoError::Unavailable(e.to_string()))?;

        if resp.status() == 429 {
            return Err(GeoError::RateLimited);
        }

        let data: IpApiResponse = resp
            .json()
            .await
            .map_err(|e| GeoError::Unavailable(e.to_string()))?;

        Ok(GeoLocation {
            city: data.city,
            country: data.country,
            latitude: data.lat,
            longitude: data.lon,
        })
    }
}
