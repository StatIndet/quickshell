pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
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
    readonly property var remoteOptions: RcloneService.remotes.map((remote) => {
        return ({
            "label": remote.name,
            "value": remote.name,
            "remoteName": remote.name,
            "remoteType": remote.type,
            "enabled": !RcloneService.isReadOnly(remote),
            "tooltip": RcloneService.isReadOnly(remote) ? qsTr("此云存储不支持写入，不能设为默认") : ""
        });
    })
    property var pendingTemplate: null
    property bool deletingTemplate: false

    function requestTemplateAction(template, deleting) {
        root.pendingTemplate = template;
        root.deletingTemplate = deleting;
        templateDialog.open();
    }

    function closeChildWindows() {
        templateAddWindow.dismiss();
        templateDialog.close();
        cloudWizard.dismiss();
        cloudManager.dismiss();
    }

    function cloudRootError(value) {
        const raw = String(value || "").trim();
        if (raw.indexOf(":") >= 0)
            return qsTr("请输入 remote 内的相对目录，不要包含 remote 名称或冒号");

        const relative = raw.replace(/^\/+|\/+$/g, "");
        if (relative === "." || relative === "..")
            return qsTr("请输入有效的远程目录");

        return "";
    }

    function saveBackupRoot() {
        const error = root.cloudRootError(backupRootField.text);
        if (error !== "")
            return ;

        UiPreferences.setCloudBackupRoot(backupRootField.text);
        backupRootField.text = "/" + UiPreferences.cloudBackupRoot;
    }

    function saveUploadRoot() {
        const error = root.cloudRootError(uploadRootField.text);
        if (error !== "")
            return ;

        UiPreferences.setCloudUploadRoot(uploadRootField.text);
        uploadRootField.text = "/" + UiPreferences.cloudUploadRoot;
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
        function onRemotesLoadingChanged() {
            if (RcloneService.remotesLoading || !root.refreshRequested)
                return ;

            root.refreshRequested = false;
            if (RcloneService.remotesError === "") {
                root.refreshConfirmed = true;
                refreshConfirmationTimer.restart();
            }
        }

        target: RcloneService
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
            title: qsTr("地图与天气服务")
            iconName: "map"

            MapTilerApiSettingsCard {
                Layout.fillWidth: true
            }

            OpenWeatherApiSettingsCard {
                Layout.fillWidth: true
            }

        }

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
                    onAccepted: (value) => {
                        return RcloneService.setDefaultRemote(value);
                    }

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
                    iconName: RcloneService.remotesError !== "" && !RcloneService.remotesLoading ? "sync_problem" : root.refreshConfirmed ? "check" : "refresh"
                    iconFill: root.refreshConfirmed ? 1 : 0
                    iconColor: RcloneService.remotesError !== "" && !RcloneService.remotesLoading ? Appearance.colors.colError : root.refreshConfirmed ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    tooltipText: RcloneService.remotesLoading ? qsTr("正在刷新配置") : RcloneService.remotesError !== "" ? RcloneService.remotesError : root.refreshConfirmed ? qsTr("配置已刷新") : qsTr("刷新配置")
                    accessibleName: tooltipText
                    enabled: !RcloneService.remotesLoading && !RcloneService.configBusy
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
                id: uploadRootField

                Layout.fillWidth: true
                labelText: qsTr("文件上传位置")
                text: "/" + UiPreferences.cloudUploadRoot
                error: root.cloudRootError(text) !== ""
                onAccepted: root.saveUploadRoot()
                onEditingFinished: root.saveUploadRoot()
            }

            MaterialFilledTextField {
                id: backupRootField

                Layout.fillWidth: true
                labelText: qsTr("电脑备份位置")
                text: "/" + UiPreferences.cloudBackupRoot
                error: root.cloudRootError(text) !== ""
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

            RowLayout {
                Layout.fillWidth: true
                Item {
                    Layout.fillWidth: true
                }
                IconButton {
                    iconName: "refresh"
                    tooltipText: qsTr("刷新模板")
                    onClicked: MatugenTemplateService.refresh()
                }
                ActionButton {
                    text: qsTr("添加")
                    iconName: "add"
                    enabled: !MatugenTemplateService.busy && PersonalizationConfig.ready
                    onClicked: templateAddWindow.showWindow()
                }
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: MatugenTemplateService.error !== ""
                tone: "error"
                message: MatugenTemplateService.error
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                visible: !templateAddWindow.visible && MatugenTemplateService.operationError !== ""
                tone: "error"
                message: MatugenTemplateService.operationError
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                visible: ThemeService.generationError !== "" || ThemeService.externalGenerationError !== ""
                tone: "error"
                message: ThemeService.generationError !== "" ? qsTr("Matugen 配色生成失败") : qsTr(
                                                                   "部分 Matugen 模板生成失败")
                StyledToolTip {
                    extraVisibleCondition: errorHover.hovered
                    text: ThemeService.generationError || ThemeService.externalGenerationError
                }
                HoverHandler {
                    id: errorHover
                }
            }

            Repeater {
                model: MatugenTemplateService.templates

                SettingsRow {
                    id: templateRow
                    required property var modelData

                    Layout.fillWidth: true
                    iconName: modelData.valid ? modelData.icon : "error"
                    title: modelData.title
                    supportingText: !modelData.valid ? modelData.error : modelData.origin === "user" ? qsTr(
                                                                                                           "用户模板") : ""

                    trailing: RowLayout {
                        IconButton {
                            visible: templateRow.modelData.hasPostHook
                            iconName: "terminal"
                            tooltipText: qsTr("每次生成后执行：%1").arg(templateRow.modelData.postHook)
                            onClicked: root.requestTemplateAction(templateRow.modelData, false)
                            enabled: templateRow.modelData.valid && !ThemeService.generating
                        }
                        IconButton {
                            visible: templateRow.modelData.origin === "user"
                            iconName: "folder_open"
                            tooltipText: qsTr("打开模板位置") + "\n" + templateRow.modelData.inputPath + "\n" + qsTr(
                                             "输出：%1").arg(templateRow.modelData.outputPath)
                            onClicked: MatugenTemplateService.openLocation(templateRow.modelData)
                        }
                        IconButton {
                            visible: templateRow.modelData.origin === "user"
                            iconName: "delete"
                            tooltipText: qsTr("删除模板")
                            enabled: !MatugenTemplateService.busy && !ThemeService.generating
                                     && PersonalizationConfig.ready
                            onClicked: root.requestTemplateAction(templateRow.modelData, true)
                        }
                        StyledSwitch {
                            enabled: templateRow.modelData.valid && !ThemeService.generating &&
                                     !MatugenTemplateService.busy && PersonalizationConfig.ready
                            checked: templateRow.modelData.valid
                                     && PersonalizationConfig.isMatugenTemplateEnabled(
                                         templateRow.modelData.id)
                            Accessible.name: qsTr("启用 %1 Matugen 模板").arg(templateRow.modelData.title)
                            onToggled: {
                                if (checked && templateRow.modelData.origin === "user"
                                        && templateRow.modelData.hasPostHook) {
                                    checked = Qt.binding(() => templateRow.modelData.valid
                                        && PersonalizationConfig.isMatugenTemplateEnabled(templateRow.modelData.id));
                                    root.requestTemplateAction(templateRow.modelData, false);
                                } else {
                                    ThemeService.setMatugenTemplateEnabled(templateRow.modelData.id, checked);
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }

    }

    MatugenTemplateAddWindow {
        id: templateAddWindow
        parentModal: root.parentModal
    }

    MaterialDialog {
        id: templateDialog
        anchors.centerIn: Overlay.overlay
        width: Math.min(480, root.width - 32)
        dialogTitle: root.pendingTemplate
            ? (root.deletingTemplate ? qsTr("删除“%1”？") : qsTr("启用“%1”？")).arg(root.pendingTemplate.title) : ""
        messageText: !root.pendingTemplate ? "" : root.deletingTemplate
            ? qsTr("删除模板及其注册信息，保留已生成的输出文件。")
            : qsTr("该命令会在每次 Matugen 重新生成主题后执行。仅启用可信模板。") + "\n\n" + root.pendingTemplate.postHook
        actionsComponent: Component {
            RowLayout {
                Item {
                    Layout.fillWidth: true
                }
                ActionButton {
                    text: qsTr("取消")
                    onClicked: templateDialog.close()
                }
                ActionButton {
                    text: root.deletingTemplate ? qsTr("删除") : qsTr("启用")
                    enabled: !MatugenTemplateService.busy && !ThemeService.generating
                             && PersonalizationConfig.ready
                    onClicked: {
                        if (root.pendingTemplate) {
                            if (root.deletingTemplate)
                                MatugenTemplateService.remove(root.pendingTemplate.id);
                            else
                                ThemeService.setMatugenTemplateEnabled(root.pendingTemplate.id, true);
                        }
                        templateDialog.close();
                    }
                }
            }
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
