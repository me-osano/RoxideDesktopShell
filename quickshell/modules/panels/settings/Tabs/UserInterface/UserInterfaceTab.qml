import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

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
      text: "Appearance"
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    RTabButton {
      text: "Panels"
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
    RTabButton {
      text: "Screen Corners"
      tabIndex: 2
      checked: subTabBar.currentIndex === 2
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  RTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    AppearanceSubTab {}
    PanelsSubTab {}
    ScreenCornersSubTab {}
  }
}
