import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Commons
import qs.Services.Power
import qs.Widgets

// Performance
RIconButtonHot {
  property ShellScreen screen

  readonly property bool hasPP: PowerProfileService.available

  enabled: hasPP
  icon: PowerProfileService.getIcon()
  hot: !PowerProfileService.isDefault()
  tooltipText: "Power Profile"
  onClicked: PowerProfileService.cycleProfile()
}
