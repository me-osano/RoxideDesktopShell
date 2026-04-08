import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../../common/helpers/QtObj2JS.js" as QtObj2JS
import "General"
import qs.common.theme
import qs.services
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
      text: "Basics"
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    RTabButton {
      text: "Keybinds"
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  RTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex
    BasicsSubTab {}
    KeybindsSubTab {}
  }
}
