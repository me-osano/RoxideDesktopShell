import QtQuick
import qs.common.theme
import qs.widgets

Rectangle {
    id: root

    property bool showHints: false

    height: Math.round(80 * Style.uiScaleRatio)
    radius: Style.radiusS
    color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, 0.95)
    border.color: Color.mPrimary
    border.width: 2
    opacity: showHints ? 1 : 0
    z: 100

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.marginS
        spacing: 2

        RText {
            text: I18n.tr("Tab/Shift+Tab: Nav • ←→↑↓: Grid Nav • Enter/Space: Select")
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        RText {
            text: I18n.tr("Alt+←/Backspace: Back • F1/I: File Info • F10: Help • Esc: Close")
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.InOutQuad
        }
    }
}