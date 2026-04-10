import QtQuick
import QtQuick.Layouts
import qs.common.theme
import qs.widgets

RBox {
    id: listDelegateRoot

    required property bool fileIsDir
    required property string filePath
    required property string fileName
    required property int index
    required property var fileModified
    required property int fileSize

    property int selectedIndex: -1
    property bool keyboardNavigationActive: false

    signal itemClicked(int index, string path, string name, bool isDir)
    signal itemSelected(int index, string path, string name, bool isDir)

    function getFileExtension(fileName) {
        const parts = fileName.split('.');
        if (parts.length > 1) {
            return parts[parts.length - 1].toLowerCase();
        }
        return "";
    }

    function determineFileType(fileName) {
        const ext = getFileExtension(fileName);

        const imageExts = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "svg", "ico", "jxl", "avif", "heif", "exr"];
        if (imageExts.includes(ext)) {
            return "image";
        }

        const videoExts = ["mp4", "mkv", "avi", "mov", "webm", "flv", "wmv", "m4v"];
        if (videoExts.includes(ext)) {
            return "video";
        }

        const audioExts = ["mp3", "wav", "flac", "ogg", "m4a", "aac", "wma"];
        if (audioExts.includes(ext)) {
            return "audio";
        }

        const codeExts = ["js", "ts", "jsx", "tsx", "py", "go", "rs", "c", "cpp", "h", "java", "kt", "swift", "rb", "php", "html", "css", "scss", "json", "xml", "yaml", "yml", "toml", "sh", "bash", "zsh", "fish", "qml", "vue", "svelte"];
        if (codeExts.includes(ext)) {
            return "code";
        }

        const docExts = ["txt", "md", "pdf", "doc", "docx", "odt", "rtf"];
        if (docExts.includes(ext)) {
            return "document";
        }

        const archiveExts = ["zip", "tar", "gz", "bz2", "xz", "7z", "rar"];
        if (archiveExts.includes(ext)) {
            return "archive";
        }

        if (!ext || fileName.indexOf('.') === -1) {
            return "binary";
        }

        return "file";
    }

    function isImageFile(fileName) {
        if (!fileName) {
            return false;
        }
        return determineFileType(fileName) === "image";
    }

    function isVideoFile(fileName) {
        if (!fileName) {
            return false;
        }
        return determineFileType(fileName) === "video";
    }

    property bool isImage: isImageFile(listDelegateRoot.fileName)
    property bool isVideo: isVideoFile(listDelegateRoot.fileName)

    property string _xdgCacheHome: Paths.strip(Paths.xdgCache)
    property string videoThumbnailPath: {
        if (!listDelegateRoot.fileIsDir && isVideo) {
            const hash = Qt.md5("file://" + listDelegateRoot.filePath);
            return _xdgCacheHome + "/thumbnails/normal/" + hash + ".png";
        }
        return "";
    }

    property string _videoThumb: ""

    onVideoThumbnailPathChanged: {
        _videoThumb = "";
        if (!videoThumbnailPath)
            return;
        const thumbPath = videoThumbnailPath;
        const fp = listDelegateRoot.filePath;
        Paths.mkdir(_xdgCacheHome + "/thumbnails/normal");
        Proc.runCommand(null, ["test", "-f", thumbPath], function(output, exitCode) {
            if (exitCode === 0) {
                _videoThumb = thumbPath;
            } else {
                Proc.runCommand(null, ["ffmpegthumbnailer", "-i", fp, "-o", thumbPath, "-s", "128", "-f"], function(output, exitCode) {
                    if (exitCode === 0)
                        _videoThumb = thumbPath;
                });
            }
        });
    }

    function getIconForFile(fileName) {
        const lowerName = fileName.toLowerCase();
        if (lowerName.startsWith("dockerfile")) {
            return "docker";
        }
        const ext = fileName.split('.').pop();
        return ext || "";
    }

    function formatFileSize(size) {
        if (size < 1024)
            return size + " B";
        if (size < 1024 * 1024)
            return (size / 1024).toFixed(1) + " KB";
        if (size < 1024 * 1024 * 1024)
            return (size / (1024 * 1024)).toFixed(1) + " MB";
        return (size / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    height: Math.round(44 * Style.uiScaleRatio)
    radius: Style.radiusS
    color: {
        if (keyboardNavigationActive && listDelegateRoot.index === selectedIndex)
            return Color.mSurfaceContainerHigh;
        return listMouseArea.containsMouse ? Color.mSurfaceContainerHighest : Qt.colorTransparent;
    }
    border.color: keyboardNavigationActive && listDelegateRoot.index === selectedIndex ? Color.mPrimary : Qt.colorTransparent
    border.width: (keyboardNavigationActive && listDelegateRoot.index === selectedIndex) ? 2 : 0

    Component.onCompleted: {
        if (keyboardNavigationActive && listDelegateRoot.index === selectedIndex)
            itemSelected(listDelegateRoot.index, listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir);
    }

    onSelectedIndexChanged: {
        if (keyboardNavigationActive && selectedIndex === listDelegateRoot.index)
            itemSelected(listDelegateRoot.index, listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir);
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.marginS
        anchors.rightMargin: Style.marginS
        spacing: Style.marginS

        Item {
            width: Math.round(28 * Style.uiScaleRatio)
            height: Math.round(28 * Style.uiScaleRatio)

            Image {
                id: listPreviewImage
                anchors.fill: parent
                property string imagePath: {
                    if (!listDelegateRoot.fileIsDir && isImage)
                        return listDelegateRoot.filePath;
                    if (_videoThumb)
                        return _videoThumb;
                    return "";
                }
                source: imagePath ? "file://" + imagePath.split('/').map(s => encodeURIComponent(s)).join('/') : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Math.round(32 * Style.uiScaleRatio)
                sourceSize.height: Math.round(32 * Style.uiScaleRatio)
                asynchronous: true
                visible: false
            }

            RImageRounded {
                anchors.fill: parent
                imagePath: listPreviewImage.status === Image.Ready && !listDelegateRoot.fileIsDir && (isImage || isVideo) ? listPreviewImage.source : ""
                radius: Style.radiusS
            }

            RIcon {
                anchors.centerIn: parent
                icon: listDelegateRoot.fileIsDir ? "folder" : getIconForFile(listDelegateRoot.fileName)
                pointSize: Style.fontSizeM
                color: listDelegateRoot.fileIsDir ? Color.mPrimary : Color.mOnSurface
                visible: listDelegateRoot.fileIsDir || (!isImage && !(isVideo && listPreviewImage.status === Image.Ready))
            }
        }

        RText {
            text: listDelegateRoot.fileName || ""
            pointSize: Style.fontSizeM
            color: Color.mOnSurface
            width: parent.width - Math.round(280 * Style.uiScaleRatio)
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: 1
            clip: true
        }

        RText {
            text: listDelegateRoot.fileIsDir ? "" : formatFileSize(listDelegateRoot.fileSize)
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            width: Math.round(70 * Style.uiScaleRatio)
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }

        RText {
            text: Qt.formatDateTime(listDelegateRoot.fileModified, "MMM d, yyyy h:mm AP")
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            width: Math.round(140 * Style.uiScaleRatio)
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        id: listMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            itemClicked(listDelegateRoot.index, listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir);
        }
    }
}