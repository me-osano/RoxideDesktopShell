import QtQuick
import qs.common.theme
import qs.widgets

Item {
    id: filesPanel
    width: Math.round(800 * Style.uiScaleRatio)
    height: Math.round(600 * Style.uiScaleRatio)

    FilesContent {
        anchors.fill: parent
    }
}