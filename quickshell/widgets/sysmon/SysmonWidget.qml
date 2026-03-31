import QtQuick
import QtQuick.Layouts
import "../../common/theme"
import "../../common/components"

Item {
    id: root
    height: Theme.barHeight
    width: row.width

    property real cpuPercent: 0
    property real memPercent: 0
    property real rxRate: 0
    property real txRate: 0

    RustiqClient { id: client }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            client.sysmon(function(data) {
                if (!data) return
                root.cpuPercent = data.cpu.usage_percent
                root.memPercent = data.memory.used_percent

                // Sum all non-loopback interfaces
                var rx = 0, tx = 0
                data.network.forEach(function(iface) {
                    rx += iface.rx_rate_bps
                    tx += iface.tx_rate_bps
                })
                root.rxRate = rx
                root.txRate = tx
            })
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingLarge

        // CPU
        SysmonPill {
            icon: ""
            value: Math.round(root.cpuPercent)
            unit: "%"
            color: cpuColor(root.cpuPercent)
        }

        // RAM
        SysmonPill {
            icon: ""
            value: Math.round(root.memPercent)
            unit: "%"
            color: memColor(root.memPercent)
        }

        // Network
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            NetRate { icon: "↑"; rate: root.txRate }
            NetRate { icon: "↓"; rate: root.rxRate }
        }
    }

    function cpuColor(pct) {
        if (pct > 85) return Theme.red
        if (pct > 60) return Theme.peach
        return Theme.green
    }

    function memColor(pct) {
        if (pct > 90) return Theme.red
        if (pct > 70) return Theme.yellow
        return Theme.blue
    }

    function formatRate(bps) {
        if (bps > 1048576) return (bps / 1048576).toFixed(1) + "M"
        if (bps > 1024)    return (bps / 1024).toFixed(0) + "K"
        return bps + "B"
    }
}

component SysmonPill: Row {
    property string icon
    property real value
    property string unit
    property color color: Theme.text
    spacing: 3
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Text {
        text: icon
        color: parent.color
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        anchors.verticalCenter: parent.verticalCenter
    }
    Text {
        text: parent.value + parent.unit
        color: parent.color
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
    }
}

component NetRate: Row {
    property string icon
    property real rate
    spacing: 2

    Text {
        text: icon
        color: Theme.overlay1
        font.family: Theme.fontFamily
        font.pixelSize: 9
    }
    Text {
        text: formatRate(rate)
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: 9
    }

    function formatRate(bps) {
        if (bps > 1048576) return (bps / 1048576).toFixed(1) + "M"
        if (bps > 1024)    return (bps / 1024).toFixed(0) + "K"
        return bps + "B"
    }
}
