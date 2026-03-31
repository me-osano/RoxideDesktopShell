// RUSTIQ Bar — top panel
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../common/theme"
import "../common/components"
import "../widgets/clock"
import "../widgets/sysmon"
import "../widgets/weather"
import "../widgets/network"
import "../widgets/media"

PanelWindow {
    id: bar

    // Anchor to top of screen, full width
    anchors {
        top: true
        left: true
        right: true
    }
    height: Theme.barHeight
    exclusiveZone: height  // reserves space — niri won't tile windows over bar

    color: Qt.rgba(
        Theme.base.r,
        Theme.base.g,
        Theme.base.b,
        Theme.barOpacity
    )

    // IPC client — polls on a timer
    RustiqClient { id: client }

    // State
    property var workspaces: []
    property string focusedTitle: ""
    property string focusedAppId: ""

    // Poll niri state every 500ms (until SSE is wired)
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            client.workspaces(function(data) {
                if (data) bar.workspaces = data
            })
            client.windows(function(data) {
                if (!data) return
                var focused = data.find(function(w) { return w.is_focused })
                if (focused) {
                    bar.focusedTitle = focused.title || ""
                    bar.focusedAppId = focused.app_id || ""
                }
            })
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingLarge
        anchors.rightMargin: Theme.spacingLarge
        spacing: Theme.spacing

        // LEFT: Workspaces
        WorkspaceSwitcher {
            workspaces: bar.workspaces
            onActivate: function(id) { client.activateWorkspace(id) }
        }

        // LEFT: Focused window title
        Text {
            text: bar.focusedTitle
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
            Layout.maximumWidth: 300
            Layout.leftMargin: Theme.spacingLarge
        }

        Item { Layout.fillWidth: true } // spacer

        // CENTER: Clock
        ClockWidget {}

        Item { Layout.fillWidth: true } // spacer

        // RIGHT: widgets
        NetworkWidget {}
        WeatherWidget {}
        SysmonWidget {}

        // RIGHT: System tray placeholder
        SystemTray {}

        // RIGHT: Session button
        SessionButton {}
    }
}

// ── Workspace Switcher ──────────────────────────────────────────────────────
component WorkspaceSwitcher: Row {
    property var workspaces: []
    signal activate(int id)
    spacing: 4

    Repeater {
        model: workspaces
        delegate: Rectangle {
            width: modelData.name ? nameText.width + 16 : 28
            height: 28
            radius: Theme.radius
            color: modelData.is_focused ? Theme.accent
                 : modelData.is_active  ? Theme.surface1
                 :                         "transparent"

            Text {
                id: nameText
                anchors.centerIn: parent
                text: modelData.name || String(modelData.idx)
                color: modelData.is_focused ? Theme.base : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: modelData.is_focused
            }

            MouseArea {
                anchors.fill: parent
                onClicked: parent.parent.activate(modelData.id)
            }
        }
    }
}

// ── System Tray placeholder ─────────────────────────────────────────────────
component SystemTray: Row {
    spacing: 4
    // TODO: wire StatusNotifierItem via Quickshell.Services.SystemTray
    Text {
        text: ""  // placeholder
        color: Theme.overlay1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}

// ── Session Button ──────────────────────────────────────────────────────────
component SessionButton: Rectangle {
    width: 28; height: 28
    radius: Theme.radius
    color: hovered ? Theme.surface1 : "transparent"
    property bool hovered: false

    Text {
        anchors.centerIn: parent
        text: "⏻"
        color: Theme.subtext1
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.hovered = true
        onExited:  parent.hovered = false
        // TODO: open session menu
        onClicked: Qt.quit()
    }
}
