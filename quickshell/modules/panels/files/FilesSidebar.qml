import QtQuick
import qs.common.theme
import qs.widgets

RBox {
    id: sidebar

    property var quickAccessLocations: []
    property string currentPath: ""
    signal locationSelected(string path)

    width: Math.round(200 * Style.uiScaleRatio)
    color: Color.mSurfaceContainer

    Column {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: 4

        RText {
            text: I18n.tr("Quick Access")
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            font.weight: Style.fontWeightMedium
            leftPadding: Style.marginS
            bottomPadding: Style.marginXXS
        }

        Repeater {
            model: quickAccessLocations

            RBox {
                width: parent?.width ?? 0
                height: Math.round(38 * Style.uiScaleRatio)
                radius: Style.radiusS
                color: quickAccessMouseArea.containsMouse ? Qt.colorTransparent : (currentPath === modelData?.path ? Color.mSurfaceContainerHigh : Qt.colorTransparent)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.marginM
                    spacing: Style.marginS

                    RIcon {
                        icon: modelData?.icon ?? ""
                        pointSize: Style.fontSizeM
                        color: currentPath === modelData?.path ? Color.mPrimary : Color.mOnSurface
                    }

                    RText {
                        text: modelData?.name ?? ""
                        pointSize: Style.fontSizeM
                        color: currentPath === modelData?.path ? Color.mPrimary : Color.mOnSurface
                        font.weight: currentPath === modelData?.path ? Style.fontWeightMedium : Style.fontWeightRegular
                    }
                }

                MouseArea {
                    id: quickAccessMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: locationSelected(modelData?.path ?? "")
                }
            }
        }
    }
}