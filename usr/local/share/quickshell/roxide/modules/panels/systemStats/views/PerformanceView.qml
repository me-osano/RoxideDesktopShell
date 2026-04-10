import QtQuick
import QtQuick.Layouts
import qs.common.theme
import qs.services
import qs.widgets

ColumnLayout {
  anchors.fill: parent
  spacing: Style.marginM

  // CPU Card
  RBox {
    Layout.fillWidth: true
    Layout.preferredHeight: cardHeight

    property real cardHeight: 90 * Style.uiScaleRatio

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginS
      anchors.bottomMargin: Style.radiusM * 0.5
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        RIcon {
          icon: "cpu-usage"
          pointSize: Style.fontSizeXS
          color: Color.mPrimary
        }

        RText {
          text: `${Math.round(SystemStatService.cpuUsage)}% (${SystemStatService.cpuFreq.replace(/[^0-9.]/g, "")} GHz)`
          pointSize: Style.fontSizeXS
          color: Color.mPrimary
          font.family: Settings.data.ui.fontFixed
        }

        RIcon {
          icon: "cpu-temperature"
          pointSize: Style.fontSizeXS
          color: Color.mSecondary
        }

        RText {
          text: `${Math.round(SystemStatService.cpuTemp)}°C`
          pointSize: Style.fontSizeXS
          color: Color.mSecondary
          font.family: Settings.data.ui.fontFixed
          Layout.rightMargin: Style.marginS
        }

        Item {
          Layout.fillWidth: true
        }

        RText {
          text: "CPU"
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }
      }

      RGraph {
        Layout.fillWidth: true
        Layout.fillHeight: true
        values: SystemStatService.cpuHistory
        values2: SystemStatService.cpuTempHistory
        minValue: 0
        maxValue: 100
        minValue2: Math.max(SystemStatService.cpuTempHistoryMin - 5, 0)
        maxValue2: Math.max(SystemStatService.cpuTempHistoryMax + 5, 1)
        color: Color.mPrimary
        color2: Color.mSecondary
        fill: true
        fillOpacity: 0.15
        updateInterval: SystemStatService.cpuUsageIntervalMs
      }
    }
  }

  // Memory Card
  RBox {
    Layout.fillWidth: true
    Layout.preferredHeight: cardHeight

    property real cardHeight: 90 * Style.uiScaleRatio

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginS
      anchors.bottomMargin: Style.radiusM * 0.5
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        RIcon {
          icon: "memory"
          pointSize: Style.fontSizeXS
          color: Color.mPrimary
        }

        RText {
          text: `${Math.round(SystemStatService.memPercent)}% (${SystemStatService.formatGigabytes(SystemStatService.memGb).replace(/[^0-9.]/g, "")} GB)`
          pointSize: Style.fontSizeXS
          color: Color.mPrimary
          font.family: Settings.data.ui.fontFixed
        }

        Item {
          Layout.fillWidth: true
        }

        RText {
          text: "Memory"
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }
      }

      RGraph {
        Layout.fillWidth: true
        Layout.fillHeight: true
        values: SystemStatService.memHistory
        minValue: 0
        maxValue: 100
        color: Color.mPrimary
        fill: true
        fillOpacity: 0.15
        updateInterval: SystemStatService.memIntervalMs
      }
    }
  }

  // Network Card
  RBox {
    Layout.fillWidth: true
    Layout.preferredHeight: cardHeight

    property real cardHeight: 90 * Style.uiScaleRatio

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginS
      anchors.bottomMargin: Style.radiusM * 0.5
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        RIcon {
          icon: "download-speed"
          pointSize: Style.fontSizeXS
          color: Color.mPrimary
        }

        RText {
          text: SystemStatService.formatSpeed(SystemStatService.rxSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s"
          pointSize: Style.fontSizeXS
          color: Color.mPrimary
          font.family: Settings.data.ui.fontFixed
          Layout.rightMargin: Style.marginS
        }

        RIcon {
          icon: "upload-speed"
          pointSize: Style.fontSizeXS
          color: Color.mSecondary
        }

        RText {
          text: SystemStatService.formatSpeed(SystemStatService.txSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s"
          pointSize: Style.fontSizeXS
          color: Color.mSecondary
          font.family: Settings.data.ui.fontFixed
        }

        Item {
          Layout.fillWidth: true
        }

        RText {
          text: "Network"
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }
      }

      RGraph {
        Layout.fillWidth: true
        Layout.fillHeight: true
        values: SystemStatService.rxSpeedHistory
        values2: SystemStatService.txSpeedHistory
        minValue: 0
        maxValue: SystemStatService.rxMaxSpeed
        minValue2: 0
        maxValue2: SystemStatService.txMaxSpeed
        color: Color.mPrimary
        color2: Color.mSecondary
        fill: true
        fillOpacity: 0.15
        updateInterval: SystemStatService.networkIntervalMs
        animateScale: true
      }
    }
  }
}
