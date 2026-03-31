// RUSTIQ Launcher — Spotlight-style overlay
// Toggle with: niri keybind → `rustiq launcher toggle`
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../common/theme"
import "../common/components"

PopupWindow {
    id: launcher

    property bool open: false
    visible: open

    // Center on screen
    anchor.rect.x: (screen.width - width) / 2
    anchor.rect.y: (screen.height - height) / 4
    width: 640
    height: Math.min(520, resultsColumn.height + searchBox.height + Theme.spacingLarge * 3)

    color: "transparent"

    // Toggle function — call from keybind via IPC
    function toggle() { open = !open; if (open) { searchInput.text = ""; searchInput.forceActiveFocus(); doSearch("") } }
    function close()  { open = false }

    RustiqClient { id: client }

    property var results: []
    property bool searching: false
    property string mode: "apps"  // "apps" | "files"

    function doSearch(query) {
        if (query === "") {
            // Show app list placeholder
            root.results = []
            return
        }
        searching = true
        if (query.startsWith("/") || query.startsWith("~")) {
            mode = "files"
            client.search(query, 20, function(data) {
                searching = false
                if (data) results = data.hits
            })
        } else {
            mode = "apps"
            client.search(query, 20, function(data) {
                searching = false
                if (data) results = data.hits
            })
        }
    }

    // Background blur + rounded card
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.95)
        border.color: Theme.surface1
        border.width: 1

        // Drop shadow via layered rect
        layer.enabled: true
        layer.effect: null  // TODO: MultiEffect drop shadow

        Column {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingLarge
            spacing: Theme.spacing

            // Search input
            Rectangle {
                id: searchBox
                width: parent.width
                height: 44
                radius: Theme.radius
                color: Theme.surface0
                border.color: searchInput.activeFocus ? Theme.accent : "transparent"
                border.width: 2

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.padding
                    spacing: 8

                    Text {
                        text: launcher.searching ? "⟳" : "󰍉"
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 32
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        placeholderText: "Search apps, files…"
                        placeholderTextColor: Theme.overlay0
                        selectByMouse: true

                        onTextChanged: launcher.doSearch(text)
                        Keys.onEscapePressed: launcher.close()
                        Keys.onReturnPressed: {
                            if (launcher.results.length > 0) {
                                launcher.activateResult(launcher.results[0])
                            }
                        }
                    }
                }
            }

            // Results
            Column {
                id: resultsColumn
                width: parent.width
                spacing: 2
                visible: launcher.results.length > 0

                Repeater {
                    model: launcher.results.slice(0, 10)
                    delegate: ResultRow {
                        width: resultsColumn.width
                        hit: modelData
                        onActivated: launcher.activateResult(modelData)
                    }
                }
            }

            // Empty state
            Text {
                width: parent.width
                text: searchInput.text === "" ? "Type to search…" : "No results"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignHCenter
                visible: launcher.results.length === 0
                topPadding: Theme.spacingLarge
            }
        }
    }

    function activateResult(hit) {
        if (hit.kind === "file" || hit.kind === "directory") {
            // Open with xdg-open
            client.launch("xdg-open " + hit.path)
        } else {
            client.launch(hit.name)
        }
        close()
    }

    // Close on outside click
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: launcher.close()
    }
}

component ResultRow: Rectangle {
    property var hit
    signal activated

    height: 40
    radius: Theme.radius
    color: ma.containsMouse ? Theme.surface0 : "transparent"

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        // Kind icon
        Text {
            text: kindIcon(hit.kind)
            color: kindColor(hit.kind)
            font.family: Theme.fontFamily
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 20
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                text: hit.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Text {
                text: hit.path
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideLeft
                width: 540
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: parent.activated()
    }

    function kindIcon(kind) {
        switch(kind) {
            case "directory":  return "󰉋"
            case "image":      return "󰋩"
            case "video":      return "󰈫"
            case "audio":      return "󰈣"
            case "document":   return "󰈙"
            case "code":       return "󰈮"
            default:           return "󰈔"
        }
    }

    function kindColor(kind) {
        switch(kind) {
            case "directory": return Theme.blue
            case "image":     return Theme.pink
            case "video":     return Theme.mauve
            case "audio":     return Theme.peach
            case "document":  return Theme.green
            case "code":      return Theme.teal
            default:          return Theme.overlay1
        }
    }
}
