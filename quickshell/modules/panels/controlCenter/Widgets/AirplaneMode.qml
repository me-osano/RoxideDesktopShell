import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

RIconButtonHot {
  property ShellScreen screen

  icon: !Settings.data.network.airplaneModeEnabled ? "plane-off" : "plane"
  hot: Settings.data.network.airplaneModeEnabled
  tooltipText: "Airplane Mode"
  onClicked: {
    BluetoothService.setAirplaneMode(!Settings.data.network.airplaneModeEnabled);
  }
}
