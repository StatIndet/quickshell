pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property var parentModal: null
    property var pendingDeleteRemote: null
    property string cloudStatusMessage: ""
    property string cloudStatusTone: "info"
    property bool refreshRequested: false
    readonly property real pageContentWidth: 600
    readonly property var writableRemoteOptions: RcloneService.writableRemotes().map((remote) => ({
        "label": RcloneService.providerDisplayName(remote.type, remote.name) + " — " + remote.name,
        "value": remote.name
    }))
    readonly property var templatePrograms: [({
        "id": "btop",
        "title": "btop",
        "icon": "monitoring"
    }), ({
        "id": "cava",
        "title": "Cava",
        "icon": "graphic_eq"
    }), ({
        "id": "kitty",
        "title": "Kitty",
        "icon": "terminal"
    }), ({
        "id": "yazi",
        "title": "Yazi",
        "icon": "folder"
    })]

    function closeChildWindows() {
        cloudWizard.dismiss();
        deleteDialog.close();
    }

    function backupRootError(value) {
        const raw = String(value || "").trim();
        if (raw.indexOf(":") >= 0)
            return qsTr("请输入 remote 内的相对目录，不要包含 remote 名称或冒号");
        if (raw === "/" || raw === "." || raw === "..")
            return qsTr("请输入有效的远程目录");
        return "";
    }

    function saveBackupRoot() {
        const error = root.backupRootError(backupRootField.text);
        backupRootField.errorText = error;
        if (error !== "")
            return ;
        UiPreferences.setCloudBackupRoot(backupRootField.text);
        backupRootField.text = UiPreferences.cloudBackupRoot;
    }

    function requestDelete(remote) {
        if (!remote || RcloneService.backupActive || RcloneService.configBusy)
            return ;
        root.pendingDeleteRemote = remote;
        deleteDialog.open();
    }

    function confirmDelete() {
        if (!root.pendingDeleteRemote)
            return ;
        const name = root.pendingDeleteRemote.name;
        deleteDialog.close();
        if (!RcloneService.deleteRemote(name)) {
            root.cloudStatusTone = "error";
            root.cloudStatusMessage = qsTr("无法开始删除云存储配置");
        }
    }

    function refreshConfiguration() {
        if (RcloneService.remotesLoading)
            return ;
        root.refreshRequested = true;
        root.cloudStatusMessage = "";
        RcloneService.refreshRemotes();
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 24

    Component.onCompleted: {
        if (RcloneService.providers.length === 0)
            RcloneService.loadProviders();
    }

    Connections {
        target: RcloneService

        function onRemoteDeleted(remoteName) {
            root.pendingDeleteRemote = null;
            root.cloudStatusTone = "info";
            root.cloudStatusMessage = qsTr("已删除云存储“%1”").arg(remoteName);
        }

        function onRemoteDeleteFailed(message) {
            root.cloudStatusTone = "error";
            root.cloudStatusMessage = message;
        }

        function onRemotesLoadingChanged() {
            if (!RcloneService.remotesLoading && root.refreshRequested) {
                root.refreshRequested = false;
                root.cloudStatusTone = RcloneService.remotesError === "" ? "info" : "error";
                root.cloudStatusMessage = RcloneService.remotesError === ""
                    ? qsTr("云存储配置已刷新") : RcloneService.remotesError;
            }
        }
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(root.pageContentWidth, Math.max(0, root.width - 48))
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: Appearance.spacing.medium

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("云存储")
            iconName: "cloud"

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: root.cloudStatusMessage !== ""
                    || RcloneService.remotesError !== ""
                tone: root.cloudStatusMessage !== ""
                    ? root.cloudStatusTone : "error"
                message: root.cloudStatusMessage !== ""
                    ? root.cloudStatusMessage : RcloneService.remotesError
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("默认云存储")
                supportingText: RcloneService.selectedRemote
                    ? RcloneService.selectedRemote.name
                    : qsTr("尚未选择云存储")
                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 300
                    options: root.writableRemoteOptions
                    value: RcloneService.selectedRemoteName
                    placeholder: qsTr("尚未选择云存储")
                    closeOnAccept: true
                    enabled: options.length > 0
                    onAccepted: (value) => RcloneService.setDefaultRemote(value)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                text: qsTr("已配置的云存储")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.labelLarge.family
                font.pixelSize: Typography.labelLarge.pixelSize
                font.weight: Typography.labelLarge.weight
            }

            Repeater {
                model: RcloneService.remotes

                SettingsRow {
                    id: remoteRow

                    required property var modelData

                    Layout.fillWidth: true
                    title: RcloneService.providerDisplayName(modelData.type, modelData.name)
                    supportingText: modelData.name + " · " + modelData.type
                    iconName: ""

                    trailing: RowLayout {
                        spacing: Metrics.spacingXS

                        CloudProviderIcon {
                            Layout.preferredWidth: Metrics.iconL
                            Layout.preferredHeight: Metrics.iconL
                            remoteName: remoteRow.modelData.name
                            remoteType: remoteRow.modelData.type
                            iconSize: Metrics.iconL
                        }

                        Rectangle {
                            visible: RcloneService.selectedRemoteName
                                === remoteRow.modelData.name
                            implicitWidth: defaultLabel.implicitWidth
                                + Metrics.spacingM * 2
                            implicitHeight: Metrics.controlHeightS
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colSecondaryContainer

                            Text {
                                id: defaultLabel

                                anchors.centerIn: parent
                                text: qsTr("默认")
                                color: Appearance.colors.colOnSecondaryContainer
                                font.family: Typography.labelMedium.family
                                font.pixelSize: Typography.labelMedium.pixelSize
                                font.weight: Typography.labelMedium.weight
                            }
                        }

                        IconButton {
                            id: moreButton

                            iconName: "more_horiz"
                            accessibleName: qsTr("云存储操作")
                            enabled: !RcloneService.configBusy
                            onClicked: remoteMenu.open()

                            Menu {
                                id: remoteMenu

                                y: moreButton.height

                                MenuItem {
                                    text: qsTr("设为默认")
                                    enabled: RcloneService.selectedRemoteName
                                        !== remoteRow.modelData.name
                                        && !RcloneService.isReadOnly(remoteRow.modelData)
                                    onTriggered: RcloneService.setDefaultRemote(
                                        remoteRow.modelData.name)
                                }

                                MenuItem {
                                    text: qsTr("删除")
                                    enabled: !RcloneService.backupActive
                                        && !RcloneService.configBusy
                                    onTriggered: root.requestDelete(remoteRow.modelData)
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: !RcloneService.remotesLoading
                    && RcloneService.remotes.length === 0
                spacing: Metrics.spacingXS

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "cloud_off"
                    iconSize: Metrics.iconL
                    color: Appearance.colors.colOnSurfaceVariant
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("尚未配置云存储")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Typography.bodyMedium.family
                    font.pixelSize: Typography.bodyMedium.pixelSize
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("添加云存储")
                iconName: "add"
                trailingIconName: "chevron_right"
                enabled: !RcloneService.configBusy
                onClicked: cloudWizard.showWindow()
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                Layout.topMargin: Metrics.spacingS
                text: qsTr("电脑备份位置")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.labelLarge.family
                font.pixelSize: Typography.labelLarge.pixelSize
                font.weight: Typography.labelLarge.weight
            }

            OutlinedTextField {
                id: backupRootField

                Layout.fillWidth: true
                labelText: qsTr("电脑备份位置")
                text: UiPreferences.cloudBackupRoot
                supportingText: qsTr("remote 内的相对根目录")
                onTextChanged: errorText = root.backupRootError(text)
                onAccepted: root.saveBackupRoot()
                onEditingFinished: root.saveBackupRoot()
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "folder_data"
                title: qsTr("完整位置")
                supportingText: RcloneService.selectedRemoteName !== ""
                    ? RcloneService.selectedRemoteName + ":"
                        + UiPreferences.cloudBackupRoot
                    : qsTr("尚未选择云存储")
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                Layout.rightMargin: Metrics.spacingS
                text: qsTr("更改位置不会移动现有备份。新的备份将保存到新位置。")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.bodySmall.family
                font.pixelSize: Typography.bodySmall.pixelSize
                font.weight: Typography.bodySmall.weight
                wrapMode: Text.Wrap
            }

            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("刷新配置")
                description: RcloneService.remotesLoading
                    ? qsTr("正在刷新…") : ""
                iconName: "refresh"
                trailingIconName: ""
                enabled: !RcloneService.remotesLoading
                    && !RcloneService.configBusy
                onClicked: root.refreshConfiguration()
            }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: ThemeService.generating
            message: qsTr("正在为已启用的程序生成 Matugen 配色…")
            iconName: "progress_activity"
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Matugen 模板生成")

            Repeater {
                model: root.templatePrograms

                SettingsRow {
                    required property var modelData

                    Layout.fillWidth: true
                    iconName: modelData.icon
                    title: modelData.title

                    trailing: StyledSwitch {
                        enabled: !ThemeService.generating
                        checked: PersonalizationConfig.isMatugenTemplateEnabled(modelData.id)
                        Accessible.name: qsTr("启用 %1 Matugen 模板").arg(modelData.title)
                        onToggled: ThemeService.setMatugenTemplateEnabled(modelData.id, checked)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }

    MaterialDialog {
        id: deleteDialog

        anchors.centerIn: Overlay.overlay
        width: Math.min(440, root.width - Metrics.spacingL * 2)
        dialogTitle: root.pendingDeleteRemote
            ? qsTr("删除“%1”？").arg(RcloneService.providerDisplayName(
                root.pendingDeleteRemote.type,
                root.pendingDeleteRemote.name)) : qsTr("删除云存储")
        messageText: root.pendingDeleteRemote
            ? qsTr("将从 rclone 配置中删除 remote “%1”。这不会主动删除云端已有文件。")
                .arg(root.pendingDeleteRemote.name) : ""

        actionsComponent: Component {
            RowLayout {
                spacing: Metrics.spacingS
                Item { Layout.fillWidth: true }
                ActionButton {
                    text: qsTr("取消")
                    onClicked: deleteDialog.close()
                }
                ActionButton {
                    text: qsTr("删除")
                    enabled: !RcloneService.backupActive
                        && !RcloneService.configBusy
                    onClicked: root.confirmDelete()
                }
            }
        }
    }

    CloudRemoteWizard {
        id: cloudWizard

        parentModal: root.parentModal
    }
}
