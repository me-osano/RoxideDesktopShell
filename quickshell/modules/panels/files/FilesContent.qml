import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel

import qs.common.theme
import qs.services
import qs.widgets

FocusScope {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    property string docsDir: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
    property string musicDir: StandardPaths.writableLocation(StandardPaths.MusicLocation)
    property string videosDir: StandardPaths.writableLocation(StandardPaths.MoviesLocation)
    property string picsDir: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    property string downloadDir: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
    property string desktopDir: StandardPaths.writableLocation(StandardPaths.DesktopLocation)
    property string currentPath: ""
    property var fileExtensions: ["*.*"]
    property alias filterExtensions: root.fileExtensions
    property string browserTitle: "Select File"
    property string browserIcon: "folder_open"
    property string browserType: "generic"
    property bool showHiddenFiles: false
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property bool backButtonFocused: false
    property bool saveMode: false
    property string defaultFileName: ""
    property int keyboardSelectionIndex: -1
    property bool keyboardSelectionRequested: false
    property bool showKeyboardHints: false
    property bool showFileInfo: false
    property string selectedFilePath: ""
    property string selectedFileName: ""
    property bool selectedFileIsDir: false
    property bool showOverwriteConfirmation: false
    property string pendingFilePath: ""
    property bool showSidebar: true
    property string viewMode: "grid"
    property string sortBy: "name"
    property bool sortAscending: true
    property int iconSizeIndex: 1
    property var iconSizes: [80, 120, 160, 200]
    property bool pathEditMode: false
    property bool pathInputHasFocus: false
    property int actualGridColumns: 5
    property bool _initialized: false
    property bool closeOnEscape: true

    signal fileSelected(string path)
    signal closeRequested

    function encodeFileUrl(path) {
        if (!path)
            return "";
        return "file://" + path.split('/').map(s => encodeURIComponent(s)).join('/');
    }

    function initialize() {
        loadSettings();
        currentPath = getLastPath();
        _initialized = true;
    }

    function reset() {
        currentPath = getLastPath();
        selectedIndex = -1;
        keyboardNavigationActive = false;
        backButtonFocused = false;
    }

    function loadSettings() {
        const type = browserType || "default";
        const settings = CacheData.fileBrowserSettings[type];
        const isImageBrowser = ["wallpaper", "profile"].includes(browserType);

        if (settings) {
            viewMode = settings.viewMode || (isImageBrowser ? "grid" : "list");
            sortBy = settings.sortBy || "name";
            sortAscending = settings.sortAscending !== undefined ? settings.sortAscending : true;
            iconSizeIndex = settings.iconSizeIndex !== undefined ? settings.iconSizeIndex : 1;
            showSidebar = settings.showSidebar !== undefined ? settings.showSidebar : true;
        } else {
            viewMode = isImageBrowser ? "grid" : "list";
        }
    }

    function saveSettings() {
        if (!_initialized)
            return;
        const type = browserType || "default";
        let settings = CacheData.fileBrowserSettings;
        if (!settings[type]) {
            settings[type] = {};
        }
        settings[type].viewMode = viewMode;
        settings[type].sortBy = sortBy;
        settings[type].sortAscending = sortAscending;
        settings[type].iconSizeIndex = iconSizeIndex;
        settings[type].showSidebar = showSidebar;
        settings[type].lastPath = currentPath;
        CacheData.fileBrowserSettings = settings;

        if (browserType === "wallpaper") {
            CacheData.wallpaperLastPath = currentPath;
        } else if (browserType === "profile") {
            CacheData.profileLastPath = currentPath;
        }

        CacheData.saveCache();
    }

    onViewModeChanged: saveSettings()
    onSortByChanged: saveSettings()
    onSortAscendingChanged: saveSettings()
    onIconSizeIndexChanged: saveSettings()
    onShowSidebarChanged: saveSettings()

    function isImageFile(fileName) {
        if (!fileName)
            return false;
        const ext = fileName.toLowerCase().split('.').pop();
        return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext);
    }

    function getLastPath() {
        const type = browserType || "default";
        const settings = CacheData.fileBrowserSettings[type];
        const lastPath = settings?.lastPath || "";
        return (lastPath && lastPath !== "") ? lastPath : homeDir;
    }

    function saveLastPath(path) {
        const type = browserType || "default";
        let settings = CacheData.fileBrowserSettings;
        if (!settings[type]) {
            settings[type] = {};
        }
        settings[type].lastPath = path;
        CacheData.fileBrowserSettings = settings;
        CacheData.saveCache();

        if (browserType === "wallpaper") {
            CacheData.wallpaperLastPath = path;
        } else if (browserType === "profile") {
            CacheData.profileLastPath = path;
        }
    }

    function setSelectedFileData(path, name, isDir) {
        selectedFilePath = path;
        selectedFileName = name;
        selectedFileIsDir = isDir;
    }

    function navigateUp() {
        const path = currentPath;
        if (path === homeDir)
            return;
        const lastSlash = path.lastIndexOf('/');
        if (lastSlash <= 0)
            return;
        const newPath = path.substring(0, lastSlash);
        if (newPath.length < homeDir.length) {
            currentPath = homeDir;
            saveLastPath(homeDir);
        } else {
            currentPath = newPath;
            saveLastPath(newPath);
        }
    }

    function navigateTo(path) {
        currentPath = path;
        saveLastPath(path);
        selectedIndex = -1;
        backButtonFocused = false;
    }

    function keyboardFileSelection(index) {
        if (index < 0)
            return;
        keyboardSelectionTimer.targetIndex = index;
        keyboardSelectionTimer.start();
    }

    function executeKeyboardSelection(index) {
        keyboardSelectionIndex = index;
        keyboardSelectionRequested = true;
    }

    function handleSaveFile(filePath) {
        var normalizedPath = filePath;
        if (!normalizedPath.startsWith("file://")) {
            normalizedPath = encodeFileUrl(filePath);
        }

        var exists = false;
        var fileName = filePath.split('/').pop();

        for (var i = 0; i < folderModel.count; i++) {
            if (folderModel.get(i, "fileName") === fileName && !folderModel.get(i, "fileIsDir")) {
                exists = true;
                break;
            }
        }

        if (exists) {
            pendingFilePath = normalizedPath;
            showOverwriteConfirmation = true;
        } else {
            fileSelected(normalizedPath);
            closeRequested();
        }
    }

    onCurrentPathChanged: {
        selectedFilePath = "";
        selectedFileName = "";
        selectedFileIsDir = false;
        saveSettings();
    }

    onSelectedIndexChanged: {
        if (selectedIndex >= 0 && folderModel && selectedIndex < folderModel.count) {
            selectedFilePath = "";
            selectedFileName = "";
            selectedFileIsDir = false;
        }
    }

    property var quickAccessLocations: [
        {
            "name": I18n.tr("Home"),
            "path": homeDir,
            "icon": "home"
        },
        {
            "name": I18n.tr("Documents"),
            "path": docsDir,
            "icon": "file_text"
        },
        {
            "name": I18n.tr("Downloads"),
            "path": downloadDir,
            "icon": "download"
        },
        {
            "name": I18n.tr("Pictures"),
            "path": picsDir,
            "icon": "photo"
        },
        {
            "name": I18n.tr("Music"),
            "path": musicDir,
            "icon": "music"
        },
        {
            "name": I18n.tr("Videos"),
            "path": videosDir,
            "icon": "video"
        },
        {
            "name": I18n.tr("Desktop"),
            "path": desktopDir,
            "icon": "monitor"
        }
    ]

    FolderListModel {
        id: folderModel

        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: root.showHiddenFiles
        caseSensitive: false
        nameFilters: fileExtensions
        showFiles: true
        showDirs: true
        folder: encodeFileUrl(currentPath || homeDir)
        sortField: {
            switch (sortBy) {
            case "name":
                return FolderListModel.Name;
            case "size":
                return FolderListModel.Size;
            case "modified":
                return FolderListModel.Time;
            case "type":
                return FolderListModel.Type;
            default:
                return FolderListModel.Name;
            }
        }
        sortReversed: !sortAscending
    }

    QtObject {
        id: keyboardController

        property int totalItems: folderModel.count
        property int gridColumns: viewMode === "list" ? 1 : Math.max(1, actualGridColumns)

        function handleKey(event) {
            if (event.key === Qt.Key_Escape && root.closeOnEscape) {
                closeRequested();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_F10) {
                showKeyboardHints = !showKeyboardHints;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_F1 || event.key === Qt.Key_I) {
                showFileInfo = !showFileInfo;
                event.accepted = true;
                return;
            }
            if ((event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) || event.key === Qt.Key_Backspace) {
                if (currentPath !== homeDir) {
                    navigateUp();
                    event.accepted = true;
                }
                return;
            }
            if (!keyboardNavigationActive) {
                const isInitKey = event.key === Qt.Key_Tab || event.key === Qt.Key_Down || event.key === Qt.Key_Right || (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) || (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) || (event.key === Qt.Key_L && event.modifiers & Qt.ControlModifier);

                if (isInitKey) {
                    keyboardNavigationActive = true;
                    if (currentPath !== homeDir) {
                        backButtonFocused = true;
                        selectedIndex = -1;
                    } else {
                        backButtonFocused = false;
                        selectedIndex = 0;
                    }
                    event.accepted = true;
                }
                return;
            }
            switch (event.key) {
            case Qt.Key_Tab:
                if (backButtonFocused) {
                    backButtonFocused = false;
                    selectedIndex = 0;
                } else if (selectedIndex < totalItems - 1) {
                    selectedIndex++;
                } else if (currentPath !== homeDir) {
                    backButtonFocused = true;
                    selectedIndex = -1;
                } else {
                    selectedIndex = 0;
                }
                event.accepted = true;
                break;
            case Qt.Key_Backtab:
                if (backButtonFocused) {
                    backButtonFocused = false;
                    selectedIndex = totalItems - 1;
                } else if (selectedIndex > 0) {
                    selectedIndex--;
                } else if (currentPath !== homeDir) {
                    backButtonFocused = true;
                    selectedIndex = -1;
                } else {
                    selectedIndex = totalItems - 1;
                }
                event.accepted = true;
                break;
            case Qt.Key_N:
                if (event.modifiers & Qt.ControlModifier) {
                    if (backButtonFocused) {
                        backButtonFocused = false;
                        selectedIndex = 0;
                    } else if (selectedIndex < totalItems - 1) {
                        selectedIndex++;
                    }
                    event.accepted = true;
                }
                break;
            case Qt.Key_P:
                if (event.modifiers & Qt.ControlModifier) {
                    if (selectedIndex > 0) {
                        selectedIndex--;
                    } else if (currentPath !== homeDir) {
                        backButtonFocused = true;
                        selectedIndex = -1;
                    }
                    event.accepted = true;
                }
                break;
            case Qt.Key_J:
                if (event.modifiers & Qt.ControlModifier) {
                    if (selectedIndex < totalItems - 1) {
                        selectedIndex++;
                    }
                    event.accepted = true;
                }
                break;
            case Qt.Key_K:
                if (event.modifiers & Qt.ControlModifier) {
                    if (selectedIndex > 0) {
                        selectedIndex--;
                    } else if (currentPath !== homeDir) {
                        backButtonFocused = true;
                        selectedIndex = -1;
                    }
                    event.accepted = true;
                }
                break;
            case Qt.Key_H:
                if (event.modifiers & Qt.ControlModifier) {
                    if (!backButtonFocused && selectedIndex > 0) {
                        selectedIndex--;
                    } else if (currentPath !== homeDir) {
                        backButtonFocused = true;
                        selectedIndex = -1;
                    }
                    event.accepted = true;
                }
                break;
            case Qt.Key_L:
                if (event.modifiers & Qt.ControlModifier) {
                    if (backButtonFocused) {
                        backButtonFocused = false;
                        selectedIndex = 0;
                    } else if (selectedIndex < totalItems - 1) {
                        selectedIndex++;
                    }
                    event.accepted = true;
                }
                break;
            case Qt.Key_Left:
                if (pathInputHasFocus)
                    return;
                if (backButtonFocused)
                    return;
                if (selectedIndex > 0) {
                    selectedIndex--;
                } else if (currentPath !== homeDir) {
                    backButtonFocused = true;
                    selectedIndex = -1;
                }
                event.accepted = true;
                break;
            case Qt.Key_Right:
                if (pathInputHasFocus)
                    return;
                if (backButtonFocused) {
                    backButtonFocused = false;
                    selectedIndex = 0;
                } else if (selectedIndex < totalItems - 1) {
                    selectedIndex++;
                }
                event.accepted = true;
                break;
            case Qt.Key_Up:
                if (backButtonFocused) {
                    backButtonFocused = false;
                    if (gridColumns === 1) {
                        selectedIndex = 0;
                    } else {
                        var col = selectedIndex % gridColumns;
                        selectedIndex = Math.min(col, totalItems - 1);
                    }
                } else if (selectedIndex >= gridColumns) {
                    selectedIndex -= gridColumns;
                } else if (selectedIndex > 0 && gridColumns === 1) {
                    selectedIndex--;
                } else if (currentPath !== homeDir) {
                    backButtonFocused = true;
                    selectedIndex = -1;
                }
                event.accepted = true;
                break;
            case Qt.Key_Down:
                if (backButtonFocused) {
                    backButtonFocused = false;
                    selectedIndex = 0;
                } else if (gridColumns === 1) {
                    if (selectedIndex < totalItems - 1) {
                        selectedIndex++;
                    }
                } else {
                    var newIndex = selectedIndex + gridColumns;
                    if (newIndex < totalItems) {
                        selectedIndex = newIndex;
                    } else {
                        var lastRowStart = Math.floor((totalItems - 1) / gridColumns) * gridColumns;
                        var col = selectedIndex % gridColumns;
                        var targetIndex = lastRowStart + col;
                        if (targetIndex < totalItems && targetIndex > selectedIndex) {
                            selectedIndex = targetIndex;
                        }
                    }
                }
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (backButtonFocused) {
                    navigateUp();
                } else if (selectedIndex >= 0 && selectedIndex < totalItems) {
                    root.keyboardFileSelection(selectedIndex);
                }
                event.accepted = true;
                break;
            }
        }
    }

    Timer {
        id: keyboardSelectionTimer

        property int targetIndex: -1

        interval: 1
        onTriggered: {
            executeKeyboardSelection(targetIndex);
        }
    }

    focus: true

    Keys.onPressed: event => {
        keyboardController.handleKey(event);
    }

    Column {
        anchors.fill: parent
        spacing: 0

        RBox {
            Layout.fillWidth: true
            implicitHeight: Math.round(48 * Style.uiScaleRatio)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                RIcon {
                    name: browserIcon
                    pointSize: Style.fontSizeXXL
                    color: Color.mPrimary
                }

                RText {
                    text: browserTitle
                    pointSize: Style.fontSizeXL
                    color: Color.mOnSurface
                    font.weight: Style.fontWeightMedium
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                RIconButton {
                    icon: showHiddenFiles ? "eye_off" : "eye"
                    tooltipText: showHiddenFiles ? "Hide hidden files" : "Show hidden files"
                    baseSize: Style.baseWidgetSize * 0.8
                    onClicked: showHiddenFiles = !showHiddenFiles
                }

                RIconButton {
                    icon: viewMode === "grid" ? "list" : "grid"
                    tooltipText: viewMode === "grid" ? "List view" : "Grid view"
                    baseSize: Style.baseWidgetSize * 0.8
                    onClicked: viewMode = viewMode === "grid" ? "list" : "grid"
                }

                RIconButton {
                    icon: iconSizeIndex === 0 ? "photo_size_select_small" : iconSizeIndex === 1 ? "photo_size_select_large" : iconSizeIndex === 2 ? "photo_size_select_actual" : "zoom_in"
                    tooltipText: "Icon size"
                    baseSize: Style.baseWidgetSize * 0.8
                    visible: viewMode === "grid"
                    onClicked: iconSizeIndex = (iconSizeIndex + 1) % iconSizes.length
                }

                RIconButton {
                    icon: "info"
                    tooltipText: "File info"
                    baseSize: Style.baseWidgetSize * 0.8
                    onClicked: root.showKeyboardHints = !root.showKeyboardHints
                }

                RIconButton {
                    icon: "x"
                    tooltipText: "Close"
                    baseSize: Style.baseWidgetSize * 0.8
                    onClicked: root.closeRequested()
                }
            }
        }

        RDivider {}

        Item {
            width: parent.width
            height: parent.height - 49

            RowLayout {
                anchors.fill: parent
                spacing: 0

                RBox {
                    width: showSidebar ? Math.round(201 * Style.uiScaleRatio) : 0
                    height: parent.height
                    visible: showSidebar

                    FilesSidebar {
                        height: parent.height
                        quickAccessLocations: root.quickAccessLocations
                        currentPath: root.currentPath
                        onLocationSelected: path => navigateTo(path)
                    }
                }

                RDivider {
                    orientation: Qt.Vertical
                    visible: showSidebar
                }

                ColumnLayout {
                    width: parent.width - (showSidebar ? Math.round(201 * Style.uiScaleRatio) : 0)
                    height: parent.height
                    spacing: 0

                    FilesNavigation {
                        width: parent.width
                        currentPath: root.currentPath
                        homeDir: root.homeDir
                        backButtonFocused: root.backButtonFocused
                        keyboardNavigationActive: root.keyboardNavigationActive
                        showSidebar: root.showSidebar
                        pathEditMode: root.pathEditMode
                        onNavigateUp: root.navigateUp()
                        onNavigateTo: path => root.navigateTo(path)
                        onPathInputFocusChanged: hasFocus => {
                            root.pathInputHasFocus = hasFocus;
                            if (hasFocus) {
                                root.pathEditMode = true;
                            }
                        }
                    }

                    RDivider {}

                    Item {
                        id: gridContainer
                        width: parent.width
                        height: parent.height - Math.round(41 * Style.uiScaleRatio)
                        clip: true

                        property real gridCellWidth: iconSizes[iconSizeIndex] + 24
                        property real gridCellHeight: iconSizes[iconSizeIndex] + 56
                        property real availableGridWidth: width - Style.marginM * 2
                        property int gridColumns: Math.max(1, Math.floor(availableGridWidth / gridCellWidth))
                        property real gridLeftMargin: Style.marginM + Math.max(0, (availableGridWidth - (gridColumns * gridCellWidth)) / 2)

                        onGridColumnsChanged: {
                            root.actualGridColumns = gridColumns;
                        }
                        Component.onCompleted: {
                            root.actualGridColumns = gridColumns;
                        }

                        RGridView {
                            id: fileGrid
                            anchors.fill: parent
                            anchors.leftMargin: gridContainer.gridLeftMargin
                            anchors.rightMargin: Style.marginM
                            anchors.topMargin: Style.marginS
                            anchors.bottomMargin: Style.marginS
                            visible: viewMode === "grid"
                            cellWidth: gridContainer.gridCellWidth
                            cellHeight: gridContainer.gridCellHeight
                            cacheBuffer: 260
                            model: folderModel
                            currentIndex: selectedIndex
                            onCurrentIndexChanged: {
                                if (keyboardNavigationActive && currentIndex >= 0)
                                    positionViewAtIndex(currentIndex, GridView.Contain);
                            }

                            delegate: FilesGridDelegate {
                                iconSizes: root.iconSizes
                                iconSizeIndex: root.iconSizeIndex
                                selectedIndex: root.selectedIndex
                                keyboardNavigationActive: root.keyboardNavigationActive
                                onItemClicked: (index, path, name, isDir) => {
                                    selectedIndex = index;
                                    setSelectedFileData(path, name, isDir);
                                    if (isDir) {
                                        navigateTo(path);
                                    } else {
                                        fileSelected(path);
                                        root.closeRequested();
                                    }
                                }
                                onItemSelected: (index, path, name, isDir) => {
                                    setSelectedFileData(path, name, isDir);
                                }

                                Connections {
                                    function onKeyboardSelectionRequestedChanged() {
                                        if (root.keyboardSelectionRequested && root.keyboardSelectionIndex === index) {
                                            root.keyboardSelectionRequested = false;
                                            selectedIndex = index;
                                            setSelectedFileData(filePath, fileName, fileIsDir);
                                            if (fileIsDir) {
                                                navigateTo(filePath);
                                            } else {
                                                fileSelected(filePath);
                                                root.closeRequested();
                                            }
                                        }
                                    }

                                    target: root
                                }
                            }
                        }

                        RListView {
                            id: fileList
                            anchors.fill: parent
                            anchors.leftMargin: Style.marginM
                            anchors.rightMargin: Style.marginM
                            anchors.topMargin: Style.marginS
                            anchors.bottomMargin: Style.marginS
                            visible: viewMode === "list"
                            spacing: 2
                            model: folderModel
                            currentIndex: selectedIndex
                            onCurrentIndexChanged: {
                                if (keyboardNavigationActive && currentIndex >= 0)
                                    positionViewAtIndex(currentIndex, ListView.Contain);
                            }

                            delegate: FilesListDelegate {
                                width: fileList.width
                                selectedIndex: root.selectedIndex
                                keyboardNavigationActive: root.keyboardNavigationActive
                                onItemClicked: (index, path, name, isDir) => {
                                    selectedIndex = index;
                                    setSelectedFileData(path, name, isDir);
                                    if (isDir) {
                                        navigateTo(path);
                                    } else {
                                        fileSelected(path);
                                        root.closeRequested();
                                    }
                                }
                                onItemSelected: (index, path, name, isDir) => {
                                    setSelectedFileData(path, name, isDir);
                                }

                                Connections {
                                    function onKeyboardSelectionRequestedChanged() {
                                        if (root.keyboardSelectionRequested && root.keyboardSelectionIndex === index) {
                                            root.keyboardSelectionRequested = false;
                                            selectedIndex = index;
                                            setSelectedFileData(filePath, fileName, fileIsDir);
                                            if (fileIsDir) {
                                                navigateTo(filePath);
                                            } else {
                                                fileSelected(filePath);
                                                root.closeRequested();
                                            }
                                        }
                                    }

                                    target: root
                                }
                            }
                        }
                    }
                }
            }

            FilesSaveRow {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.marginL
                saveMode: root.saveMode
                defaultFileName: root.defaultFileName
                currentPath: root.currentPath
                onSaveRequested: filePath => handleSaveFile(filePath)
            }

            FilesKeyboardHints {
                id: keyboardHints

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.marginL
                showHints: root.showKeyboardHints
            }

            FilesInfo {
                id: fileInfo

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Style.marginL
                width: Math.round(300 * Style.uiScaleRatio)
                showFileInfo: root.showFileInfo
                selectedIndex: root.selectedIndex
                sourceFolderModel: folderModel
                currentPath: root.currentPath
                currentFileName: root.selectedFileName
                currentFileIsDir: root.selectedFileIsDir
                currentFileExtension: {
                    if (root.selectedFileIsDir || !root.selectedFileName)
                        return "";

                    var lastDot = root.selectedFileName.lastIndexOf('.');
                    return lastDot > 0 ? root.selectedFileName.substring(lastDot + 1).toLowerCase() : "";
                }
            }

            FilesSortMenu {
                id: sortMenu
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Math.round(120 * Style.uiScaleRatio)
                anchors.rightMargin: Style.marginL
                sortBy: root.sortBy
                sortAscending: root.sortAscending
                onSortBySelected: value => {
                    root.sortBy = value;
                }
                onSortOrderSelected: ascending => {
                    root.sortAscending = ascending;
                }
            }
        }

        FilesOverwriteDialog {
            anchors.fill: parent
            showDialog: showOverwriteConfirmation
            pendingFilePath: root.pendingFilePath
            onConfirmed: filePath => {
                showOverwriteConfirmation = false;
                fileSelected(filePath);
                pendingFilePath = "";
                Qt.callLater(() => root.closeRequested());
            }
            onCancelled: {
                showOverwriteConfirmation = false;
                pendingFilePath = "";
            }
        }
    }
}