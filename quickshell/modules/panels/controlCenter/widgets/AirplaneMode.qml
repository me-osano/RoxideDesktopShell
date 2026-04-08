import QtQuick.Layouts
import Quickshell
import qs.common.theme
import qs.services
import qs.widgets

RIconButtonHot {
  property ShellScreen screen

  icon: !Settings.data.network.airplaneModeEnabled ? "plane-off" : "plane"
  hot: Settings.data.network.airplaneModeEnabled
  tooltipText: "Airplane Mode"
  onClicked: {
    BluetoothService.setAirplaneMode(!Settings.data.network.airplaneModeEnabled);
  }
}
