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

    function showWindow() {
        root.sourcePath = "";
        idField.text = "";
        outputField.text = "";
        hookField.text = "";
        root.advanced = false;
        MatugenTemplateService.operationError = "";
        root.visible = true;
    }
    function dismiss() {
        picker.dismiss();
        root.visible = false;
    }

    visible: false
    parentWindow: root.parentModal
    title: qsTr("Add Matugen template")
    implicitWidth: 580
    implicitHeight: 640
    minimumSize: Qt.size(460, 480)
    color: "transparent"
    onClosed: root.dismiss()

    Connections {
        target: MatugenTemplateService
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
                title: qsTr("Add Matugen template")
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
                        text: qsTr("Template file")
                        description: root.sourcePath
                        iconName: "description"
                        trailingIconName: "folder_open"
                        onClicked: picker.openAt(Paths.homeDir)
                    }
                    MaterialFilledTextField {
                        id: idField
                        Layout.fillWidth: true
                        labelText: qsTr("Template ID")
                        error: text !== "" && !/^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*$/.test(text)
                    }
                    MaterialFilledTextField {
                        id: outputField
                        Layout.fillWidth: true
                        labelText: qsTr("Output path")
                    }
                    SettingsActionRow {
                        Layout.fillWidth: true
                        text: qsTr("Advanced options")
                        trailingIconName: root.advanced ? "expand_less" : "expand_more"
                        onClicked: root.advanced = !root.advanced
                    }
                    MaterialFilledTextField {
                        id: hookField
                        Layout.fillWidth: true
                        visible: root.advanced
                        labelText: qsTr("Run command after generation")
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.advanced
                        text: qsTr(
                                  "This command runs every time Matugen regenerates the theme. Only enable trusted templates.")
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
            Item {
                Layout.fillWidth: true
                implicitHeight: addActions.implicitHeight

                InlineBusyIndicator {
                    anchors.right: addActions.left
                    anchors.rightMargin: Metrics.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    width: implicitWidth
                    height: implicitHeight
                    busy: MatugenTemplateService.adding
                }

                RowLayout {
                    id: addActions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    ActionButton {
                        text: qsTr("Cancel")
                        enabled: !MatugenTemplateService.adding
                        onClicked: root.dismiss()
                    }
                    ActionButton {
                        text: qsTr("Add")
                        filled: true
                        enabled: !MatugenTemplateService.busy && root.sourcePath !== "" && idField.text !== ""
                                 && !idField.error && outputField.text.trim() !== ""
                        onClicked: MatugenTemplateService.add(idField.text, root.sourcePath, outputField.text,
                                                              hookField.text)
                    }
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
        dialogTitle: qsTr("Choose template file")
        description: ""
        windowIconName: "description"
        emptyStateText: qsTr("No files available")
        selectionPrompt: qsTr("Choose template file")
        formatSummary: ""
        onAccepted: (path, isDirectory) => {
            if (!isDirectory)
                root.sourcePath = path;
        }
    }
}
