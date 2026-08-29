import QtCore
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Components
import qs.Modules.FilePicker
import qs.Services
import qs.Widgets.common

FloatingWindow {
    id: root

    property var parentModal: null
    property bool _restoreAfterPicker: false

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
        if (index < 0 || index >= folders.length)
            return ;

        folders[index].enabled = enabled;
        UiPreferences.setCloudBackupFolders(folders);
    }

    function removeFolder(index) {
        UiPreferences.setCloudBackupFolders(UiPreferences.cloudBackupFolders.filter(function(folder, folderIndex) {
            return folderIndex !== index;
        }));
    }

    function addFolder(path) {
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
        _restoreAfterPicker = true;
        root.visible = false;
        folderPicker.targetScreen = root.screen;
        folderPicker.openAt(folderPicker.homeDir);
    }

    function startBackup() {
        RcloneService.backupFolders(selectedFolders());
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spacingXL
            spacing: Metrics.spacingM

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingM

                Rectangle {
                    Layout.preferredWidth: Metrics.controlHeightL
                    Layout.preferredHeight: Metrics.controlHeightL
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colPrimaryContainer

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "backup"
                        iconSize: Metrics.iconM
                        fill: 1
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("电脑备份")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.headlineSmall.family
                    font.pixelSize: Typography.headlineSmall.pixelSize
                    font.weight: Typography.headlineSmall.weight
                }

                IconButton {
                    iconName: "close"
                    accessibleName: qsTr("关闭")
                    onClicked: root.dismiss()
                }

            }

            Text {
                Layout.fillWidth: true
                text: qsTr("所选文件夹会同步到云端；被替换或删除的文件将保留在带时间戳的历史版本中。")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.bodyMedium.family
                font.pixelSize: Typography.bodyMedium.pixelSize
                wrapMode: Text.Wrap
            }

            ListView {
                id: folderList

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Metrics.spacingXS
                model: UiPreferences.cloudBackupFolders

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, 320)
                    visible: folderList.count === 0
                    spacing: Metrics.spacingM

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 88
                        Layout.preferredHeight: 88
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSecondaryContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "folder_off"
                            iconSize: 48
                            fill: 1
                            color: Appearance.colors.colOnSecondaryContainer
                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("尚未添加备份文件夹")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.titleMedium.family
                        font.pixelSize: Typography.titleMedium.pixelSize
                        font.weight: Typography.titleMedium.weight
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                }

                delegate: Rectangle {
                    id: folderRow

                    required property var modelData
                    required property int index
                    readonly property var info: root.folderInfo(folderRow.modelData)

                    width: ListView.view ? ListView.view.width : 0
                    height: 64
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHighest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Metrics.spacingM
                        anchors.rightMargin: Metrics.spacingXS
                        spacing: Metrics.spacingS

                        MaterialSymbol {
                            text: folderRow.info.icon
                            iconSize: Metrics.iconM
                            color: Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: folderRow.info.label
                                color: Appearance.colors.colOnSurface
                                font.family: Typography.bodyMedium.family
                                font.pixelSize: Typography.bodyMedium.pixelSize
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: folderRow.modelData.path
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Typography.bodySmall.family
                                font.pixelSize: Typography.bodySmall.pixelSize
                                elide: Text.ElideMiddle
                            }

                        }

                        StyledSwitch {
                            id: folderSwitch

                            checked: folderRow.modelData.enabled
                            enabled: RcloneService.backupState !== "running"
                            Accessible.name: qsTr("备份 %1").arg(folderRow.info.label)
                            onToggled: root.updateFolder(folderRow.index, folderSwitch.checked)
                        }

                        IconButton {
                            iconName: "close"
                            iconSize: Metrics.iconS
                            enabled: RcloneService.backupState !== "running"
                            accessibleName: qsTr("移除 %1").arg(folderRow.info.label)
                            onClicked: root.removeFolder(folderRow.index)
                        }

                    }

                }

            }

            RowLayout {
                Layout.fillWidth: true

                ActionButton {
                    text: qsTr("添加其他路径")
                    iconName: "create_new_folder"
                    enabled: RcloneService.backupState !== "running"
                    onClicked: root.chooseFolder()
                }

                Item {
                    Layout.fillWidth: true
                }

            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: progressRow.implicitHeight + Metrics.spacingM * 2
                visible: RcloneService.backupState !== "idle"
                radius: Appearance.rounding.normal
                color: RcloneService.backupState === "error" ? Appearance.colors.colErrorContainer : Appearance.colors.colSecondaryContainer

                RowLayout {
                    id: progressRow

                    anchors.fill: parent
                    anchors.margins: Metrics.spacingM
                    spacing: Metrics.spacingM

                    MaterialLoadingIndicator {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        visible: RcloneService.backupState === "running"
                        running: visible
                        contained: false
                        indicatorColor: Appearance.colors.colOnSecondaryContainer
                        accessibleName: qsTr("正在备份")
                    }

                    MaterialSymbol {
                        visible: RcloneService.backupState !== "running"
                        text: RcloneService.backupState === "success" ? "cloud_done" : "error"
                        iconSize: Metrics.iconL
                        color: RcloneService.backupState === "error" ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingXXS

                        Text {
                            Layout.fillWidth: true
                            text: RcloneService.backupMessage
                            color: RcloneService.backupState === "error" ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer
                            font.family: Typography.bodyMedium.family
                            font.pixelSize: Typography.bodyMedium.pixelSize
                            font.weight: Font.Medium
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: RcloneService.backupState === "running"
                            text: RcloneService.backupProgress >= 0 ? qsTr("总进度 %1%").arg(Math.round(RcloneService.backupProgress * 100)) : qsTr("正在计算备份进度…")
                            color: Appearance.colors.colOnSecondaryContainer
                            font.family: Typography.labelMedium.family
                            font.pixelSize: Typography.labelMedium.pixelSize
                        }

                    }

                }

            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    text: qsTr("取消")
                    onClicked: root.dismiss()
                }

                ActionButton {
                    text: RcloneService.backupState === "running" ? qsTr("备份中") : qsTr("开始备份")
                    iconName: "backup"
                    filled: true
                    enabled: RcloneService.backupState !== "running" && root.selectedFolders().length > 0
                    onClicked: root.startBackup()
                }

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
