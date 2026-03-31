// RUSTIQ Notification Center — popup toasts + panel
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../common/theme"
import "../common/components"

// Toast popups — top-right corner
Item {
    id: notificationCenter

    RustiqClient { id: client }

    // Active toasts (auto-expire)
    property var toasts: []

    // Poll for new notifications every second
    // (Replace with SSE event stream when wired)
    property var lastSeen: ({})

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            client.get("/notifications", function(data) {
                if (!data) return
                data.forEach(function(notif) {
                    if (!notificationCenter.lastSeen[notif.id]) {
                        notificationCenter.lastSeen[notif.id] = true
                        notificationCenter.showToast(notif)
                    }
                })
            })
        }
    }

    function showToast(notif) {
        toastRepeater.model.push(notif)
        toastRepeater.model = toastRepeater.model  // trigger update
    }

    // Toast container — top-right
    Variants {
        model: Quickshell.screens

        Item {
            property var screen: modelData

            // Toasts column anchored top-right
            Column {
                x: screen.width - width - 16
                y: Theme.barHeight + 8
                spacing: 6
                z: 999

                Repeater {
                    id: toastRepeater
                    model: []

                    delegate: Toast {
                        notif: modelData
                        onDismissed: {
                            client.dismissNotification(modelData.id)
                        }
                    }
                }
            }
        }
    }
}

component Toast: Rectangle {
    id: toast
    property var notif
    signal dismissed

    width: 360
    height: contentCol.height + Theme.spacingLarge * 2
    radius: Theme.radiusLarge
    color: urgencyColor(notif.urgency)
    border.color: Qt.lighter(urgencyColor(notif.urgency), 1.3)
    border.width: 1

    // Auto-dismiss timer
    Timer {
        interval: notif.timeout_ms > 0 ? notif.timeout_ms : 5000
        running: true
        onTriggered: {
            dismissAnim.start()
        }
    }

    // Slide-in animation
    NumberAnimation on x {
        from: 400; to: 0
        duration: 250
        easing.type: Easing.OutCubic
        running: true
    }

    // Slide-out
    NumberAnimation {
        id: dismissAnim
        target: toast
        property: "opacity"
        to: 0
        duration: 200
        onFinished: toast.dismissed()
    }

    Column {
        id: contentCol
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.spacingLarge
        }
        spacing: 4

        Row {
            width: parent.width
            spacing: 6

            Text {
                text: notif.app_name
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }

            Item { width: parent.width - appName.width - dismissBtn.width - 12; height: 1 }

            Text {
                id: dismissBtn
                text: "✕"
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall

                MouseArea {
                    anchors.fill: parent
                    onClicked: dismissAnim.start()
                }
            }
        }

        Text {
            id: appName
            width: parent.width
            text: notif.summary
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: notif.body
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            visible: notif.body !== ""
        }
    }

    function urgencyColor(u) {
        switch(u) {
            case 0: return Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0.95)
            case 2: return Qt.rgba(Theme.red.r * 0.3, Theme.red.g * 0.3, Theme.red.b * 0.3, 0.97)
            default: return Qt.rgba(Theme.surface1.r, Theme.surface1.g, Theme.surface1.b, 0.95)
        }
    }
}
