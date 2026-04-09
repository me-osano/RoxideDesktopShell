import QtQuick
import qs.common.theme
import qs.widgets

RBox {
    id: sortMenu

    property string sortBy: "name"
    property bool sortAscending: true

    signal sortBySelected(string value)
    signal sortOrderSelected(bool ascending)

    width: Math.round(200 * Style.uiScaleRatio)
    height: sortColumn.height + Style.marginM * 2
    color: Color.mSurfaceContainer
    radius: Style.radiusS
    border.color: Color.mOutlineVariant
    border.width: 1
    visible: false
    z: 100

    Column {
        id: sortColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.marginM
        spacing: Style.marginXXS

        RText {
            text: "Sort By"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            font.weight: Style.fontWeightMedium
        }

        Repeater {
            model: [{
                    "name": "Name",
                    "value": "name"
                }, {
                    "name": "Size",
                    "value": "size"
                }, {
                    "name": "Modified",
                    "value": "modified"
                }, {
                    "name": "Type",
                    "value": "type"
                }]

            RBox {
                width: sortColumn?.width ?? 0
                height: Math.round(32 * Style.uiScaleRatio)
                radius: Style.radiusS
                color: sortMouseArea.containsMouse ? Color.mSurfaceContainerHighest : (sortBy === modelData?.value ? Color.mSurfaceContainerHigh : Qt.colorTransparent)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.marginS
                    spacing: Style.marginS

                    RIcon {
                        name: sortBy === modelData?.value ? "check" : ""
                        pointSize: Style.fontSizeS
                        color: Color.mPrimary
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sortBy === modelData?.value
                    }

                    RText {
                        text: modelData?.name ?? ""
                        pointSize: Style.fontSizeM
                        color: sortBy === modelData?.value ? Color.mPrimary : Color.mOnSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: sortMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sortMenu.sortBySelected(modelData?.value ?? "name")
                        sortMenu.visible = false
                    }
                }
            }
        }

        RBox {
            width: sortColumn.width
            height: 1
            color: Color.mOutline
        }

        RText {
            text: "Order"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            font.weight: Style.fontWeightMedium
            topPadding: Style.marginXXS
        }

        RBox {
            width: sortColumn?.width ?? 0
            height: Math.round(32 * Style.uiScaleRatio)
            radius: Style.radiusS
            color: ascMouseArea.containsMouse ? Color.mSurfaceContainerHighest : (sortAscending ? Color.mSurfaceContainerHigh : Qt.colorTransparent)

            Row {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                spacing: Style.marginS

                RIcon {
                    name: "arrow_up"
                    pointSize: Style.fontSizeS
                    color: sortAscending ? Color.mPrimary : Color.mOnSurface
                    anchors.verticalCenter: parent.verticalCenter
                }

                RText {
                    text: "Ascending"
                    pointSize: Style.fontSizeM
                    color: sortAscending ? Color.mPrimary : Color.mOnSurface
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: ascMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sortMenu.sortOrderSelected(true)
                    sortMenu.visible = false
                }
            }
        }

        RBox {
            width: sortColumn?.width ?? 0
            height: Math.round(32 * Style.uiScaleRatio)
            radius: Style.radiusS
            color: descMouseArea.containsMouse ? Color.mSurfaceContainerHighest : (!sortAscending ? Color.mSurfaceContainerHigh : Qt.colorTransparent)

            Row {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                spacing: Style.marginS

                RIcon {
                    name: "arrow_down"
                    pointSize: Style.fontSizeS
                    color: !sortAscending ? Color.mPrimary : Color.mOnSurface
                    anchors.verticalCenter: parent.verticalCenter
                }

                RText {
                    text: "Descending"
                    pointSize: Style.fontSizeM
                    color: !sortAscending ? Color.mPrimary : Color.mOnSurface
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: descMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sortMenu.sortOrderSelected(false)
                    sortMenu.visible = false
                }
            }
        }
    }
}