import QtQuick.Layouts
import Quickshell
import qs.common.theme
import qs.services
import qs.widgets

RIconButtonHot {
  property ShellScreen screen

  icon: "dark-mode"
  tooltipText: Settings.data.colorSchemes.darkMode ? "Light Mode" : "Dark Mode"
  onClicked: Settings.data.colorSchemes.darkMode = !Settings.data.colorSchemes.darkMode
}
