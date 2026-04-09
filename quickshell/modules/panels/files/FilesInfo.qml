import QtQuick
import QtCore
import Quickshell.Io
import qs.common.theme
import qs.widgets

Rectangle {
    id: root

    property bool showFileInfo: false
    property int selectedIndex: -1
    property var sourceFolderModel: null
    property string currentPath: ""

    height: Math.round(200 * Style.uiScaleRatio)
    radius: Style.radiusS
    color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, 0.95)
    border.color: Color.mSecondary
    border.width: 2
    opacity: showFileInfo ? 1 : 0
    z: 100

    onShowFileInfoChanged: {
        if (showFileInfo && currentFileName && currentPath) {
            const fullPath = currentPath + "/" + currentFileName
            fileStatProcess.selectedFilePath = fullPath
            fileStatProcess.running = true
        }
    }

    Process {
        id: fileStatProcess
        command: ["stat", "-c", "%y|%A|%s|%n", selectedFilePath]
        property string selectedFilePath: ""
        property var fileStats: null
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    const parts = text.trim().split('|')
                    if (parts.length >= 4) {
                        fileStatProcess.fileStats = {
                            "modifiedTime": parts[0],
                            "permissions": parts[1],
                            "size": parseInt(parts[2]) || 0,
                            "fullPath": parts[3]
                        }
                    }
                }
            }
        }

        onExited: function (exitCode) {}
    }

    property string currentFileName: ""
    property bool currentFileIsDir: false
    property string currentFileExtension: ""

    onCurrentFileNameChanged: {
        if (showFileInfo && currentFileName && currentPath) {
            const fullPath = currentPath + "/" + currentFileName
            if (fullPath !== fileStatProcess.selectedFilePath) {
                fileStatProcess.selectedFilePath = fullPath
                fileStatProcess.running = true
            }
        }
    }

    function updateFileInfo(filePath, fileName, isDirectory) {
        if (filePath && filePath !== fileStatProcess.selectedFilePath) {
            fileStatProcess.selectedFilePath = filePath
            currentFileName = fileName || ""
            currentFileIsDir = isDirectory || false

            let ext = ""
            if (!isDirectory && fileName) {
                const lastDot = fileName.lastIndexOf('.')
                if (lastDot > 0) {
                    ext = fileName.substring(lastDot + 1).toLowerCase()
                }
            }
            currentFileExtension = ext

            if (showFileInfo) {
                fileStatProcess.running = true
            }
        }
    }

    readonly property var currentFileDisplayData: {
        if (selectedIndex < 0 || !sourceFolderModel) {
            return {
                "exists": false,
                "name": "No selection",
                "type": "",
                "size": "",
                "modified": "",
                "permissions": "",
                "extension": "",
                "position": "N/A"
            }
        }

        const hasValidFile = currentFileName !== ""
        return {
            "exists": hasValidFile,
            "name": hasValidFile ? currentFileName : "Loading...",
            "type": currentFileIsDir ? "Directory" : "File",
            "size": fileStatProcess.fileStats ? formatFileSize(fileStatProcess.fileStats.size) : "Calculating...",
            "modified": fileStatProcess.fileStats ? formatDateTime(fileStatProcess.fileStats.modifiedTime) : "Loading...",
            "permissions": fileStatProcess.fileStats ? fileStatProcess.fileStats.permissions : "Loading...",
            "extension": currentFileExtension,
            "position": sourceFolderModel ? ((selectedIndex + 1) + " of " + sourceFolderModel.count) : "N/A"
        }
    }

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.marginM
        spacing: Style.marginXXS

        Row {
            width: parent.width
            spacing: Style.marginS

            RIcon {
                name: "info"
                pointSize: Style.fontSizeM
                color: Color.mSecondary
            }

            RText {
                text: I18n.tr("File Information")
                pointSize: Style.fontSizeM
                color: Color.mOnSurface
                font.weight: Style.fontWeightMedium
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Column {
            width: parent.width
            spacing: Style.marginXXS

            RText {
                text: currentFileDisplayData.name
                pointSize: Style.fontSizeM
                color: Color.mOnSurface
                width: parent.width
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
                font.weight: Style.fontWeightMedium
            }

            RText {
                text: currentFileDisplayData.type + (currentFileDisplayData.extension ? " (." + currentFileDisplayData.extension + ")" : "")
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                width: parent.width
            }

            RText {
                text: currentFileDisplayData.size
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                width: parent.width
                visible: currentFileDisplayData.exists && !currentFileIsDir
            }

            RText {
                text: currentFileDisplayData.modified
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                width: parent.width
                elide: Text.ElideRight
                visible: currentFileDisplayData.exists
            }

            RText {
                text: currentFileDisplayData.permissions
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                visible: currentFileDisplayData.exists
            }

            RText {
                text: currentFileDisplayData.position
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                width: parent.width
            }
        }
    }

    RText {
        text: I18n.tr("F1/I: Toggle • F10: Help")
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.marginM
        horizontalAlignment: Text.AlignHCenter
    }

    function formatFileSize(bytes) {
        if (bytes === 0 || !bytes) {
            return "0 B"
        }
        const k = 1024
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
        const i = Math.floor(Math.log(bytes) / Math.log(k))
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
    }

    function formatDateTime(dateTimeString) {
        if (!dateTimeString) {
            return "Unknown"
        }
        const parts = dateTimeString.split(' ')
        if (parts.length >= 2) {
            return parts[0] + " " + parts[1].split('.')[0]
        }
        return dateTimeString
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.InOutQuad
        }
    }
}