import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

RIconButtonHot {
  property ShellScreen screen

  icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
  hot: NotificationService.doNotDisturb
  tooltipText: "Notifications"
  onClicked: {
    NotificationService.updateLastSeenTs();
    PanelService.getPanel("controlCenterPanel", screen)?.open();
  }
  onRightClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
}
