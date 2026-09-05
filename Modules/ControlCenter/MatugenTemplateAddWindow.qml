pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import qs.Modules.FilePicker

FloatingWindow {
    id: root

    property var parentModal: null
    property string sourcePath: ""
    property bool advanced: false
    property bool validated: false
    property string validatedDraft: ""
    readonly property string draft: JSON.stringify([idField.text, sourcePath, outputField.text,
                                                    hookField.text])

    function showWindow() {
        root.sourcePath = "";
        idField.text = "";
        outputField.text = "";
        hookField.text = "";
        root.advanced = false;
        root.validated = false;
        MatugenTemplateService.operationError = "";
        root.visible = true;
    }
    function dismiss() {
        picker.dismiss();
        root.visible = false;
    }

    visible: false
    parentWindow: root.parentModal
    title: qsTr("添加 Matugen 模板")
    implicitWidth: 580
    implicitHeight: 640
    minimumSize: Qt.size(460, 480)
    color: "transparent"
    onClosed: root.dismiss()
    onDraftChanged: root.validated = false

    Connections {
        target: MatugenTemplateService
        function onValidated(valid) {
            root.validated = valid && root.draft === root.validatedDraft;
        }
        function onAdded(templateId) {
            if (root.visible)
                root.dismiss();
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        color: BlurService.backgroundColor(Appearance.m3colors.m3surfaceContainerHigh)
    }
    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: background
        radius: background.radius
    }
    FocusScope {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.dismiss()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spacingXL
            spacing: Metrics.spacingM

            WizardHeader {
                Layout.fillWidth: true
                title: qsTr("添加 Matugen 模板")
                onCloseRequested: root.dismiss()
            }
            StyledFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: form.implicitHeight
                contentWidth: width

                ColumnLayout {
                    id: form
                    width: parent.width
                    spacing: Metrics.spacingM
                    enabled: !MatugenTemplateService.busy

                    SettingsActionRow {
                        Layout.fillWidth: true
                        text: qsTr("模板文件")
                        description: root.sourcePath
                        iconName: "description"
                        trailingIconName: "folder_open"
                        onClicked: picker.openAt(Paths.homeDir)
                    }
                    MaterialFilledTextField {
                        id: idField
                        Layout.fillWidth: true
                        labelText: qsTr("模板 ID")
                        error: text !== "" && !/^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*$/.test(text)
                    }
                    MaterialFilledTextField {
                        id: outputField
                        Layout.fillWidth: true
                        labelText: qsTr("输出路径")
                    }
                    SettingsActionRow {
                        Layout.fillWidth: true
                        text: qsTr("高级选项")
                        trailingIconName: root.advanced ? "expand_less" : "expand_more"
                        onClicked: root.advanced = !root.advanced
                    }
                    MaterialFilledTextField {
                        id: hookField
                        Layout.fillWidth: true
                        visible: root.advanced
                        labelText: qsTr("生成后执行命令")
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.advanced
                        text: qsTr("该命令会在每次 Matugen 重新生成主题后执行。仅启用可信模板。")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    InlineStatusBanner {
                        Layout.fillWidth: true
                        visible: MatugenTemplateService.operationError !== ""
                        tone: "error"
                        message: MatugenTemplateService.operationError
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Item {
                    Layout.fillWidth: true
                }
                ActionButton {
                    text: qsTr("验证")
                    iconName: root.validated ? "check" : ""
                    enabled: !MatugenTemplateService.busy && root.sourcePath !== "" && idField.text !== "" &&
                             !idField.error && outputField.text !== ""
                    onClicked: {
                        root.validatedDraft = root.draft;
                        MatugenTemplateService.validate(idField.text, root.sourcePath, outputField.text,
                                                        hookField.text);
                    }
                }
                ActionButton {
                    text: qsTr("添加")
                    filled: true
                    enabled: root.validated && !MatugenTemplateService.busy
                    onClicked: MatugenTemplateService.add(idField.text, root.sourcePath, outputField.text,
                                                          hookField.text)
                }
            }
        }
    }
    FilePickerWindow {
        id: picker
        parentModal: root
        requiresParentWindow: true
        selectionMode: FilePickerWindow.Files
        nameFilters: ["*"]
        dialogTitle: qsTr("选择模板文件")
        description: ""
        windowIconName: "description"
        emptyStateText: qsTr("没有可选择的文件")
        selectionPrompt: qsTr("选择模板文件")
        formatSummary: ""
        onAccepted: (path, isDirectory) => {
            if (!isDirectory)
                root.sourcePath = path;
        }
    }
}
