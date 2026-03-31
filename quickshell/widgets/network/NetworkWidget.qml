import QtQuick
import "../../common/theme"
import "../../common/components"

Item {
    id: root
    height: Theme.barHeight
    width: row.width

    // Network state — populated from sysmon poll
    property string ssid: ""
    property bool connected: false
    property bool wifi: true

    // Poll via sysmon (network interfaces) every 5s
    RustiqClient { id: client }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            client.sysmon(function(data) {
                if (!data) return
                var ifaces = data.network
                var active = ifaces.find(function(i) {
                    return i.name.startsWith("wl") || i.name.startsWith("en")
                })
                root.connected = !!active
                root.wifi = active ? active.name.startsWith("wl") : false
            })
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            text: root.wifi ? (root.connected ? "󰤨" : "󰤭")
                            : (root.connected ? "󰈀" : "󰈂")
            color: root.connected ? Theme.green : Theme.red
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
