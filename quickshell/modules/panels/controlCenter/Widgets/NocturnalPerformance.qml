import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Power
import qs.Widgets

RIconButtonHot {
  property ShellScreen screen

  icon: PowerProfileService.nocturnalPerformanceMode ? "rocket" : "rocket-off"
  tooltipText: "Nocturnal Performance Mode"
  hot: PowerProfileService.nocturnalPerformanceMode
  onClicked: PowerProfileService.toggleNocturnalPerformance()
}
