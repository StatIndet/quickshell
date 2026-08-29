pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

FloatingWindow {
    id: root

    property var parentModal: null
    property var pendingDeleteRemote: null
    property string transientMessage: ""
    property string transientTone: "info"

    function showWindow() {
        if (!root.parentModal)
            return ;
        root.transientMessage = "";
        root.visible = true;
    }

    function dismiss() {
        deleteDialog.close();
        root.pendingDeleteRemote = null;
        root.visible = false;
    }

    function requestDelete(remote) {
        if (!remote || RcloneService.backupActive
                || RcloneService.configBusy)
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
            root.transientTone = "error";
            root.transientMessage = qsTr("无法开始删除云存储配置");
            messageTimer.restart();
        }
    }

    visible: false
    parentWindow: root.parentModal
    title: qsTr("管理云存储")
    implicitWidth: 620
    implicitHeight: 580
    minimumSize: Qt.size(500, 440)
    color: "transparent"
    onClosed: root.visible = false

    Connections {
        target: RcloneService

        function onRemoteDeleted(remoteName) {
            root.pendingDeleteRemote = null;
            root.transientTone = "info";
            root.transientMessage = qsTr("已删除云存储“%1”")
                .arg(remoteName);
            messageTimer.restart();
        }

        function onRemoteDeleteFailed(message) {
            root.transientTone = "error";
            root.transientMessage = message;
            messageTimer.restart();
        }
    }

    Timer {
        id: messageTimer

        interval: 3200
        onTriggered: root.transientMessage = ""
    }

    Rectangle {
        id: windowBackground

        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        color: BlurService.backgroundColor(
            Appearance.m3colors.m3surfaceContainerHigh)
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: windowBackground
        radius: windowBackground.radius
    }

    FocusScope {
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

            WizardHeader {
                Layout.fillWidth: true
                title: qsTr("管理云存储")
                onCloseRequested: root.dismiss()
            }

            ListView {
                id: remoteList

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Metrics.spacingXS
                model: RcloneService.remotes

                delegate: SettingsRow {
                    id: remoteRow

                    required property var modelData

                    width: ListView.view.width
                    title: RcloneService.providerDisplayName(
                        modelData.type, modelData.name)
                        + " — " + modelData.name
                    highlighted: RcloneService.selectedRemoteName
                        === modelData.name
                    leading: Component {
                        CloudProviderIcon {
                            remoteName: remoteRow.modelData.name
                            remoteType: remoteRow.modelData.type
                            iconSize: Metrics.iconL
                        }
                    }

                    trailing: RowLayout {
                        spacing: Metrics.spacingXS
                        opacity: rowHover.hovered
                            || setDefaultButton.visualFocus
                            || deleteButton.visualFocus ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation
                                    .expressiveFastEffects.duration
                                easing.type: Appearance.animation
                                    .expressiveFastEffects.type
                                easing.bezierCurve: Appearance.animation
                                    .expressiveFastEffects.bezierCurve
                            }
                        }

                        IconButton {
                            id: setDefaultButton

                            iconName: RcloneService.selectedRemoteName
                                === remoteRow.modelData.name
                                ? "check_circle" : "cloud_done"
                            iconFill: RcloneService.selectedRemoteName
                                === remoteRow.modelData.name ? 1 : 0
                            accessibleName: RcloneService.selectedRemoteName
                                === remoteRow.modelData.name
                                ? qsTr("当前默认云存储") : qsTr("设为默认")
                            enabled: RcloneService.selectedRemoteName
                                !== remoteRow.modelData.name
                                && !RcloneService.isReadOnly(
                                    remoteRow.modelData)
                                && !RcloneService.configBusy
                            onClicked: RcloneService.setDefaultRemote(
                                remoteRow.modelData.name)
                        }

                        IconButton {
                            id: deleteButton

                            iconName: "delete"
                            accessibleName: qsTr("删除")
                            iconColor: Appearance.colors.colError
                            enabled: !RcloneService.backupActive
                                && !RcloneService.configBusy
                            onClicked: root.requestDelete(
                                remoteRow.modelData)
                        }
                    }

                    HoverHandler {
                        id: rowHover
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: RcloneService.remotes.length === 0
                spacing: Metrics.spacingS

                Item { Layout.fillHeight: true }
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "cloud_off"
                    iconSize: Metrics.touchTarget
                    color: Appearance.colors.colOnSurfaceVariant
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("尚未配置云存储")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Typography.bodyLarge.family
                    font.pixelSize: Typography.bodyLarge.pixelSize
                    horizontalAlignment: Text.AlignHCenter
                }
                Item { Layout.fillHeight: true }
            }
        }

        InlineStatusBanner {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Metrics.spacingXL
            visible: opacity > 0
            opacity: root.transientMessage !== "" ? 1 : 0
            tone: root.transientTone
            message: root.transientMessage
            z: 10

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }
            }
        }
    }

    MaterialDialog {
        id: deleteDialog

        anchors.centerIn: Overlay.overlay
        width: Math.min(440, root.width - Metrics.spacingL * 2)
        dialogTitle: root.pendingDeleteRemote
            ? qsTr("删除“%1”？").arg(
                RcloneService.providerDisplayName(
                    root.pendingDeleteRemote.type,
                    root.pendingDeleteRemote.name))
            : qsTr("删除云存储")
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
}
