import QtQuick
import qs.common.theme
import qs.widgets

RBox {
    id: delegateRoot

    required property bool fileIsDir
    required property string filePath
    required property string fileName
    required property int index

    property bool weMode: false
    property var iconSizes: [80, 120, 160, 200]
    property int iconSizeIndex: 1
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

    property bool isImage: isImageFile(delegateRoot.fileName)
    property bool isVideo: isVideoFile(delegateRoot.fileName)

    property string _xdgCacheHome: Paths.strip(Paths.xdgCache)
    property string _thumbnailSize: iconSizeIndex >= 2 ? "x-large" : "large"
    property int _thumbnailPx: iconSizeIndex >= 2 ? 512 : 256
    property string videoThumbnailPath: {
        if (!delegateRoot.fileIsDir && isVideo) {
            const hash = Qt.md5("file://" + delegateRoot.filePath);
            return _xdgCacheHome + "/thumbnails/" + _thumbnailSize + "/" + hash + ".png";
        }
        return "";
    }

    property string _videoThumb: ""

    onVideoThumbnailPathChanged: {
        _videoThumb = "";
        if (!videoThumbnailPath)
            return;
        const thumbPath = videoThumbnailPath;
        const thumbDir = _xdgCacheHome + "/thumbnails/" + _thumbnailSize;
        const size = _thumbnailPx;
        const fp = delegateRoot.filePath;
        Paths.mkdir(thumbDir);
        Proc.runCommand(null, ["test", "-f", thumbPath], function(output, exitCode) {
            if (exitCode === 0) {
                _videoThumb = thumbPath;
            } else {
                Proc.runCommand(null, ["ffmpegthumbnailer", "-i", fp, "-o", thumbPath, "-s", String(size), "-f"], function(output, exitCode) {
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

    width: weMode ? Math.round(245 * Style.uiScaleRatio) : iconSizes[iconSizeIndex] + 16
    height: weMode ? Math.round(205 * Style.uiScaleRatio) : iconSizes[iconSizeIndex] + 48
    radius: Style.radiusS
    color: {
        if (keyboardNavigationActive && delegateRoot.index === selectedIndex)
            return Color.mSurfaceContainerHigh;

        return mouseArea.containsMouse ? Color.mSurfaceContainerHighest : Qt.colorTransparent;
    }
    border.color: keyboardNavigationActive && delegateRoot.index === selectedIndex ? Color.mPrimary : Qt.colorTransparent
    border.width: (keyboardNavigationActive && delegateRoot.index === selectedIndex) ? 2 : 0

    Component.onCompleted: {
        if (keyboardNavigationActive && delegateRoot.index === selectedIndex)
            itemSelected(delegateRoot.index, delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir);
    }

    onSelectedIndexChanged: {
        if (keyboardNavigationActive && selectedIndex === delegateRoot.index)
            itemSelected(delegateRoot.index, delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir);
    }

    Column {
        anchors.centerIn: parent
        spacing: Style.marginS

        Item {
            width: weMode ? Math.round(225 * Style.uiScaleRatio) : (iconSizes[iconSizeIndex] - 8)
            height: weMode ? Math.round(165 * Style.uiScaleRatio) : (iconSizes[iconSizeIndex] - 8)
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                id: gridPreviewImage
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                property var weExtensions: [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tga", ".jxl", ".avif", ".heif", ".exr"]
                property int weExtIndex: 0
                property string imagePath: {
                    if (weMode && delegateRoot.fileIsDir)
                        return delegateRoot.filePath + "/preview" + weExtensions[weExtIndex];
                    if (!delegateRoot.fileIsDir && isImage)
                        return delegateRoot.filePath;
                    if (_videoThumb)
                        return _videoThumb;
                    return "";
                }
                source: imagePath ? "file://" + imagePath.split('/').map(s => encodeURIComponent(s)).join('/') : ""
                onStatusChanged: {
                    if (weMode && delegateRoot.fileIsDir && status === Image.Error) {
                        if (weExtIndex < weExtensions.length - 1) {
                            weExtIndex++;
                        } else {
                            imagePath = "";
                        }
                    }
                }
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: weMode ? Math.round(225 * Style.uiScaleRatio) : iconSizes[iconSizeIndex]
                sourceSize.height: weMode ? Math.round(225 * Style.uiScaleRatio) : iconSizes[iconSizeIndex]
                asynchronous: true
                visible: false
            }

            RImageRounded {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                imagePath: gridPreviewImage.status === Image.Ready && ((!delegateRoot.fileIsDir && (isImage || isVideo)) || (weMode && delegateRoot.fileIsDir)) ? gridPreviewImage.source : ""
                radius: Style.radiusS
            }

            RIcon {
                anchors.centerIn: parent
                icon: delegateRoot.fileIsDir ? "folder" : getIconForFile(delegateRoot.fileName)
                pointSize: iconSizes[iconSizeIndex] * 0.45
                color: delegateRoot.fileIsDir ? Color.mPrimary : Color.mOnSurface
                visible: (!delegateRoot.fileIsDir && !isImage && !(isVideo && gridPreviewImage.status === Image.Ready)) || (delegateRoot.fileIsDir && !weMode)
            }
        }

        RText {
            text: delegateRoot.fileName || ""
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            width: delegateRoot.width - Style.marginM
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            itemClicked(delegateRoot.index, delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir);
        }
    }
}