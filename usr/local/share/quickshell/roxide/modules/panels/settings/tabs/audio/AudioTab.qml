import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common.theme
import qs.widgets

ColumnLayout {
  id: root
  spacing: 0

  RTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    RTabButton {
      text: "Volumes"
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    RTabButton {
      text: "Devices"
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
    RTabButton {
      text: "Media"
      tabIndex: 2
      checked: subTabBar.currentIndex === 2
    }
    RTabButton {
      text: "Visualizer"
      tabIndex: 3
      checked: subTabBar.currentIndex === 3
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  RTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    VolumesSubTab {}
    DevicesSubTab {}
    MediaSubTab {}
    VisualizerSubTab {}
  }
}
