import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.common.theme
import qs.services
import qs.widgets

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
