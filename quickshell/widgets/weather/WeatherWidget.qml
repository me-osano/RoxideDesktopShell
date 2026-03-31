import QtQuick
import QtQuick.Layouts
import "../../common/theme"
import "../../common/components"

Item {
    id: root
    height: Theme.barHeight
    width: row.width + Theme.spacing * 2

    property string description: "—"
    property real tempC: 0
    property string icon: ""
    property bool loaded: false

    RustiqClient { id: client }

    Timer {
        interval: 900000  // 15 min — matches Rust polling
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            client.weather(function(data) {
                if (!data) return
                root.loaded = true
                root.tempC = data.current.temperature_c
                root.description = data.current.description
                root.icon = data.current.icon
            })
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        visible: root.loaded

        Text {
            text: weatherEmoji(root.icon)
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Math.round(root.tempC) + "°C"
            color: tempColor(root.tempC)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Fallback when not loaded
    Text {
        anchors.centerIn: parent
        text: "…"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        visible: !root.loaded
    }

    function weatherEmoji(icon) {
        if (icon.includes("clear")) return "☀️"
        if (icon.includes("few-clouds")) return "⛅"
        if (icon.includes("clouds")) return "☁️"
        if (icon.includes("fog")) return "🌫️"
        if (icon.includes("showers") || icon.includes("rain")) return "🌧️"
        if (icon.includes("snow")) return "❄️"
        if (icon.includes("storm")) return "⛈️"
        return "🌡️"
    }

    function tempColor(c) {
        if (c >= 35) return Theme.red
        if (c >= 28) return Theme.peach
        if (c >= 20) return Theme.yellow
        if (c >= 10) return Theme.teal
        if (c >= 0)  return Theme.sky
        return Theme.blue
    }
}
