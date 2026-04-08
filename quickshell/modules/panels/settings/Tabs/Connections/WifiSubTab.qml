import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Bluetooth

import qs.Commons
import qs.Modules.Panels.Network
import qs.Services.Networking
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Password and expand states for WiFi networks
  property string passwordSsid: ""
  property string expandedSsid: ""

  // Computed network lists
  readonly property var knownNetworks: {
    if (!Settings.data.network.wifiEnabled)
      return [];

    var nets = Object.values(NetworkService.networks);
    var known = nets.filter(n => n.connected || n.existing || n.cached);

    // Sort: connected first, then by signal strength
    known.sort((a, b) => {
      if (a.connected !== b.connected)
        return b.connected - a.connected;
      return b.signal - a.signal;
    });

    return known;
  }

  readonly property var availableNetworks: {
    if (!Settings.data.network.wifiEnabled)
      return [];

    var nets = Object.values(NetworkService.networks);
    var available = nets.filter(n => !n.connected && !n.existing && !n.cached);

    // Sort by signal strength
    available.sort((a, b) => b.signal - a.signal);

    return available;
  }

  // Master Controls
  RBox {
    Layout.fillWidth: true
    Layout.preferredHeight: masterControlCol.implicitHeight + Style.margin2L
    color: Color.mSurface

    ColumnLayout {
      id: masterControlCol
      spacing: Style.marginL
      anchors.fill: parent
      anchors.margins: Style.marginL

      // Airplane Mode Toggle
      RToggle {
        Layout.fillWidth: true
        label: "Airplane Mode"
        description: "Disable all wireless connections"
        icon: Settings.data.network.airplaneModeEnabled ? "plane" : "plane-off"
        checked: Settings.data.network.airplaneModeEnabled
        onToggled: checked => BluetoothService.setAirplaneMode(checked)
      }

      RDivider {
        Layout.fillWidth: true
      }

      // Wi-Fi Master Control
      RToggle {
        Layout.fillWidth: true
        label: "Wi-Fi"
        description: NetworkService.wifiAvailable ? "Wireless network connectivity" : "No Wi-Fi adapter detected"
        icon: Settings.data.network.wifiEnabled ? "wifi" : "wifi-off"
        checked: Settings.data.network.wifiEnabled
        onToggled: checked => NetworkService.setWifiEnabled(checked)
        enabled: ProgramCheckerService.nmcliAvailable && !Settings.data.network.airplaneModeEnabled && NetworkService.wifiAvailable
      }
    }
  }

  // Connection Status
  RBox {
    Layout.fillWidth: true
    Layout.preferredHeight: statusCol.implicitHeight + Style.margin2L
    color: Color.mSurface

    // Helper properties for connection state
    readonly property bool hasWifiConnection: {
      for (const net in NetworkService.networks) {
        if (NetworkService.networks[net].connected) return true;
      }
      return false;
    }
    readonly property string connectedSsid: {
      for (const net in NetworkService.networks) {
        if (NetworkService.networks[net].connected) return net;
      }
      return "";
    }
    readonly property int connectedSignal: {
      for (const net in NetworkService.networks) {
        if (NetworkService.networks[net].connected) return NetworkService.networks[net].signal;
      }
      return 0;
    }
    readonly property color signalColor: {
      if (!hasWifiConnection) return Color.mOnSurfaceVariant;
      if (connectedSignal >= 70) return Color.mPrimary;
      if (connectedSignal >= 40) return Color.mWarning || Color.mOnSurface;
      return Color.mError;
    }
    readonly property string signalQuality: {
      if (!hasWifiConnection) return "";
      if (connectedSignal >= 70) return "Excellent";
      if (connectedSignal >= 50) return "Good";
      if (connectedSignal >= 30) return "Fair";
      return "Weak";
    }

    // Internet connectivity indicator (anchored top-right)
    Rectangle {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Style.marginL
      anchors.rightMargin: Style.marginL
      z: 1
      height: internetIndicatorContent.implicitHeight + Style.marginS * 2
      width: internetIndicatorContent.implicitWidth + Style.marginM * 2
      radius: height / 2
      color: NetworkService.internetConnectivity ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.1) : Qt.rgba(Color.mError.r, Color.mError.g, Color.mError.b, 0.1)
      border.width: 1
      border.color: NetworkService.internetConnectivity ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.2) : Qt.rgba(Color.mError.r, Color.mError.g, Color.mError.b, 0.2)

      RowLayout {
        id: internetIndicatorContent
        anchors.centerIn: parent
        spacing: Style.marginS

        // Status dot with pulse animation
        Rectangle {
          id: statusDot
          Layout.preferredWidth: 8
          Layout.preferredHeight: 8
          radius: 4
          color: NetworkService.internetConnectivity ? Color.mPrimary : Color.mError

          SequentialAnimation on opacity {
            id: pulseAnimation
            running: NetworkService.internetConnectivity
            loops: Animation.Infinite
            alwaysRunToEnd: false
            NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
          }

          // Reset opacity when animation stops
          Connections {
            target: pulseAnimation
            function onRunningChanged() {
              if (!pulseAnimation.running) {
                statusDot.opacity = 1.0;
              }
            }
          }
        }

        RIcon {
          icon: NetworkService.internetConnectivity ? "world" : "world-off"
          pointSize: Style.fontSizeS
          color: NetworkService.internetConnectivity ? Color.mPrimary : Color.mError
        }

        RText {
          text: NetworkService.internetConnectivity ? "Online" : "Offline"
          pointSize: Style.fontSizeXS
          font.weight: Style.fontWeightMedium
          color: NetworkService.internetConnectivity ? Color.mPrimary : Color.mError
        }
      }
    }

    ColumnLayout {
      id: statusCol
      spacing: Style.marginL
      anchors.fill: parent
      anchors.margins: Style.marginL

      RHeader {
        label: "Connection Status"
      }

      // Main connection card - Wi-Fi
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: wifiStatusContent.implicitHeight + Style.marginL * 2
        radius: Style.radiusM
        color: parent.parent.hasWifiConnection ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08) : Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.05)
        border.width: 1
        border.color: parent.parent.hasWifiConnection ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.2) : Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.1)
        visible: Settings.data.network.wifiEnabled

        RowLayout {
          id: wifiStatusContent
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginL

          // Large animated Wi-Fi icon with glow effect
          Item {
            Layout.preferredWidth: Style.baseWidgetSize * 1.4
            Layout.preferredHeight: Style.baseWidgetSize * 1.4

            // Glow effect for connected state
            Rectangle {
              anchors.centerIn: parent
              width: parent.width
              height: parent.height
              radius: width / 2
              color: "transparent"
              border.width: 2
              border.color: parent.parent.parent.parent.parent.hasWifiConnection ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.3) : "transparent"
              visible: parent.parent.parent.parent.parent.hasWifiConnection

              SequentialAnimation on opacity {
                running: parent.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
              }
            }

            Rectangle {
              anchors.centerIn: parent
              width: parent.width * 0.85
              height: parent.height * 0.85
              radius: width / 2
              color: parent.parent.parent.parent.hasWifiConnection ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.15) : Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.1)

              RIcon {
                anchors.centerIn: parent
                icon: {
                  const box = statusCol.parent;
                  return box.hasWifiConnection ? NetworkService.signalIcon(box.connectedSignal, true) : "wifi-off";
                }
                pointSize: Style.fontSizeXXL
                color: statusCol.parent.hasWifiConnection ? Color.mPrimary : Color.mOnSurfaceVariant
              }
            }
          }

          // Connection info
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            RowLayout {
              spacing: Style.marginS

              RText {
                text: statusCol.parent.hasWifiConnection ? statusCol.parent.connectedSsid : "Not connected"
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeL
              }

              // Connection quality badge
              Rectangle {
                visible: statusCol.parent.hasWifiConnection
                Layout.preferredHeight: qualityText.implicitHeight + Style.marginXS
                Layout.preferredWidth: qualityText.implicitWidth + Style.marginM
                radius: height / 2
                color: Qt.rgba(statusCol.parent.signalColor.r, statusCol.parent.signalColor.g, statusCol.parent.signalColor.b, 0.15)

                RText {
                  id: qualityText
                  anchors.centerIn: parent
                  text: statusCol.parent.signalQuality
                  pointSize: Style.fontSizeXS
                  font.weight: Style.fontWeightMedium
                  color: statusCol.parent.signalColor
                }
              }
            }

            // Signal strength bar
            RowLayout {
              visible: statusCol.parent.hasWifiConnection
              spacing: Style.marginS
              Layout.fillWidth: true

              RText {
                text: "Signal"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                Layout.maximumWidth: 120
                radius: 3
                color: Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.2)

                Rectangle {
                  width: parent.width * (statusCol.parent.connectedSignal / 100)
                  height: parent.height
                  radius: 3
                  color: statusCol.parent.signalColor

                  Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                  }
                }
              }

              RText {
                text: statusCol.parent.connectedSignal + "%"
                pointSize: Style.fontSizeXS
                font.weight: Style.fontWeightMedium
                color: statusCol.parent.signalColor
              }
            }

            // Connection details
            RText {
              visible: statusCol.parent.hasWifiConnection
              text: {
                const w = NetworkService.activeWifiDetails || ({});
                const parts = [];
                if (w.rateShort) parts.push(w.rateShort);
                if (w.freq) parts.push(w.freq);
                if (w.security) parts.push(w.security);
                return parts.length > 0 ? parts.join(" · ") : "Connected";
              }
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            RText {
              visible: !statusCol.parent.hasWifiConnection && Settings.data.network.wifiEnabled
              text: "Select a network to connect"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }

          // Disconnect button
          RButton {
            visible: statusCol.parent.hasWifiConnection
            text: "Disconnect"
            onClicked: NetworkService.disconnect(statusCol.parent.connectedSsid)
          }
        }
      }

      // Ethernet status card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: ethernetStatusContent.implicitHeight + Style.marginL * 2
        radius: Style.radiusM
        color: NetworkService.ethernetConnected ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08) : Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.05)
        border.width: 1
        border.color: NetworkService.ethernetConnected ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.2) : Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.1)
        visible: NetworkService.ethernetAvailable

        RowLayout {
          id: ethernetStatusContent
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginL

          // Ethernet icon
          Rectangle {
            Layout.preferredWidth: Style.baseWidgetSize * 1.2
            Layout.preferredHeight: Style.baseWidgetSize * 1.2
            radius: width / 2
            color: NetworkService.ethernetConnected ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.15) : Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.1)

            RIcon {
              anchors.centerIn: parent
              icon: NetworkService.ethernetConnected ? "ethernet" : "ethernet-off"
              pointSize: Style.fontSizeXL
              color: NetworkService.ethernetConnected ? Color.mPrimary : Color.mOnSurfaceVariant
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            RowLayout {
              spacing: Style.marginS

              RText {
                text: NetworkService.ethernetConnected ? "Ethernet" : "Ethernet Disconnected"
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeM
              }

              // Connected badge
              Rectangle {
                visible: NetworkService.ethernetConnected
                Layout.preferredHeight: ethBadgeText.implicitHeight + Style.marginXS
                Layout.preferredWidth: ethBadgeText.implicitWidth + Style.marginM
                radius: height / 2
                color: Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.15)

                RText {
                  id: ethBadgeText
                  anchors.centerIn: parent
                  text: "Connected"
                  pointSize: Style.fontSizeXS
                  font.weight: Style.fontWeightMedium
                  color: Color.mPrimary
                }
              }
            }

            RText {
              visible: NetworkService.ethernetConnected
              text: {
                const d = NetworkService.activeEthernetDetails || ({});
                const parts = [];
                if (d.speed) parts.push(d.speed);
                if (d.ipv4) parts.push(d.ipv4);
                return parts.length > 0 ? parts.join(" · ") : "Wired connection";
              }
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }
        }
      }
    }
  }

  // Network Details (when connected to Wi-Fi)
  RCollapsible {
    Layout.fillWidth: true
    label: "Wi-Fi Details"
    visible: {
      for (const net in NetworkService.networks) {
        if (NetworkService.networks[net].connected) {
          return true;
        }
      }
      return false;
    }

    ColumnLayout {
      spacing: Style.marginS
      Layout.fillWidth: true

      // SSID
      RowLayout {
        Layout.fillWidth: true
        RText {
          text: "Network Name"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: {
            for (const net in NetworkService.networks) {
              if (NetworkService.networks[net].connected) {
                return net;
              }
            }
            return "—";
          }
          pointSize: Style.fontSizeS
          Layout.fillWidth: true
        }
      }

      // Signal Strength
      RowLayout {
        Layout.fillWidth: true
        RText {
          text: "Signal Strength"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: {
            for (const net in NetworkService.networks) {
              if (NetworkService.networks[net].connected) {
                return NetworkService.networks[net].signal + "%";
              }
            }
            return "—";
          }
          pointSize: Style.fontSizeS
          Layout.fillWidth: true
        }
      }

      // Frequency
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeWifiDetails && NetworkService.activeWifiDetails.freq)
        RText {
          text: "Frequency"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeWifiDetails ? (NetworkService.activeWifiDetails.freq || "—") : "—"
          pointSize: Style.fontSizeS
          Layout.fillWidth: true
        }
      }

      // Link Speed
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeWifiDetails && NetworkService.activeWifiDetails.rate)
        RText {
          text: "Link Speed"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeWifiDetails ? (NetworkService.activeWifiDetails.rate || "—") : "—"
          pointSize: Style.fontSizeS
          Layout.fillWidth: true
        }
      }

      // Security
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeWifiDetails && NetworkService.activeWifiDetails.security)
        RText {
          text: "Security"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeWifiDetails ? (NetworkService.activeWifiDetails.security || "—") : "—"
          pointSize: Style.fontSizeS
          Layout.fillWidth: true
        }
      }

      // BSSID
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeWifiDetails && NetworkService.activeWifiDetails.bssid)
        RText {
          text: "BSSID"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeWifiDetails ? (NetworkService.activeWifiDetails.bssid || "—") : "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          Layout.fillWidth: true
        }
      }

      // IPv4 Address
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeWifiDetails && NetworkService.activeWifiDetails.ipv4)
        RText {
          text: "IPv4 Address"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeWifiDetails ? (NetworkService.activeWifiDetails.ipv4 || "—") : "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          Layout.fillWidth: true
        }
      }

      // IPv6 Address
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeWifiDetails && NetworkService.activeWifiDetails.ipv6)
        RText {
          text: "IPv6 Address"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeWifiDetails ? (NetworkService.activeWifiDetails.ipv6 || "—") : "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          elide: Text.ElideMiddle
          Layout.fillWidth: true
        }
      }

      // Gateway
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeWifiDetails && NetworkService.activeWifiDetails.gateway)
        RText {
          text: "Gateway"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeWifiDetails ? (NetworkService.activeWifiDetails.gateway || "—") : "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          Layout.fillWidth: true
        }
      }

      // DNS
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeWifiDetails && NetworkService.activeWifiDetails.dns)
        RText {
          text: "DNS"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeWifiDetails ? (NetworkService.activeWifiDetails.dns || "—") : "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          Layout.fillWidth: true
        }
      }
    }
  }

  // Ethernet Details (when connected)
  RCollapsible {
    Layout.fillWidth: true
    label: "Ethernet Details"
    visible: NetworkService.ethernetConnected

    ColumnLayout {
      spacing: Style.marginS
      Layout.fillWidth: true

      // Interface
      RowLayout {
        Layout.fillWidth: true
        visible: !!NetworkService.activeEthernetIf
        RText {
          text: "Interface"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeEthernetIf || "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          Layout.fillWidth: true
        }
      }

      // Speed
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeEthernetDetails && NetworkService.activeEthernetDetails.speed)
        RText {
          text: "Link Speed"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeEthernetDetails ? (NetworkService.activeEthernetDetails.speed || "—") : "—"
          pointSize: Style.fontSizeS
          Layout.fillWidth: true
        }
      }

      // IPv4 Address
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeEthernetDetails && NetworkService.activeEthernetDetails.ipv4)
        RText {
          text: "IPv4 Address"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeEthernetDetails ? (NetworkService.activeEthernetDetails.ipv4 || "—") : "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          Layout.fillWidth: true
        }
      }

      // IPv6 Address
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeEthernetDetails && NetworkService.activeEthernetDetails.ipv6)
        RText {
          text: "IPv6 Address"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeEthernetDetails ? (NetworkService.activeEthernetDetails.ipv6 || "—") : "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          elide: Text.ElideMiddle
          Layout.fillWidth: true
        }
      }

      // Gateway
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeEthernetDetails && NetworkService.activeEthernetDetails.gateway)
        RText {
          text: "Gateway"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeEthernetDetails ? (NetworkService.activeEthernetDetails.gateway || "—") : "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          Layout.fillWidth: true
        }
      }

      // DNS
      RowLayout {
        Layout.fillWidth: true
        visible: !!(NetworkService.activeEthernetDetails && NetworkService.activeEthernetDetails.dns)
        RText {
          text: "DNS"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.preferredWidth: 120
        }
        RText {
          text: NetworkService.activeEthernetDetails ? (NetworkService.activeEthernetDetails.dns || "—") : "—"
          pointSize: Style.fontSizeS
          font.family: Style.fontMono
          Layout.fillWidth: true
        }
      }
    }
  }

  // Known Networks
  RBox {
    Layout.fillWidth: true
    Layout.preferredHeight: knownNetworksCol.implicitHeight + Style.margin2L
    color: Color.mSurface
    visible: Settings.data.network.wifiEnabled && root.knownNetworks.length > 0

    ColumnLayout {
      id: knownNetworksCol
      spacing: Style.marginM
      anchors.fill: parent
      anchors.margins: Style.marginL

      RHeader {
        label: "Known Networks"
      }

      WiFiNetworksList {
        Layout.fillWidth: true
        model: root.knownNetworks
        passwordSsid: root.passwordSsid
        expandedSsid: root.expandedSsid
        onPasswordRequested: ssid => {
          root.passwordSsid = ssid;
          root.expandedSsid = "";
        }
        onPasswordSubmitted: (ssid, password) => {
          NetworkService.connect(ssid, password);
          root.passwordSsid = "";
        }
        onPasswordCancelled: root.passwordSsid = ""
        onForgetRequested: ssid => root.expandedSsid = root.expandedSsid === ssid ? "" : ssid
        onForgetConfirmed: ssid => {
          NetworkService.forget(ssid);
          root.expandedSsid = "";
        }
        onForgetCancelled: root.expandedSsid = ""
      }
    }
  }

  // Available Networks
  RBox {
    Layout.fillWidth: true
    Layout.preferredHeight: availableNetworksCol.implicitHeight + Style.margin2L
    color: Color.mSurface
    visible: Settings.data.network.wifiEnabled && root.availableNetworks.length > 0

    ColumnLayout {
      id: availableNetworksCol
      spacing: Style.marginM
      anchors.fill: parent
      anchors.margins: Style.marginL

      RHeader {
        label: "Available Networks"
      }

      WiFiNetworksList {
        Layout.fillWidth: true
        model: root.availableNetworks
        passwordSsid: root.passwordSsid
        expandedSsid: root.expandedSsid
        onPasswordRequested: ssid => {
          root.passwordSsid = ssid;
          root.expandedSsid = "";
        }
        onPasswordSubmitted: (ssid, password) => {
          NetworkService.connect(ssid, password);
          root.passwordSsid = "";
        }
        onPasswordCancelled: root.passwordSsid = ""
        onForgetRequested: ssid => root.expandedSsid = root.expandedSsid === ssid ? "" : ssid
        onForgetConfirmed: ssid => {
          NetworkService.forget(ssid);
          root.expandedSsid = "";
        }
        onForgetCancelled: root.expandedSsid = ""
      }
    }
  }

  // Scanning indicator
  RBox {
    Layout.fillWidth: true
    Layout.preferredHeight: scanningCol.implicitHeight + Style.margin2L
    color: Color.mSurface
    visible: Settings.data.network.wifiEnabled && NetworkService.scanning

    ColumnLayout {
      id: scanningCol
      spacing: Style.marginM
      anchors.fill: parent
      anchors.margins: Style.marginL

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        RBusyIndicator {
          running: visible
          color: Color.mPrimary
          size: Style.baseWidgetSize * 0.6
        }

        RText {
          text: "Scanning for networks..."
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
      }
    }
  }

  // Quick Actions
  RBox {
    Layout.fillWidth: true
    Layout.preferredHeight: actionsCol.implicitHeight + Style.margin2L
    color: Color.mSurface

    ColumnLayout {
      id: actionsCol
      spacing: Style.marginM
      anchors.fill: parent
      anchors.margins: Style.marginL

      RHeader {
        label: "Quick Actions"
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        RButton {
          text: "Scan Networks"
          icon: "refresh"
          enabled: Settings.data.network.wifiEnabled && !NetworkService.scanning
          onClicked: NetworkService.scan()
        }

        RButton {
          text: "Open Network Panel"
          icon: "wifi"
          onClicked: {
            var panel = PanelService.getPanel("networkPanel", null);
            if (panel) panel.toggle();
          }
        }
      }
    }
  }


  // Spacer to push content up
  Item {
    Layout.fillHeight: true
  }
}
