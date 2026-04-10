import QtQuick
import QtQuick.Layouts
import qs.common.theme
import qs.widgets

RowLayout {
    id: saveRow

    property bool saveMode: false
    property string defaultFileName: ""
    property string currentPath: ""

    signal saveRequested(string filePath)

    height: saveMode ? Math.round(40 * Style.uiScaleRatio) : 0
    visible: saveMode
    spacing: Style.marginM

    RTextInput {
        id: fileNameInput

        Layout.fillWidth: true
        height: Math.round(40 * Style.uiScaleRatio)
        text: defaultFileName
        placeholderText: I18n.tr("Enter filename...")
        focus: saveMode
        Component.onCompleted: {
            if (saveMode)
                Qt.callLater(() => {
                                 forceActiveFocus()
                             })
        }
        onAccepted: {
            if (text.trim() !== "") {
                var basePath = currentPath.replace(/^file:\/\//, '')
                var fullPath = basePath + "/" + text.trim()
                fullPath = fullPath.replace(/\/+/g, '/')
                saveRequested(fullPath)
            }
        }
    }

    RBox {
        id: saveButton

        width: Math.round(80 * Style.uiScaleRatio)
        height: Math.round(40 * Style.uiScaleRatio)
        color: fileNameInput.text.trim() !== "" ? Color.mPrimary : Color.mSurfaceContainerHighest
        radius: Style.radiusS

        RText {
            anchors.centerIn: parent
            text: I18n.tr("Save")
            color: fileNameInput.text.trim() !== "" ? Color.mOnPrimary : Color.mOnSurfaceVariant
            pointSize: Style.fontSizeM
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (fileNameInput.text.trim() !== "") {
                    var basePath = currentPath.replace(/^file:\/\//, '')
                    var fullPath = basePath + "/" + fileNameInput.text.trim()
                    fullPath = fullPath.replace(/\/+/g, '/')
                    saveRequested(fullPath)
                }
            }
        }
    }
}