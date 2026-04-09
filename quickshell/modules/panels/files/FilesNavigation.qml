import QtQuick
import qs.common.theme
import qs.widgets

RowLayout {
    id: navigation

    property string currentPath: ""
    property string homeDir: ""
    property bool backButtonFocused: false
    property bool keyboardNavigationActive: false
    property bool showSidebar: true
    property bool pathEditMode: false
    property bool pathInputHasFocus: false

    signal navigateUp()
    signal navigateTo(string path)
    signal pathInputFocusChanged(bool hasFocus)

    height: Math.round(40 * Style.uiScaleRatio)
    leftPadding: Style.marginM
    rightPadding: Style.marginM
    spacing: Style.marginS

    RBox {
        width: Math.round(32 * Style.uiScaleRatio)
        height: Math.round(32 * Style.uiScaleRatio)
        radius: Style.radiusS
        color: (backButtonMouseArea.containsMouse || (backButtonFocused && keyboardNavigationActive)) && currentPath !== homeDir ? Color.mSurfaceContainerHighest : Qt.colorTransparent
        opacity: currentPath !== homeDir ? 1 : 0

        RIcon {
            anchors.centerIn: parent
            name: "arrow_left"
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
        }

        MouseArea {
            id: backButtonMouseArea

            anchors.fill: parent
            hoverEnabled: currentPath !== homeDir
            cursorShape: currentPath !== homeDir ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: currentPath !== homeDir
            onClicked: navigation.navigateUp()
        }
    }

    Item {
        width: Math.max(0, (parent?.width ?? 0) - Math.round(40 * Style.uiScaleRatio) - Style.marginS - (showSidebar ? 0 : Math.round(80 * Style.uiScaleRatio)))
        height: Math.round(32 * Style.uiScaleRatio)

        RBox {
            anchors.fill: parent
            radius: Style.radiusS
            color: pathEditMode ? Color.mSurfaceContainerHighest : Qt.colorTransparent
            border.color: pathEditMode ? Color.mPrimary : Qt.colorTransparent
            border.width: pathEditMode ? 1 : 0
            visible: !pathEditMode

            RText {
                id: pathDisplay
                text: currentPath.replace("file://", "")
                pointSize: Style.fontSizeM
                color: Color.mOnSurface
                font.weight: Style.fontWeightMedium
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                anchors.rightMargin: Style.marginS
                elide: Text.ElideMiddle
                verticalAlignment: Text.AlignVCenter
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    pathEditMode = true
                    pathInput.text = currentPath.replace("file://", "")
                    Qt.callLater(() => pathInput.forceActiveFocus())
                }
            }
        }

        RTextInput {
            id: pathInput
            anchors.fill: parent
            visible: pathEditMode
            topPadding: Style.marginXXS
            bottomPadding: Style.marginXXS
            onAccepted: {
                const newPath = text.trim()
                if (newPath !== "") {
                    navigation.navigateTo(newPath)
                }
                pathEditMode = false
            }
            Keys.onEscapePressed: {
                pathEditMode = false
            }
            Keys.onDownPressed: {
                pathEditMode = false
            }
            onActiveFocusChanged: {
                navigation.pathInputFocusChanged(activeFocus)
                if (!activeFocus && pathEditMode) {
                    pathEditMode = false
                }
            }
        }
    }

    Row {
        spacing: Style.marginXXS
        visible: !showSidebar
        anchors.verticalCenter: parent.verticalCenter

        RIconButton {
            icon: "sort"
            tooltipText: "Sort"
            baseSize: Style.baseWidgetSize * 0.7
        }
    }
}