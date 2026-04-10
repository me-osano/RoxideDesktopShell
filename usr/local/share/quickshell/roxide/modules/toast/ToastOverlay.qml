import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.common.theme
import qs.widgets

Variants {
  model: Quickshell.screens.filter(screen => (Settings.data.notifications.monitors.includes(screen.name) || (Settings.data.notifications.monitors.length === 0)))

  delegate: ToastScreen {
    required property ShellScreen modelData
    screen: modelData
  }
}
