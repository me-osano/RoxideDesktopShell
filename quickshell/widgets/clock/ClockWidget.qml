import QtQuick
import "../../common/theme"

Item {
    id: root
    width: timeText.width + dateText.width + 12
    height: Theme.barHeight

    property var now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Text {
            id: timeText
            text: root.now.toLocaleTimeString(Qt.locale(), "HH:mm")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        Text {
            id: dateText
            text: root.now.toLocaleDateString(Qt.locale(), "ddd dd MMM")
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
