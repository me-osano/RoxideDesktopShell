import QtQuick
import QtQuick.Layouts
import qs.common.theme
import qs.services
import qs.widgets

ColumnLayout {
  anchors.fill: parent
  spacing: Style.marginM

  // Quick stats bar
  RBox {
    Layout.fillWidth: true
    implicitHeight: statsRow.implicitHeight + Style.marginM

    RowLayout {
      id: statsRow
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginL

      Column {
        Layout.fillWidth: true
        spacing: Style.marginXS

        RText {
          text: "Total: " + (SysmonService.processCount > 0 ? SysmonService.processCount : "--")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurface
          font.family: Settings.data.ui.fontFixed
        }
      }

      Column {
        Layout.fillWidth: true
        spacing: Style.marginXS

        RText {
          text: "Running: " + (SysmonService.runningProcesses > 0 ? SysmonService.runningProcesses : "--")
          pointSize: Style.fontSizeXS
          color: Color.mPrimary
          font.family: Settings.data.ui.fontFixed
        }
      }

      Column {
        Layout.fillWidth: true
        spacing: Style.marginXS

        RText {
          text: "Sleeping: " + (SysmonService.sleepingProcesses > 0 ? SysmonService.sleepingProcesses : "--")
          pointSize: Style.fontSizeXS
          color: Color.mSecondary
          font.family: Settings.data.ui.fontFixed
        }
      }
    }
  }

  // Header row
  RBox {
    Layout.fillWidth: true
    implicitHeight: headerRow.implicitHeight + Style.marginS

    RowLayout {
      id: headerRow
      anchors.fill: parent
      anchors.margins: Style.marginS
      spacing: Style.marginXS

      RText {
        text: "Name"
        pointSize: Style.fontSizeXS
        font.weight: Style.fontWeightBold
        color: Color.mOnSurfaceVariant
        Layout.fillWidth: true
        Layout.minimumWidth: 120
      }

      RText {
        text: "CPU%"
        pointSize: Style.fontSizeXS
        font.weight: Style.fontWeightBold
        color: Color.mOnSurfaceVariant
        Layout.preferredWidth: 60
        horizontalAlignment: Text.AlignRight
      }

      RText {
        text: "Memory"
        pointSize: Style.fontSizeXS
        font.weight: Style.fontWeightBold
        color: Color.mOnSurfaceVariant
        Layout.preferredWidth: 70
        horizontalAlignment: Text.AlignRight
      }

      RText {
        text: "PID"
        pointSize: Style.fontSizeXS
        font.weight: Style.fontWeightBold
        color: Color.mOnSurfaceVariant
        Layout.preferredWidth: 50
        horizontalAlignment: Text.AlignRight
      }
    }
  }

  // Process list (simplified - top 15 by CPU)
  RBox {
    Layout.fillWidth: true
    Layout.fillHeight: true

    ListView {
      anchors.fill: parent
      anchors.margins: Style.marginS
      clip: true

      model: SysmonService.processes || []

      delegate: Item {
        width: parent.width
        height: 32

        RowLayout {
          anchors.fill: parent
          spacing: Style.marginXS

          RText {
            text: modelData.name || modelData.cmd?.[0] || ""
            pointSize: Style.fontSizeXS
            color: Color.mOnSurface
            font.family: Settings.data.ui.fontFixed
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            elide: Text.ElideRight
          }

          RText {
            text: (modelData.cpu_percent || 0).toFixed(1) + "%"
            pointSize: Style.fontSizeXS
            color: (modelData.cpu_percent || 0) > 80 ? Color.mError : ((modelData.cpu_percent || 0) > 50 ? Color.mTertiary : Color.mPrimary)
            font.family: Settings.data.ui.fontFixed
            Layout.preferredWidth: 60
            horizontalAlignment: Text.AlignRight
          }

          RText {
            text: SysmonService.formatMemory(modelData.mem_kb || 0)
            pointSize: Style.fontSizeXS
            color: Color.mOnSurface
            font.family: Settings.data.ui.fontFixed
            Layout.preferredWidth: 70
            horizontalAlignment: Text.AlignRight
          }

          RText {
            text: modelData.pid || ""
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
            Layout.preferredWidth: 50
            horizontalAlignment: Text.AlignRight
          }
        }
      }

      Rectangle {
        anchors.centerIn: parent
        visible: !SysmonService.processes || SysmonService.processes.length === 0

        RText {
          text: "No processes"
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
        }
      }
    }
  }
}
