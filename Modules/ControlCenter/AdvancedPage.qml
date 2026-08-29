pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property var parentModal: null
    property bool refreshRequested: false
    property bool refreshConfirmed: false
    readonly property real pageContentWidth: 600
    readonly property var remoteOptions: RcloneService.remotes.map((remote) => ({
        "label": remote.name,
        "value": remote.name,
        "remoteName": remote.name,
        "remoteType": remote.type,
        "enabled": !RcloneService.isReadOnly(remote),
        "tooltip": RcloneService.isReadOnly(remote)
            ? qsTr("此云存储不支持写入，不能设为默认") : ""
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
        cloudManager.dismiss();
    }

    function backupRootError(value) {
        const raw = String(value || "").trim();
        if (raw.indexOf(":") >= 0)
            return qsTr("请输入 remote 内的相对目录，不要包含 remote 名称或冒号");
        const relative = raw.replace(/^\/+|\/+$/g, "");
        if (relative === "." || relative === "..")
            return qsTr("请输入有效的远程目录");
        return "";
    }

    function saveBackupRoot() {
        const error = root.backupRootError(backupRootField.text);
        if (error !== "")
            return ;
        UiPreferences.setCloudBackupRoot(backupRootField.text);
        backupRootField.text = "/" + UiPreferences.cloudBackupRoot;
    }

    function refreshConfiguration() {
        if (RcloneService.remotesLoading)
            return ;
        refreshConfirmationTimer.stop();
        root.refreshRequested = true;
        root.refreshConfirmed = false;
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

        function onRemotesLoadingChanged() {
            if (RcloneService.remotesLoading || !root.refreshRequested)
                return ;

            root.refreshRequested = false;
            if (RcloneService.remotesError === "") {
                root.refreshConfirmed = true;
                refreshConfirmationTimer.restart();
            }
        }
    }

    Timer {
        id: refreshConfirmationTimer

        interval: 1400
        onTriggered: root.refreshConfirmed = false
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

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS

                SearchSelectMenuField {
                    Layout.fillWidth: true
                    options: root.remoteOptions
                    value: RcloneService.selectedRemoteName
                    placeholder: qsTr("尚未选择云存储")
                    closeOnAccept: true
                    showCheckmark: false
                    fieldHeight: Metrics.controlHeightXL
                    itemHeight: Metrics.controlHeightXL
                    leadingWidth: Metrics.iconM
                    enabled: options.length > 0
                    onAccepted: (value) => RcloneService.setDefaultRemote(value)

                    leadingDelegate: Component {
                        CloudProviderIcon {
                            property var optionData: null

                            remoteName: optionData ? optionData.remoteName : ""
                            remoteType: optionData ? optionData.remoteType : ""
                            iconSize: Metrics.iconM
                        }
                    }
                }

                IconButton {
                    id: refreshButton

                    Layout.preferredWidth: Metrics.controlHeightXL
                    Layout.preferredHeight: Metrics.controlHeightXL
                    iconName: RcloneService.remotesError !== ""
                        && !RcloneService.remotesLoading
                        ? "sync_problem"
                        : root.refreshConfirmed ? "check" : "refresh"
                    iconFill: root.refreshConfirmed ? 1 : 0
                    iconColor: RcloneService.remotesError !== ""
                        && !RcloneService.remotesLoading
                        ? Appearance.colors.colError
                        : root.refreshConfirmed
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colOnSurfaceVariant
                    tooltipText: RcloneService.remotesLoading
                        ? qsTr("正在刷新配置")
                        : RcloneService.remotesError !== ""
                            ? RcloneService.remotesError
                            : root.refreshConfirmed
                                ? qsTr("配置已刷新") : qsTr("刷新配置")
                    accessibleName: tooltipText
                    enabled: !RcloneService.remotesLoading
                        && !RcloneService.configBusy
                    onClicked: root.refreshConfiguration()
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("查看云存储")
                iconName: "cloud_queue"
                trailingIconName: "chevron_right"
                onClicked: cloudManager.showWindow()
            }

            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("添加云存储")
                iconName: "add"
                trailingIconName: "chevron_right"
                enabled: !RcloneService.configBusy
                onClicked: cloudWizard.showWindow()
            }

            MaterialFilledTextField {
                id: backupRootField

                Layout.fillWidth: true
                labelText: qsTr("电脑备份位置")
                text: "/" + UiPreferences.cloudBackupRoot
                error: root.backupRootError(text) !== ""
                onAccepted: root.saveBackupRoot()
                onEditingFinished: root.saveBackupRoot()
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

    CloudRemoteWizard {
        id: cloudWizard

        parentModal: root.parentModal
    }

    CloudRemoteManagerWindow {
        id: cloudManager

        parentModal: root.parentModal
    }
}
