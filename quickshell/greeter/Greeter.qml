// RUSTIQ Greeter — pure QML greetd greeter
// Configure greetd to run: quickshell -p /path/to/rustiq/quickshell/greeter
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../common/theme"

ShellRoot {
    Variants {
        model: Quickshell.screens

        GreeterScreen {
            screen: modelData
        }
    }
}

component GreeterScreen: Rectangle {
    property var screen
    width: screen.width
    height: screen.height
    color: Theme.crust

    // Background — can set to wallpaper image
    // Image { anchors.fill: parent; source: "file:///path/to/wallpaper.jpg"; fillMode: Image.PreserveAspectCrop }

    // Clock
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.25
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), "HH:mm")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 72
            font.bold: true

            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: parent.text = Qt.formatTime(new Date(), "HH:mm")
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: 18
        }
    }

    // Login card
    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 40
        width: 360
        height: loginCol.height + Theme.spacingLarge * 3
        radius: Theme.radiusLarge
        color: Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0.85)
        border.color: Theme.surface1
        border.width: 1

        Column {
            id: loginCol
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: Theme.spacingLarge * 2
            }
            spacing: Theme.spacingLarge

            // User avatar placeholder
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64; height: 64
                radius: 32
                color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "󰀄"
                    color: Theme.base
                    font.family: Theme.fontFamily
                    font.pixelSize: 32
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.environment ? (Qt.environment["USER"] || "user") : "user"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            // Password field
            Rectangle {
                width: parent.width
                height: 44
                radius: Theme.radius
                color: Theme.surface1
                border.color: pwInput.activeFocus ? Theme.accent : "transparent"
                border.width: 2

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.padding
                    spacing: 8

                    Text {
                        text: "󰍁"
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: pwInput
                        width: parent.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        echoMode: TextInput.Password
                        placeholderText: "Password"
                        placeholderTextColor: Theme.overlay0

                        Keys.onReturnPressed: {
                            // TODO: wire greetd IPC for actual auth
                            console.log("greetd auth:", text)
                        }
                    }
                }
            }

            // Login button
            Rectangle {
                width: parent.width
                height: 40
                radius: Theme.radius
                color: loginMa.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "Login"
                    color: Theme.base
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                MouseArea {
                    id: loginMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        // TODO: greetd auth IPC
                    }
                }
            }
        }
    }
}
