// Media controls via MPRIS D-Bus
// Uses Quickshell's built-in MprisPlayer service
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../../common/theme"

Item {
    id: root
    height: Theme.barHeight
    width: visible ? row.width : 0
    visible: MprisController.currentPlayer !== null

    property var player: MprisController.currentPlayer

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        visible: root.player !== null

        // Prev
        MediaButton {
            text: "󰒮"
            onClicked: root.player && root.player.previous()
        }

        // Play/Pause
        MediaButton {
            text: root.player && root.player.playbackStatus === MprisPlaybackStatus.Playing
                  ? "󰏤" : "󰐊"
            color: Theme.accent
            onClicked: root.player && root.player.togglePlaying()
        }

        // Next
        MediaButton {
            text: "󰒭"
            onClicked: root.player && root.player.next()
        }

        // Track title
        Text {
            text: root.player
                  ? (root.player.trackTitle || root.player.identity || "")
                  : ""
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.maximumWidth: 160
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}

component MediaButton: Item {
    property string text
    property color color: Theme.subtext1
    signal clicked

    width: 22; height: 22

    Text {
        anchors.centerIn: parent
        text: parent.text
        color: ma.containsMouse ? Theme.text : parent.color
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: parent.clicked()
    }
}
