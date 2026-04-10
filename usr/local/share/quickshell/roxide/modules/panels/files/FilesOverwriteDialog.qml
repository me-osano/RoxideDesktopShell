import QtQuick
import qs.common.theme
import qs.widgets

Item {
    id: overwriteDialog

    property bool showDialog: false
    property string pendingFilePath: ""

    signal confirmed(string filePath)
    signal cancelled()

    visible: showDialog
    focus: showDialog

    Keys.onEscapePressed: {
        cancelled()
    }

    Keys.onReturnPressed: {
        confirmed(pendingFilePath)
    }

    Rectangle {
        anchors.fill: parent
        color: Color.mShadow
        opacity: 0.8

        MouseArea {
            anchors.fill: parent
            onClicked: {
                cancelled()
            }
        }
    }

    RBox {
        anchors.centerIn: parent
        width: Math.round(400 * Style.uiScaleRatio)
        height: Math.round(160 * Style.uiScaleRatio)
        color: Color.mSurfaceContainer
        radius: Style.radiusS
        border.color: Color.mOutlineVariant
        border.width: 1

        Column {
            anchors.centerIn: parent
            width: parent.width - Style.marginL * 2
            spacing: Style.marginM

            RText {
                text: I18n.tr("File Already Exists")
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightMedium
                color: Color.mOnSurface
                anchors.horizontalCenter: parent.horizontalCenter
            }

            RText {
                text: I18n.tr("A file with this name already exists. Do you want to overwrite it?")
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.marginM

                RBox {
                    width: Math.round(80 * Style.uiScaleRatio)
                    height: Math.round(36 * Style.uiScaleRatio)
                    radius: Style.radiusS
                    color: cancelArea.containsMouse ? Color.mSurfaceContainerHighest : Color.mSurfaceContainerHighest
                    border.color: Color.mOutline
                    border.width: 1

                    RText {
                        anchors.centerIn: parent
                        text: I18n.tr("Cancel")
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurface
                        font.weight: Style.fontWeightMedium
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cancelled()
                        }
                    }
                }

                RBox {
                    width: Math.round(90 * Style.uiScaleRatio)
                    height: Math.round(36 * Style.uiScaleRatio)
                    radius: Style.radiusS
                    color: overwriteArea.containsMouse ? Qt.darker(Color.mPrimary, 1.1) : Color.mPrimary

                    RText {
                        anchors.centerIn: parent
                        text: I18n.tr("Overwrite")
                        pointSize: Style.fontSizeM
                        color: Color.mOnPrimary
                        font.weight: Style.fontWeightMedium
                    }

                    MouseArea {
                        id: overwriteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            confirmed(pendingFilePath)
                        }
                    }
                }
            }
        }
    }
}