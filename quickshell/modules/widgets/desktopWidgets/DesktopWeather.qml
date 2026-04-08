import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services
import qs.Widgets

DraggableDesktopWidget {
  id: root

  readonly property bool weatherReady: WeatherService.weatherReady
  readonly property int currentWeatherCode: WeatherService.currentWeatherCode
  readonly property real currentTemp: {
    if (!weatherReady)
      return 0;
    var temp = WeatherService.temperature;
    if (Settings.data.location.useFahrenheit) {
      temp = WeatherService.celsiusToFahrenheit(temp);
    }
    return Math.round(temp);
  }
  readonly property real todayMax: {
    if (!weatherReady || !WeatherService.weather?.daily || WeatherService.weather.daily.temperature_2m_max.length === 0)
      return 0;
    var temp = WeatherService.weather.daily.temperature_2m_max[0];
    if (Settings.data.location.useFahrenheit) {
      temp = WeatherService.celsiusToFahrenheit(temp);
    }
    return Math.round(temp);
  }
  readonly property real todayMin: {
    if (!weatherReady || !WeatherService.weather?.daily || WeatherService.weather.daily.temperature_2m_min.length === 0)
      return 0;
    var temp = WeatherService.weather.daily.temperature_2m_min[0];
    if (Settings.data.location.useFahrenheit) {
      temp = WeatherService.celsiusToFahrenheit(temp);
    }
    return Math.round(temp);
  }
  readonly property string tempUnit: Settings.data.location.useFahrenheit ? "F" : "C"
  readonly property string locationName: {
    const chunks = Settings.data.location.name.split(",");
    return chunks[0];
  }

  implicitWidth: Math.round(Math.max(240 * widgetScale, contentLayout.implicitWidth + Style.margin2M * widgetScale))
  implicitHeight: Math.round(64 * widgetScale + Style.margin2M * widgetScale)
  width: implicitWidth
  height: implicitHeight

  RowLayout {
    id: contentLayout
    anchors.fill: parent
    anchors.margins: Math.round(Style.marginM * widgetScale)
    spacing: Math.round(Style.marginM * widgetScale)
    z: 2

    Item {
      Layout.preferredWidth: Math.round(64 * widgetScale)
      Layout.preferredHeight: Math.round(64 * widgetScale)
      Layout.alignment: Qt.AlignVCenter

      RIcon {
        anchors.centerIn: parent
        icon: weatherReady ? WeatherService.weatherSymbolFromCode(currentWeatherCode, WeatherService.isDayTime) : "weather-cloud-off"
        pointSize: Math.round(Style.fontSizeXXXL * 2 * widgetScale)
        color: weatherReady ? Color.mPrimary : Color.mOnSurfaceVariant
      }
    }

    RText {
      text: weatherReady ? `${currentTemp}°${tempUnit}` : "---"
      pointSize: Math.round(Style.fontSizeXXXL * widgetScale)
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginXXS * widgetScale)
      Layout.alignment: Qt.AlignVCenter

      RText {
        Layout.fillWidth: true
        text: locationName || "No location"
        pointSize: Math.round(Style.fontSizeS * widgetScale)
        font.weight: Style.fontWeightRegular
        color: Color.mOnSurfaceVariant
        elide: Text.ElideRight
        maximumLineCount: 1
        visible: !Settings.data.location.hideWeatherCityName
      }

      RowLayout {
        spacing: Math.round(Style.marginXS * widgetScale)
        visible: weatherReady && todayMax > 0 && todayMin > 0

        RText {
          text: "H:"
          pointSize: Math.round(Style.fontSizeXS * widgetScale)
          color: Color.mOnSurfaceVariant
        }
        RText {
          text: `${todayMax}°`
          pointSize: Math.round(Style.fontSizeXS * widgetScale)
          color: Color.mOnSurface
        }

        RText {
          text: "•"
          pointSize: Math.round(Style.fontSizeXXS * widgetScale)
          color: Color.mOnSurfaceVariant
          opacity: 0.5
        }

        RText {
          text: "L:"
          pointSize: Math.round(Style.fontSizeXS * widgetScale)
          color: Color.mOnSurfaceVariant
        }
        RText {
          text: `${todayMin}°`
          pointSize: Math.round(Style.fontSizeXS * widgetScale)
          color: Color.mOnSurfaceVariant
        }
      }
    }
  }
}
