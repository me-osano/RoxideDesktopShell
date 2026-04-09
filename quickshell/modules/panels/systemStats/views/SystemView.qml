import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common.theme
import qs.services
import qs.widgets

ColumnLayout {
  anchors.fill: parent
  spacing: Style.marginM

  // System Info Card
  RBox {
    Layout.fillWidth: true
    implicitHeight: sysInfoCol.implicitHeight + Style.margin2M

    ColumnLayout {
      id: sysInfoCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        spacing: Style.marginS

        RIcon {
          icon: "computer"
          pointSize: Style.fontSizeM
          color: Color.mPrimary
        }

        RText {
          text: "System Information"
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: Style.marginS
        columnSpacing: Style.marginL

        InfoRow {
          label: "Hostname"
          value: HostService.hostName || "--"
        }
        InfoRow {
          label: "Distribution"
          value: HostService.osPretty || "--"
        }
        InfoRow {
          label: "Kernel"
          value: kernelText || "--"
        }
        InfoRow {
          label: "Architecture"
          value: archText || "--"
        }
        InfoRow {
          label: "CPU"
          value: SystemStatService.cpuFreq.replace(/[^0-9.]/g, "") + " GHz (" + SystemStatService.nproc + " cores)"
        }
        InfoRow {
          label: "Uptime"
          value: SysmonService.uptime || "--"
        }
        InfoRow {
          label: "Load Average"
          value: SystemStatService.loadAvg1.toFixed(2) + " • " + SystemStatService.loadAvg5.toFixed(2) + " • " + SystemStatService.loadAvg15.toFixed(2)
        }
        InfoRow {
          label: "Processes"
          value: SysmonService.processCount > 0 ? SysmonService.processCount.toString() : "--"
        }
      }
    }
  }

  // GPU Card (if available)
  RBox {
    Layout.fillWidth: true
    implicitHeight: gpuCol.implicitHeight + Style.margin2M
    visible: SystemStatService.gpuAvailable

    ColumnLayout {
      id: gpuCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        spacing: Style.marginS

        RIcon {
          icon: "developer-board"
          pointSize: Style.fontSizeM
          color: Color.mSecondary
        }

        RText {
          text: "GPU"
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginL

        Column {
          Layout.fillWidth: true
          spacing: Style.marginXS

          RText {
            text: SystemStatService.gpuType || "GPU"
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
          }

          RText {
            text: SystemStatService.gpuTemp > 0 ? (Math.round(SystemStatService.gpuTemp) + "°C") : "--"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: SystemStatService.gpuTemp > 85 ? Color.mError : (SystemStatService.gpuTemp > 70 ? Color.mTertiary : Color.mPrimary)
          }
        }

        Column {
          Layout.fillWidth: true
          spacing: Style.marginXS

          RText {
            text: "Temperature"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }

          RText {
            text: SystemStatService.gpuTemp > 85 ? "Critical" : (SystemStatService.gpuTemp > 70 ? "Warning" : "Normal")
            pointSize: Style.fontSizeS
            color: SystemStatService.gpuTemp > 85 ? Color.mError : (SystemStatService.gpuTemp > 70 ? Color.mTertiary : Color.mPrimary)
          }
        }
      }
    }
  }

  component InfoRow: ColumnLayout {
    property string label: ""
    property string value: ""

    spacing: 2

    RText {
      text: label + ":"
      pointSize: Style.fontSizeXS
      color: Color.mOnSurfaceVariant
    }

    RText {
      text: value
      pointSize: Style.fontSizeXS
      font.family: Settings.data.ui.fontFixed
      color: Color.mOnSurface
      elide: Text.ElideRight
      Layout.fillWidth: true
    }
  }
}
