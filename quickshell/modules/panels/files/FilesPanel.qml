import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common.theme
import qs.modules.mainScreen
import qs.services
import qs.widgets

SmartPanel {
  id: root

  panelContent: Item {
    id: panelContent
    anchors.fill: parent

    property real contentPreferredWidth: Math.round(800 * Style.uiScaleRatio)
    property real contentPreferredHeight: Math.round(600 * Style.uiScaleRatio)

    FilesContent {
      anchors.fill: parent
    }
  }
}