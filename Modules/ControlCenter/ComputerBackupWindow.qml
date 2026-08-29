import QtCore
import QtQuick
import Quickshell
import qs.Common
import qs.Modules.FilePicker
import qs.Services
import qs.Widgets.common

FloatingWindow {
    id: root

    property var parentModal: null
    property bool _restoreAfterPicker: false
    property string currentPage: "setup"

    function normalizeLocalPath(path) {
        let value = String(path || "").trim();
        if (value.startsWith("file://")) {
            try {
                value = decodeURIComponent(value.substring(7));
            } catch (error) {
                value = value.substring(7);
            }
        }
        if (!value.startsWith("/"))
            return "";

        return value === "/" ? value : value.replace(/\/+$/, "");
    }

    function systemFolderDefinitions() {
        return [{
            "kind": "desktop",
            "path": normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.DesktopLocation)),
            "label": qsTr("桌面"),
            "icon": "desktop_windows"
        }, {
            "kind": "documents",
            "path": normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.DocumentsLocation)),
            "label": qsTr("文档"),
            "icon": "description"
        }, {
            "kind": "downloads",
            "path": normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.DownloadLocation)),
            "label": qsTr("下载"),
            "icon": "download"
        }, {
            "kind": "music",
            "path": normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.MusicLocation)),
            "label": qsTr("音乐"),
            "icon": "music_note"
        }, {
            "kind": "pictures",
            "path": normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.PicturesLocation)),
            "label": qsTr("图片"),
            "icon": "image"
        }, {
            "kind": "videos",
            "path": normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.MoviesLocation)),
            "label": qsTr("视频"),
            "icon": "movie"
        }];
    }

    function defaultBackupFolders() {
        const result = [];
        const seen = {
        };
        for (const folder of systemFolderDefinitions()) {
            if (folder.path === "" || seen[folder.path])
                continue;

            seen[folder.path] = true;
            result.push({
                "path": folder.path,
                "enabled": true,
                "kind": folder.kind
            });
        }
        return result;
    }

    function ensureDefaults() {
        if (!UiPreferences.preferencesReady || UiPreferences.cloudBackupFoldersVersion >= 3)
            return ;

        const merged = defaultBackupFolders();
        const seen = {
        };
        for (const folder of merged) seen[folder.path] = true
        for (const folder of UiPreferences.cloudBackupFolders || []) {
            const path = normalizeLocalPath(folder && folder.path);
            if (path === "" || seen[path])
                continue;

            seen[path] = true;
            merged.push({
                "path": path,
                "enabled": folder.enabled === undefined ? true : !!folder.enabled,
                "kind": String(folder && folder.kind || "custom")
            });
        }
        UiPreferences.setCloudBackupFolders(merged);
    }

    function folderInfo(folderEntry) {
        const normalized = normalizeLocalPath(folderEntry && folderEntry.path);
        const kind = String(folderEntry && folderEntry.kind || "");
        for (const folder of systemFolderDefinitions()) {
            if (folder.kind === kind || folder.path === normalized)
                return folder;

        }
        const parts = normalized.split("/").filter((part) => {
            return part !== "";
        });
        return {
            "path": normalized,
            "label": parts.length > 0 ? parts[parts.length - 1] : normalized,
            "icon": "folder"
        };
    }

    function updateFolder(index, enabled) {
        const folders = UiPreferences.cloudBackupFolders.map((folder) => {
            return ({
                "path": folder.path,
                "enabled": folder.enabled,
                "kind": folder.kind
            });
        });
        if (index < 0 || index >= folders.length || RcloneService.backupActive)
            return ;

        folders[index].enabled = enabled;
        UiPreferences.setCloudBackupFolders(folders);
    }

    function removeFolder(index) {
        if (RcloneService.backupActive)
            return ;

        UiPreferences.setCloudBackupFolders(UiPreferences.cloudBackupFolders.filter(function(folder, folderIndex) {
            return folderIndex !== index;
        }));
    }

    function addFolder(path) {
        if (RcloneService.backupActive)
            return ;

        const normalized = normalizeLocalPath(path);
        if (normalized === "")
            return ;

        let kind = "custom";
        for (const folder of systemFolderDefinitions()) {
            if (folder.path === normalized) {
                kind = folder.kind;
                break;
            }
        }
        const folders = UiPreferences.cloudBackupFolders.map((folder) => {
            return ({
                "path": folder.path,
                "enabled": folder.enabled,
                "kind": folder.kind
            });
        });
        for (let index = 0; index < folders.length; ++index) {
            if (folders[index].path === normalized) {
                folders[index].enabled = true;
                folders[index].kind = kind;
                UiPreferences.setCloudBackupFolders(folders);
                return ;
            }
        }
        folders.push({
            "path": normalized,
            "enabled": true,
            "kind": kind
        });
        UiPreferences.setCloudBackupFolders(folders);
    }

    function selectedFolders() {
        return UiPreferences.cloudBackupFolders.filter((folder) => {
            return folder.enabled;
        }).map((folder) => {
            return folder.path;
        });
    }

    function showWindow() {
        if (!root.parentModal) {
            console.warn("ComputerBackupWindow cannot open without parentModal");
            return ;
        }
        ensureDefaults();
        clearBackupStatusTimer.stop();
        currentPage = RcloneService.backupState === "idle" ? "setup" : "task";
        root.visible = true;
        Qt.callLater(() => {
            return windowFocus.forceActiveFocus();
        });
    }

    function dismiss() {
        _restoreAfterPicker = false;
        root.visible = false;
        folderPicker.dismiss();
    }

    function chooseFolder() {
        if (RcloneService.backupActive)
            return ;

        _restoreAfterPicker = true;
        root.visible = false;
        folderPicker.targetScreen = root.screen;
        folderPicker.openAt(folderPicker.homeDir);
    }

    function startBackup() {
        const folders = selectedFolders();
        if (folders.length === 0)
            return ;

        if (RcloneService.backupFolders(folders))
            currentPage = "task";

    }

    function returnToSetup() {
        currentPage = "setup";
        if (!RcloneService.backupActive)
            clearBackupStatusTimer.restart();

    }

    function restartBackup() {
        if (RcloneService.restartBackup())
            currentPage = "task";

    }

    visible: false
    parentWindow: root.parentModal
    title: qsTr("电脑备份")
    implicitWidth: 600
    implicitHeight: 640
    minimumSize: Qt.size(480, 520)
    color: "transparent"
    onClosed: root.visible = false

    Connections {
        function onPreferencesReadyChanged() {
            if (root.visible)
                root.ensureDefaults();

        }

        target: UiPreferences
    }

    Connections {
        function onBackupStateChanged() {
            if (root.visible && RcloneService.backupActive)
                root.currentPage = "task";

        }

        target: RcloneService
    }

    Timer {
        id: clearBackupStatusTimer

        interval: Appearance.animation.elementResize.duration
        onTriggered: {
            if (root.currentPage === "setup" && !RcloneService.backupActive)
                RcloneService.clearCompletedBackupStatus();

        }
    }

    Rectangle {
        id: windowBackground

        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        color: BlurService.backgroundColor(Appearance.m3colors.m3surfaceContainerHigh)
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: windowBackground
        radius: windowBackground.radius
    }

    FocusScope {
        id: windowFocus

        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: (event) => {
            root.dismiss();
            event.accepted = true;
        }

        PageTransitionLayer {
            anchors.fill: parent
            active: root.currentPage === "setup"
            hubPage: true
            transitionsEnabled: root.visible

            BackupSetupPage {
                anchors.fill: parent
                folderModel: UiPreferences.cloudBackupFolders
                folderInfo: (entry) => {
                    return root.folderInfo(entry);
                }
                taskActive: RcloneService.backupActive
                canStart: root.selectedFolders().length > 0
                onCloseRequested: root.dismiss()
                onChooseFolderRequested: root.chooseFolder()
                onUpdateFolderRequested: (index, enabled) => {
                    return root.updateFolder(index, enabled);
                }
                onRemoveFolderRequested: (index) => {
                    return root.removeFolder(index);
                }
                onStartRequested: root.startBackup()
                onViewTaskRequested: root.currentPage = "task"
            }

        }

        PageTransitionLayer {
            anchors.fill: parent
            active: root.currentPage === "task"
            transitionsEnabled: root.visible

            BackupTaskPage {
                anchors.fill: parent
                onBackRequested: root.returnToSetup()
                onCloseRequested: root.dismiss()
                onStopRequested: RcloneService.stopBackup()
                onRestartRequested: root.restartBackup()
            }

        }

    }

    FilePickerWindow {
        id: folderPicker

        requiresParentWindow: false
        selectionMode: FilePickerWindow.Folders
        allowCurrentFolderSelection: true
        dialogTitle: qsTr("添加备份文件夹")
        description: qsTr("选择一个要包含在电脑备份中的文件夹")
        startPath: homeDir
        nameFilters: []
        windowIconName: "create_new_folder"
        emptyStateText: qsTr("当前文件夹为空")
        selectionPrompt: qsTr("选择文件夹")
        acceptLabel: qsTr("添加文件夹")
        formatSummary: qsTr("可添加当前文件夹或选中的子文件夹")
        onAccepted: function(path, isDirectory) {
            if (isDirectory)
                root.addFolder(path);

            if (root._restoreAfterPicker) {
                root._restoreAfterPicker = false;
                root.showWindow();
            }
        }
        onRejected: {
            if (root._restoreAfterPicker) {
                root._restoreAfterPicker = false;
                root.showWindow();
            }
        }
    }

}
