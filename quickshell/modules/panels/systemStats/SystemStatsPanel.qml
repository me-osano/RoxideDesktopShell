import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io           // For Process & FileView
import qs.modules.mainScreen
import qs.common.theme
import qs.services
import qs.widgets
import "views"

SmartPanel {
  id: root

  Component.onCompleted: SystemStatService.registerComponent("panel-systemstats")
  Component.onDestruction: SystemStatService.unregisterComponent("panel-systemstats")

  preferredWidth: Math.round(440 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent
    property real contentPreferredHeight: mainColumn.implicitHeight + Style.margin2L
    readonly property real cardHeight: 90 * Style.uiScaleRatio

    readonly property string diskPath: {
      const sysMonWidget = BarService.lookupWidget("SystemMonitor");
      if (sysMonWidget && sysMonWidget.diskPath) {
        return sysMonWidget.diskPath;
      }
      return "/";
    }

    property int currentTab: 0

    // Kernel and architecture info
    readonly property string kernelText: {
        const parts = procVersionText.split(" ");
        if (parts.length >= 3) {
            return parts[2];
        }
        return procVersionText;
    }
    readonly property string archText: {
        if (SysmonService.cpuModel && SystemStatService.nproc > 0) {
            const arch = SysmonService.cpuModel.includes("ARM") ? "aarch64" : "x86_64";
            return arch;
        }
        return "--";
    }

    // FileView for kernel version
    FileView {
        id: procVersionFile
        path: "/proc/version"
        printErrors: false
        onLoaded: {
            procVersionText = text().trim();
        }
    }
    property string procVersionText: ""

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

          RIconButton {
            icon: "close"
            tooltipText: "Close"
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              root.close();
            }
          }
        }
      }

      // TAB BAR
      RBox {
        Layout.fillWidth: true
        implicitHeight: tabRow.implicitHeight + Style.marginS

        RowLayout {
          id: tabRow
          anchors.fill: parent
          anchors.margins: Style.marginS
          spacing: Style.marginXS

          TabButton {
            text: "Performance"
            checked: panelContent.currentTab === 0
            onCheckedChanged: if (checked) panelContent.currentTab = 0
            Layout.fillWidth: true
          }

          TabButton {
            text: "Processes"
            checked: panelContent.currentTab === 1
            onCheckedChanged: if (checked) panelContent.currentTab = 1
            Layout.fillWidth: true
          }

          TabButton {
            text: "System"
            checked: panelContent.currentTab === 2
            onCheckedChanged: if (checked) panelContent.currentTab = 2
            Layout.fillWidth: true
          }

          TabButton {
            text: "Disks"
            checked: panelContent.currentTab === 3
            onCheckedChanged: if (checked) panelContent.currentTab = 3
            Layout.fillWidth: true
          }
        }
      }

      // TAB CONTENT
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        PerformanceView {
            anchors.fill: parent
            visible: panelContent.currentTab === 0
        }

        ProcessesView {
            anchors.fill: parent
            visible: panelContent.currentTab === 1
        }

        SystemView {
            anchors.fill: parent
            visible: panelContent.currentTab === 2
        }

        DisksView {
            anchors.fill: parent
            visible: panelContent.currentTab === 3
        }
      }
    }
  }
}
