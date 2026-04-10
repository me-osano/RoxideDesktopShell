import QtQuick.Layouts
import Quickshell
import qs.common.theme
import qs.services
import qs.widgets

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
