import QtQuick.Layouts
import Quickshell
import qs.common.theme
import qs.services
import qs.widgets

RIconButtonHot {
  property ShellScreen screen

  enabled: Settings.data.wallpaper.enabled
  icon: "wallpaper-selector"
  tooltipText: "Wallpaper Selector"
  onClicked: PanelService.getPanel("wallpaperPanel", screen)?.toggle()
  onRightClicked: WallpaperService.setRandomWallpaper()
}
