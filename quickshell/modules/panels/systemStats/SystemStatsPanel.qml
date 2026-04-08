import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  Component.onCompleted: SystemStatService.registerComponent("panel-systemstats")
  Component.onDestruction: SystemStatService.unregisterComponent("panel-systemstats")

  preferredWidth: Math.round(440 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent
    property real contentPreferredHeight: mainColumn.implicitHeight + Style.margin2L
    readonly property real cardHeight: 90 * Style.uiScaleRatio

    // Get diskPath from bar's SystemMonitor widget if available, otherwise use "/"
    readonly property string diskPath: {
      const sysMonWidget = BarService.lookupWidget("SystemMonitor");
      if (sysMonWidget && sysMonWidget.diskPath) {
        return sysMonWidget.diskPath;
      }
      return "/";
    }

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // HEADER
      RBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RIcon {
            icon: "device-analytics"
            pointSize: Style.fontSizeXXL
            color: Color.mPrimary
          }

          RText {
            text: "System Monitor"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "close"
            tooltipText: "Close"
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              root.close();
            }
          }
        }
      }

      // CPU Card (dual-line: usage % + temperature °C)
      RBox {
        Layout.fillWidth: true
        Layout.preferredHeight: panelContent.cardHeight

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
              text: "CPU usage"
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

      // Memory Card (single-line + optional swap indicator)
      RBox {
        Layout.fillWidth: true
        Layout.preferredHeight: panelContent.cardHeight

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

      // Network Card (dual-line: RX + TX speeds)
      RBox {
        Layout.fillWidth: true
        Layout.preferredHeight: panelContent.cardHeight

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

      // Detailed Stats section
      RBox {
        Layout.fillWidth: true
        implicitHeight: detailsColumn.implicitHeight + Style.margin2M

        ColumnLayout {
          id: detailsColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.marginM
          spacing: Style.marginXS

          // Load Average
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: SystemStatService.nproc > 0

            RIcon {
              icon: "cpu-usage"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            RText {
              text: "Load average" + ":"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            RText {
              text: `${SystemStatService.loadAvg1.toFixed(2)} • ${SystemStatService.loadAvg5.toFixed(2)} • ${SystemStatService.loadAvg15.toFixed(2)}`
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
            }
          }

          // GPU Temperature (only if available)
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: SystemStatService.gpuAvailable

            RIcon {
              icon: "gpu-temperature"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            RText {
              text: "GPU temp" + ":"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            RText {
              text: `${Math.round(SystemStatService.gpuTemp)}°C`
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
            }
          }

          // Disk usage
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            RIcon {
              icon: "storage"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            RText {
              text: "Disk" + ":"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            RText {
              text: {
                const usedGb = SystemStatService.diskUsedGb[panelContent.diskPath] || 0;
                const sizeGb = SystemStatService.diskSizeGb[panelContent.diskPath] || 0;
                const percent = SystemStatService.diskPercents[panelContent.diskPath] || 0;
                return `${percent}% (${usedGb.toFixed(1)} / ${sizeGb.toFixed(1)} GB)`;
              }
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideMiddle
            }
          }

          // Swap details (only visible if swap is enabled)
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: SystemStatService.swapTotalGb > 0

            RIcon {
              icon: "exchange"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            RText {
              text: "Swap usage" + ":"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            RText {
              text: `${SystemStatService.formatGigabytes(SystemStatService.swapGb).replace(/[^0-9.]/g, "")} / ${SystemStatService.formatGigabytes(SystemStatService.swapTotalGb).replace(/[^0-9.]/g, "")} GB`
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
            }
          }
        }
      }
    }
  }
}
