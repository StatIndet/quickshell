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
    property bool refreshRequested: false
    property bool refreshConfirmed: false
    readonly property real pageContentWidth: 600
    readonly property var remoteOptions: RcloneService.remotes.map(remote => {
        return ({
                    "label": remote.name,
                    "value": remote.name,
                    "remoteName": remote.name,
                    "remoteType": remote.type,
                    "enabled": !RcloneService.isReadOnly(remote),
                    "tooltip": RcloneService.isReadOnly(remote) ? qsTr(
                                                                      "This cloud storage is read-only and cannot be set as default") :
                                                                  ""
                });
    })
    property var pendingDeleteTemplate: null

    function requestTemplateDeletion(template) {
        root.pendingDeleteTemplate = template;
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
            return qsTr(
                        "Enter a relative directory inside the remote; do not include a remote name or colon");

        const relative = raw.replace(/^\/+|\/+$/g, "");
        if (relative === "." || relative === "..")
            return qsTr("Enter a valid remote directory");

        return "";
    }

    function saveBackupRoot() {
        const error = root.cloudRootError(backupRootField.text);
        if (error !== "")
            return;

        UiPreferences.setCloudBackupRoot(backupRootField.text);
        backupRootField.text = "/" + UiPreferences.cloudBackupRoot;
    }

    function saveUploadRoot() {
        const error = root.cloudRootError(uploadRootField.text);
        if (error !== "")
            return;

        UiPreferences.setCloudUploadRoot(uploadRootField.text);
        uploadRootField.text = "/" + UiPreferences.cloudUploadRoot;
    }

    function refreshConfiguration() {
        if (RcloneService.remotesLoading)
            return;

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
                return;

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
            title: qsTr("Map and weather services")
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
            title: qsTr("Cloud storage")
            iconName: "cloud"

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS

                SearchSelectMenuField {
                    Layout.fillWidth: true
                    options: root.remoteOptions
                    value: RcloneService.selectedRemoteName
                    placeholder: qsTr("No cloud storage selected")
                    closeOnAccept: true
                    showCheckmark: false
                    fieldHeight: Metrics.controlHeightXL
                    itemHeight: Metrics.controlHeightXL
                    leadingWidth: Metrics.iconM
                    enabled: options.length > 0
                    onAccepted: value => {
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
                    iconName: RcloneService.remotesError !== "" && !RcloneService.remotesLoading
                              ? "sync_problem" : root.refreshConfirmed ? "check" : "refresh"
                    iconFill: root.refreshConfirmed ? 1 : 0
                    iconColor: RcloneService.remotesError !== "" && !RcloneService.remotesLoading
                               ? Appearance.colors.colError : root.refreshConfirmed
                                 ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    tooltipText: RcloneService.remotesLoading ? qsTr("Refreshing configuration") :
                                                                RcloneService.remotesError !== ""
                                                                ? RcloneService.remotesError :
                                                                  root.refreshConfirmed ? qsTr(
                                                                                              "Configuration refreshed") :
                                                                                          qsTr("Refresh configuration")
                    accessibleName: tooltipText
                    enabled: !RcloneService.remotesLoading && !RcloneService.configBusy
                    onClicked: root.refreshConfiguration()
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("View cloud storage")
                iconName: "cloud_queue"
                trailingIconName: "chevron_right"
                onClicked: cloudManager.showWindow()
            }

            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("Add cloud storage")
                iconName: "add"
                trailingIconName: "chevron_right"
                enabled: !RcloneService.configBusy
                onClicked: cloudWizard.showWindow()
            }

            MaterialFilledTextField {
                id: uploadRootField

                Layout.fillWidth: true
                labelText: qsTr("File upload location")
                text: "/" + UiPreferences.cloudUploadRoot
                error: root.cloudRootError(text) !== ""
                onAccepted: root.saveUploadRoot()
                onEditingFinished: root.saveUploadRoot()
            }

            MaterialFilledTextField {
                id: backupRootField

                Layout.fillWidth: true
                labelText: qsTr("Computer backup location")
                text: "/" + UiPreferences.cloudBackupRoot
                error: root.cloudRootError(text) !== ""
                onAccepted: root.saveBackupRoot()
                onEditingFinished: root.saveBackupRoot()
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Matugen template generation")

            Item {
                Layout.fillWidth: true
                implicitHeight: templateActions.implicitHeight

                InlineBusyIndicator {
                    anchors.right: templateActions.left
                    anchors.rightMargin: Metrics.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    width: implicitWidth
                    height: implicitHeight
                    busy: ThemeService.generating && ThemeService.generationTemplateId === ""
                }

                RowLayout {
                    id: templateActions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    IconButton {
                        iconName: "refresh"
                        tooltipText: qsTr("Refresh templates")
                        onClicked: MatugenTemplateService.refresh()
                    }
                    ActionButton {
                        text: qsTr("Add")
                        iconName: "add"
                        enabled: !MatugenTemplateService.busy && PersonalizationConfig.ready
                        onClicked: templateAddWindow.showWindow()
                    }
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
                message: ThemeService.generationError !== "" ? qsTr("Failed to generate Matugen colors") :
                                                               qsTr("Some Matugen templates failed to generate")
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
                                                                                                           "User templates") :
                                                                                                       ""

                    trailing: Item {
                        implicitWidth: templateRowActions.implicitWidth
                        implicitHeight: templateRowActions.implicitHeight

                        InlineBusyIndicator {
                            anchors.right: templateRowActions.left
                            anchors.rightMargin: Metrics.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            width: implicitWidth
                            height: implicitHeight
                            busy: templateRow.modelData.valid && ThemeService.generating
                                  && ThemeService.generationTemplateId === templateRow.modelData.id
                        }

                        RowLayout {
                            id: templateRowActions

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            Item {
                                visible: templateRow.modelData.hasPostHook
                                implicitWidth: Metrics.controlHeightM
                                implicitHeight: Metrics.controlHeightM
                                Accessible.role: Accessible.StaticText
                                Accessible.name: qsTr("Run after each generation: %1").arg(
                                                     templateRow.modelData.postHook)

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "terminal"
                                    iconSize: Metrics.iconM
                                    color: Appearance.colors.colOnSurfaceVariant
                                }
                                HoverHandler {
                                    id: hookHover
                                }
                                StyledToolTip {
                                    extraVisibleCondition: hookHover.hovered
                                    text: qsTr("Run after each generation:\n%1").arg(
                                              templateRow.modelData.postHook)
                                }
                            }
                            IconButton {
                                visible: templateRow.modelData.origin === "user"
                                iconName: "folder_open"
                                tooltipText: qsTr("Open template location") + "\n"
                                             + templateRow.modelData.inputPath + "\n" + qsTr("Output: %1").arg(
                                                 templateRow.modelData.outputPath)
                                onClicked: MatugenTemplateService.openLocation(templateRow.modelData)
                            }
                            IconButton {
                                visible: templateRow.modelData.origin === "user"
                                iconName: "delete"
                                tooltipText: qsTr("Delete template")
                                enabled: !MatugenTemplateService.busy && !ThemeService.generating
                                         && PersonalizationConfig.ready
                                onClicked: root.requestTemplateDeletion(templateRow.modelData)
                            }
                            StyledSwitch {
                                enabled: templateRow.modelData.valid && !ThemeService.generating &&
                                         !MatugenTemplateService.busy && PersonalizationConfig.ready
                                checked: templateRow.modelData.valid
                                         && PersonalizationConfig.isMatugenTemplateEnabled(
                                             templateRow.modelData.id)
                                Accessible.name: qsTr("Enable the %1 Matugen template").arg(
                                                     templateRow.modelData.title)
                                onToggled: ThemeService.setMatugenTemplateEnabled(templateRow.modelData.id,
                                                                                  checked)
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
        dialogTitle: root.pendingDeleteTemplate ? qsTr("Delete “%1”?").arg(root.pendingDeleteTemplate.title) :
                                                  ""
        messageText: qsTr("Delete the template and its registration. Keep generated output files.")
        onClosed: root.pendingDeleteTemplate = null
        actionsComponent: Component {
            RowLayout {
                Item {
                    Layout.fillWidth: true
                }
                ActionButton {
                    text: qsTr("Cancel")
                    onClicked: templateDialog.close()
                }
                ActionButton {
                    text: qsTr("Delete")
                    enabled: !MatugenTemplateService.busy && !ThemeService.generating
                             && PersonalizationConfig.ready
                    onClicked: {
                        if (root.pendingDeleteTemplate)
                            MatugenTemplateService.remove(root.pendingDeleteTemplate.id);
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
