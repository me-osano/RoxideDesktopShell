import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Power
import qs.Widgets

RIconButtonHot {
  property ShellScreen screen

  icon: "dark-mode"
  tooltipText: Settings.data.colorSchemes.darkMode ? "Light Mode" : "Dark Mode"
  onClicked: Settings.data.colorSchemes.darkMode = !Settings.data.colorSchemes.darkMode
}
