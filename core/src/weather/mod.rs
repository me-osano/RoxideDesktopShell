use anyhow::Result;
use serde::{Deserialize, Serialize};
use tokio::time::{Duration, interval};
use tracing::{debug, warn};

use crate::ipc::{AppState, Event};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WeatherSnapshot {
    pub location: Location,
    pub current: CurrentWeather,
    pub hourly: Vec<HourlyForecast>,
    pub fetched_at: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Location {
    pub city: String,
    pub country: String,
    pub latitude: f64,
    pub longitude: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CurrentWeather {
    pub temperature_c: f32,
    pub feels_like_c: f32,
    pub humidity_percent: u8,
    pub wind_speed_kmh: f32,
    pub weather_code: u16,
    pub description: String,
    pub icon: String, // icon name for QML Image
    pub is_day: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HourlyForecast {
    pub hour: String,
    pub temperature_c: f32,
    pub weather_code: u16,
    pub precipitation_mm: f32,
}

#[derive(Deserialize)]
struct IpApiResponse {
    city: String,
    country: String,
    lat: f64,
    lon: f64,
}

/// WMO weather code → (description, icon name)
fn weather_code_info(code: u16, is_day: bool) -> (&'static str, &'static str) {
    match code {
        0 => if is_day { ("Clear sky", "weather-clear") } else { ("Clear sky", "weather-clear-night") },
        1..=3 => if is_day { ("Partly cloudy", "weather-few-clouds") } else { ("Partly cloudy", "weather-few-clouds-night") },
        45 | 48 => ("Foggy", "weather-fog"),
        51..=57 => ("Drizzle", "weather-showers-scattered"),
        61..=67 => ("Rain", "weather-showers"),
        71..=77 => ("Snow", "weather-snow"),
        80..=82 => ("Showers", "weather-showers"),
        85 | 86 => ("Snow showers", "weather-snow"),
        95 => ("Thunderstorm", "weather-storm"),
        96 | 99 => ("Thunderstorm with hail", "weather-storm"),
        _ => ("Unknown", "weather-clear"),
    }
}

async fn fetch_location() -> Result<Location> {
    let client = reqwest::Client::new();
    let resp: IpApiResponse = client
        .get("http://ip-api.com/json/?fields=city,country,lat,lon")
        .timeout(Duration::from_secs(5))
        .send()
        .await?
        .json()
        .await?;

    Ok(Location {
        city: resp.city,
        country: resp.country,
        latitude: resp.lat,
        longitude: resp.lon,
    })
}

async fn fetch_weather(loc: &Location) -> Result<WeatherSnapshot> {
    let url = format!(
        "https://api.open-meteo.com/v1/forecast?\
         latitude={}&longitude={}\
         &current=temperature_2m,apparent_temperature,relative_humidity_2m,\
         wind_speed_10m,weather_code,is_day\
         &hourly=temperature_2m,weather_code,precipitation\
         &forecast_days=1&wind_speed_unit=kmh",
        loc.latitude, loc.longitude
    );

    let client = reqwest::Client::new();
    let data: serde_json::Value = client
        .get(&url)
        .timeout(Duration::from_secs(10))
        .send()
        .await?
        .json()
        .await?;

    let curr = &data["current"];
    let weather_code = curr["weather_code"].as_u64().unwrap_or(0) as u16;
    let is_day = curr["is_day"].as_u64().unwrap_or(1) == 1;
    let (description, icon) = weather_code_info(weather_code, is_day);

    let current = CurrentWeather {
        temperature_c: curr["temperature_2m"].as_f64().unwrap_or(0.0) as f32,
        feels_like_c: curr["apparent_temperature"].as_f64().unwrap_or(0.0) as f32,
        humidity_percent: curr["relative_humidity_2m"].as_u64().unwrap_or(0) as u8,
        wind_speed_kmh: curr["wind_speed_10m"].as_f64().unwrap_or(0.0) as f32,
        weather_code,
        description: description.to_string(),
        icon: icon.to_string(),
        is_day,
    };

    // Hourly — next 6 hours
    let hourly_temps = data["hourly"]["temperature_2m"].as_array().cloned().unwrap_or_default();
    let hourly_codes = data["hourly"]["weather_code"].as_array().cloned().unwrap_or_default();
    let hourly_precip = data["hourly"]["precipitation"].as_array().cloned().unwrap_or_default();
    let hourly_times = data["hourly"]["time"].as_array().cloned().unwrap_or_default();

    let hourly: Vec<HourlyForecast> = (0..6.min(hourly_temps.len()))
        .map(|i| HourlyForecast {
            hour: hourly_times.get(i)
                .and_then(|t| t.as_str())
                .map(|s| s.split('T').nth(1).unwrap_or(s).to_string())
                .unwrap_or_default(),
            temperature_c: hourly_temps.get(i).and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
            weather_code: hourly_codes.get(i).and_then(|v| v.as_u64()).unwrap_or(0) as u16,
            precipitation_mm: hourly_precip.get(i).and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
        })
        .collect();

    Ok(WeatherSnapshot {
        location: loc.clone(),
        current,
        hourly,
        fetched_at: chrono::Utc::now().timestamp(),
    })
}

/// Background worker — fetches weather every 15 minutes
pub async fn worker(state: AppState) {
    let mut ticker = interval(Duration::from_secs(900)); // 15 min

    // Fetch location once
    let location = match fetch_location().await {
        Ok(loc) => {
            debug!("weather: located at {}, {}", loc.city, loc.country);
            loc
        }
        Err(e) => {
            warn!("weather: geolocation failed: {e}");
            return;
        }
    };

    loop {
        ticker.tick().await;

        match fetch_weather(&location).await {
            Ok(snap) => {
                debug!("weather: {}°C {} in {}", snap.current.temperature_c, snap.current.description, snap.location.city);
                *state.inner.weather.write().await = Some(snap);
                state.emit(Event::WeatherUpdated);
            }
            Err(e) => warn!("weather: fetch failed: {e}"),
        }
    }
}
