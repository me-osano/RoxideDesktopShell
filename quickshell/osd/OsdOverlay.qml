// RUSTIQ OSD — volume & brightness overlays
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import "../common/theme"

Item {
    id: osd

    // Volume OSD — triggered by Pipewire changes
    Variants {
        model: Quickshell.screens

        PopupWindow {
            property var screen: modelData
            id: volOsd

            anchor.rect.x: (screen.width - width) / 2
            anchor.rect.y: screen.height - height - 80
            width: 280
            height: 60
            color: "transparent"
            visible: volTimer.running

            property real volume: {
                var sink = PwObjectTracker.defaultAudioSink
                return sink ? sink.audio.volume : 0
            }
            property bool muted: {
                var sink = PwObjectTracker.defaultAudioSink
                return sink ? sink.audio.muted : false
            }

            onVolumeChanged: volTimer.restart()
            onMutedChanged: volTimer.restart()

            Timer {
                id: volTimer
                interval: 2000
                running: false
            }

            OsdCard {
                icon: volOsd.muted ? "󰝟" : volumeIcon(volOsd.volume)
                value: Math.round(volOsd.volume * 100)
                unit: "%"
                color: volOsd.muted ? Theme.overlay0 : Theme.accent
            }

            function volumeIcon(v) {
                if (v === 0) return "󰕿"
                if (v < 0.5) return "󰖀"
                return "󰕾"
            }
        }
    }
}

component OsdCard: Rectangle {
    property string icon
    property real value
    property string unit: ""
    property color color: Theme.accent

    anchors.fill: parent
    radius: Theme.radiusLarge
    color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.92)
    border.color: Theme.surface1
    border.width: 1

    Row {
        anchors.centerIn: parent
        spacing: 12

        Text {
            text: parent.parent.icon
            color: parent.parent.color
            font.family: Theme.fontFamily
            font.pixelSize: 22
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                text: Math.round(parent.parent.parent.value) + parent.parent.parent.unit
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            Rectangle {
                width: 160
                height: 4
                radius: 2
                color: Theme.surface1

                Rectangle {
                    width: parent.width * Math.min(parent.parent.parent.parent.value / 100, 1)
                    height: parent.height
                    radius: 2
                    color: parent.parent.parent.parent.color
                }
            }
        }
    }
}
