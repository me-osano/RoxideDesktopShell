// WeatherService - Uses Rust daemon for weather data via RoxideClientService
// Falls back to LocationService if Rust is unavailable

pragma Singleton

import QtQuick
import Quickshell
import qs.common.theme
import qs.services

Singleton {
    id: root

    // Weather data from Rust
    property var rustWeather: null

    // Whether Rust weather is available
    readonly property bool rustAvailable: rustWeather !== null

    // Aliases for compatibility with widgets expecting LocationService.weather format
    // These convert Rust format to LocationService-compatible format
    readonly property var weather: {
        if (rustAvailable && rustWeather) {
            return convertRustToLegacy(rustWeather)
        }
        return LocationService.data.weather
    }

    readonly property bool weatherReady: weather !== null

    readonly property int currentWeatherCode: weatherReady ? (weather.current_weather?.weathercode || weather.current?.weather_code || 0) : 0
    readonly property bool isDayTime: weatherReady ? (weather.current_weather?.is_day !== false) : true

    readonly property real temperature: weatherReady ? (weather.current_weather?.temperature || weather.current?.temperature_c || 0) : 0
    readonly property real feelsLike: weatherReady ? (weather.current?.feels_like_c || 0) : 0
    readonly property int humidity: weatherReady ? (weather.current?.humidity_percent || weather.current_weather?.humidity || 0) : 0
    readonly property real windSpeed: weatherReady ? (weather.current?.wind_speed_kmh || weather.current_weather?.windspeed || 0) : 0

    // Coordinate properties (for NightLightService compatibility)
    property string latitude: rustWeather?.location?.latitude?.toString() || LocationService.stableLatitude
    property string longitude: rustWeather?.location?.longitude?.toString() || LocationService.stableLongitude
    readonly property bool coordinatesReady: latitude !== "" && longitude !== ""

    property bool _subscribed: false

    function init() {
        Logger.i("WeatherService", "Service starting")
        refreshFromRust()
        subscribeToRust()
    }

    function refreshFromRust() {
        RoxideClientService.weather(function(data, err) {
            if (err) {
                Logger.w("WeatherService", "Rust weather fetch failed:", err)
                return
            }
            rustWeather = data
            Logger.d("WeatherService", "Weather updated from Rust:", data?.current?.temperature_c + "°C")
        })
    }

    function subscribeToRust() {
        if (_subscribed) return
        _subscribed = true

        RoxideClientService.subscribe(function(event) {
            if (event.type === "weather_updated") {
                refreshFromRust()
            }
        }, ["weather_updated"])
    }

    // Convert Rust WeatherSnapshot to LocationService-compatible format
    function convertRustToLegacy(rustData) {
        if (!rustData) return null

        // Extract current weather code
        var weatherCode = rustData.current?.weather_code || 0
        var isDay = rustData.current?.is_day !== false

        return {
            "latitude": rustData.location?.latitude,
            "longitude": rustData.location?.longitude,
            "timezone": rustData.location?.timezone || "auto",
            "current_weather": {
                "temperature": rustData.current?.temperature_c,
                "weathercode": weatherCode,
                "is_day": isDay,
                "windspeed": rustData.current?.wind_speed_kmh
            },
            "current": rustData.current,
            "hourly": rustData.hourly,
            "daily": rustData.daily,
            "timezone_abbreviation": rustData.location?.timezone_abbreviation || ""
        }
    }

    // Icon mapping (compatible with LocationService)
    function weatherSymbolFromCode(code, isDay) {
        if (code === 0) return isDay ? "weather-sun" : "weather-moon"
        if (code === 1 || code === 2) return isDay ? "weather-cloud-sun" : "weather-moon-stars"
        if (code === 3) return "weather-cloud"
        if (code >= 45 && code <= 48) return "weather-cloud-haze"
        if (code >= 51 && code <= 67) return "weather-cloud-rain"
        if (code >= 80 && code <= 82) return "weather-cloud-rain"
        if (code >= 71 && code <= 77) return "weather-cloud-snow"
        if (code >= 85 && code <= 86) return "weather-cloud-snow"
        if (code >= 95 && code <= 99) return "weather-cloud-lightning"
        return "weather-cloud"
    }

    function weatherDescriptionFromCode(code) {
        if (code === 0) return "Clear sky"
        if (code === 1) return "Mainly clear"
        if (code === 2) return "Partly cloudy"
        if (code === 3) return "Overcast"
        if (code === 45 || code === 48) return "Fog"
        if (code >= 51 && code <= 67) return "Drizzle"
        if (code >= 71 && code <= 77) return "Snow"
        if (code >= 80 && code <= 82) return "Rain showers"
        if (code >= 95 && code <= 99) return "Thunderstorm"
        return "Unknown"
    }

    function celsiusToFahrenheit(celsius) {
        return 32 + celsius * 1.8
    }
}
