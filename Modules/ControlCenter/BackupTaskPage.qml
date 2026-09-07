import "../../Common/functions/SystemFormat.js" as Format
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    readonly property bool taskActive: RcloneService.backupActive
    readonly property bool checking: RcloneService.backupState === "running" && (RcloneService.backupPhase
                                                                                 === "preparing"
                                                                                 || RcloneService.backupPhase
                                                                                 === "checking")
    readonly property bool transferring: RcloneService.backupPhase === "transferring"
    readonly property bool terminal: ["success", "cancelled", "error"].indexOf(RcloneService.backupState) >= 0

    signal backRequested
    signal closeRequested
    signal stopRequested
    signal restartRequested

    function countText(value) {
        const number = Number(value);
        return isFinite(number) && number >= 0 ? Math.round(number).toLocaleString(Qt.locale(), "f", 0) : "—";
    }

    function folderPositionText() {
        if (RcloneService.backupTotalCount <= 0)
            return "";

        return qsTr("Folder %1 / %2").arg(RcloneService.backupCurrentIndex).arg(
                    RcloneService.backupTotalCount);
    }

    function checkingStatusText() {
        if (RcloneService.backupChecks > 0) {
            if (RcloneService.backupTotalChecks > 0)
                return qsTr("Checked %1 / %2").arg(countText(RcloneService.backupChecks)).arg(countText(
                                                                                                  RcloneService.backupTotalChecks));

            return qsTr("%1 items checked").arg(countText(RcloneService.backupChecks));
        }
        if (RcloneService.backupListed > 0)
            return qsTr("%1 items scanned").arg(countText(RcloneService.backupListed));

        return qsTr("Reading the file list…");
    }

    function taskTitle() {
        if (RcloneService.backupState === "stopping")
            return qsTr("Stopping backup…");

        if (RcloneService.backupPhase === "preparing")
            return qsTr("Preparing backup");

        if (RcloneService.backupPhase === "checking")
            return RcloneService.backupChecks > 0 ? qsTr("Checking files…") : qsTr("Scanning files…");

        return qsTr("Backing up");
    }

    function terminalTitle() {
        switch (RcloneService.backupState) {
        case "success":
            return qsTr("Backup complete");
        case "cancelled":
            return qsTr("Backup stopped");
        case "error":
            return qsTr("Backup failed");
        default:
            return "";
        }
    }

    function terminalIcon() {
        switch (RcloneService.backupState) {
        case "success":
            return "cloud_done";
        case "cancelled":
            return "stop_circle";
        case "error":
            return "error";
        default:
            return "backup";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingXL
        spacing: Metrics.spacingM

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingS

            IconButton {
                iconName: "arrow_back"
                accessibleName: qsTr("Back to backup settings")
                onClicked: root.backRequested()
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Computer backup")
                color: Appearance.colors.colOnSurface
                font.family: Typography.headlineSmall.family
                font.pixelSize: Typography.headlineSmall.pixelSize
                font.weight: Typography.headlineSmall.weight
            }

            IconButton {
                iconName: "close"
                accessibleName: qsTr("Close")
                onClicked: root.closeRequested()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.taskActive
            spacing: Metrics.spacingM

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: activeProgressContent.implicitHeight + Metrics.spacingL * 2
                radius: Appearance.rounding.large
                color: Appearance.colors.colPrimaryContainer

                ColumnLayout {
                    id: activeProgressContent

                    anchors.fill: parent
                    anchors.margins: Metrics.spacingL
                    spacing: Metrics.spacingS

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingM

                        MaterialLoadingIndicator {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            visible: root.checking || RcloneService.backupState === "stopping"
                            running: visible
                            contained: false
                            indicatorColor: Appearance.colors.colOnPrimaryContainer
                            accessibleName: root.taskTitle()
                        }

                        MaterialSymbol {
                            visible: !root.checking && RcloneService.backupState !== "stopping"
                            text: "cloud_upload"
                            iconSize: Metrics.iconL
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: root.taskTitle()
                                color: Appearance.colors.colOnPrimaryContainer
                                font.family: Typography.titleLarge.family
                                font.pixelSize: Typography.titleLarge.pixelSize
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: RcloneService.backupCurrentFolderName
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.78
                                font.family: Typography.bodyMedium.family
                                font.pixelSize: Typography.bodyMedium.pixelSize
                                elide: Text.ElideMiddle
                            }
                        }

                        Text {
                            text: root.folderPositionText()
                            color: Appearance.colors.colOnPrimaryContainer
                            font.family: Typography.labelLarge.family
                            font.pixelSize: Typography.labelLarge.pixelSize
                            font.weight: Typography.labelLarge.weight
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.transferring && RcloneService.backupTotalBytes > 0
                        spacing: Metrics.spacingXS

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 10
                            radius: Appearance.rounding.full
                            color: Appearance.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.22)

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, RcloneService.backupProgress))
                                height: parent.height
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: qsTr("%1%").arg(Math.round(RcloneService.backupProgress * 100))
                                color: Appearance.colors.colOnPrimaryContainer
                                font.family: Typography.titleMedium.family
                                font.pixelSize: Typography.titleMedium.pixelSize
                                font.weight: Font.DemiBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: qsTr("%1 / %2").arg(Format.bytes(RcloneService.backupBytes)).arg(
                                          Format.bytes(RcloneService.backupTotalBytes))
                                color: Appearance.colors.colOnPrimaryContainer
                                font.family: Typography.bodyMedium.family
                                font.pixelSize: Typography.bodyMedium.pixelSize
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.checking
                        text: root.checkingStatusText()
                        color: Appearance.colors.colOnPrimaryContainer
                        font.family: Typography.bodyMedium.family
                        font.pixelSize: Typography.bodyMedium.pixelSize
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.transferring
                columns: 2
                columnSpacing: Metrics.spacingXL
                rowSpacing: Metrics.spacingM

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXXS

                    Text {
                        text: qsTr("Transfer speed")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.labelMedium.family
                        font.pixelSize: Typography.labelMedium.pixelSize
                    }

                    Text {
                        text: Format.bytesPerSecond(RcloneService.backupSpeed)
                        color: Appearance.colors.colOnSurface
                        font.family: Typography.titleMedium.family
                        font.pixelSize: Typography.titleMedium.pixelSize
                        font.weight: Typography.titleMedium.weight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXXS

                    Text {
                        text: qsTr("Time remaining")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.labelMedium.family
                        font.pixelSize: Typography.labelMedium.pixelSize
                    }

                    Text {
                        text: RcloneService.backupEtaSeconds >= 0 ? qsTr("About %1").arg(Format.duration(
                                                                                             RcloneService.backupEtaSeconds)) :
                                                                    qsTr("Calculating")
                        color: Appearance.colors.colOnSurface
                        font.family: Typography.titleMedium.family
                        font.pixelSize: Typography.titleMedium.pixelSize
                        font.weight: Typography.titleMedium.weight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXXS

                    Text {
                        text: qsTr("Transferred")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.labelMedium.family
                        font.pixelSize: Typography.labelMedium.pixelSize
                    }

                    Text {
                        text: RcloneService.backupTotalTransfers >= 0 ? qsTr("%1 / %2").arg(root.countText(
                                                                                                RcloneService.backupTransfers)).arg(
                                                                            root.countText(
                                                                                RcloneService.backupTotalTransfers)) :
                                                                        root.countText(
                                                                            RcloneService.backupTransfers)
                        color: Appearance.colors.colOnSurface
                        font.family: Typography.titleMedium.family
                        font.pixelSize: Typography.titleMedium.pixelSize
                        font.weight: Typography.titleMedium.weight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXXS

                    Text {
                        text: qsTr("Checked")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.labelMedium.family
                        font.pixelSize: Typography.labelMedium.pixelSize
                    }

                    Text {
                        text: RcloneService.backupTotalChecks >= 0 ? qsTr("%1 / %2").arg(root.countText(
                                                                                             RcloneService.backupChecks)).arg(
                                                                         root.countText(
                                                                             RcloneService.backupTotalChecks)) :
                                                                     root.countText(
                                                                         RcloneService.backupChecks)
                        color: Appearance.colors.colOnSurface
                        font.family: Typography.titleMedium.family
                        font.pixelSize: Typography.titleMedium.pixelSize
                        font.weight: Typography.titleMedium.weight
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.transferring && RcloneService.backupErrors > 0
                text: qsTr("Errors %1").arg(root.countText(RcloneService.backupErrors))
                color: Appearance.colors.colError
                font.family: Typography.bodyMedium.family
                font.pixelSize: Typography.bodyMedium.pixelSize
                font.weight: Font.Medium
            }

            Text {
                Layout.fillWidth: true
                visible: root.transferring
                text: qsTr("Current transfers")
                color: Appearance.colors.colOnSurface
                font.family: Typography.titleMedium.family
                font.pixelSize: Typography.titleMedium.pixelSize
                font.weight: Typography.titleMedium.weight
            }

            ListView {
                id: transferList

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.transferring && RcloneService.backupTransferring.length > 0
                clip: true
                spacing: Metrics.spacingXS
                model: RcloneService.backupTransferring

                delegate: Rectangle {
                    id: transferRow

                    required property var modelData

                    width: ListView.view ? ListView.view.width : 0
                    height: 54
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colSurfaceContainerHighest

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Metrics.spacingS
                        spacing: Metrics.spacingXS

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: transferRow.modelData.name
                                color: Appearance.colors.colOnSurface
                                font.family: Typography.bodyMedium.family
                                font.pixelSize: Typography.bodyMedium.pixelSize
                                elide: Text.ElideMiddle
                            }

                            Text {
                                visible: transferRow.modelData.percentage >= 0
                                text: qsTr("%1%").arg(Math.round(transferRow.modelData.percentage))
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Typography.labelMedium.family
                                font.pixelSize: Typography.labelMedium.pixelSize
                                font.weight: Typography.labelMedium.weight
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            visible: transferRow.modelData.percentage >= 0
                            radius: Appearance.rounding.full
                            color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.2)

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1,
                                                                           transferRow.modelData.percentage
                                                                           / 100))
                                height: parent.height
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: root.transferring && RcloneService.backupTransferring.length === 0
                visible: root.transferring && RcloneService.backupTransferring.length === 0
                text: qsTr("Waiting for the next transfer…")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.bodyMedium.family
                font.pixelSize: Typography.bodyMedium.pixelSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Item {
                Layout.fillHeight: root.checking
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    text: RcloneService.backupState === "stopping" ? qsTr("Stopping") : qsTr("Stop backup")
                    iconName: "stop_circle"
                    enabled: RcloneService.backupState === "running"
                    onClicked: root.stopRequested()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.terminal
            spacing: Metrics.spacingL

            Item {
                Layout.fillHeight: true
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 88
                Layout.preferredHeight: 88
                radius: Appearance.rounding.full
                color: RcloneService.backupState === "error" ? Appearance.colors.colErrorContainer :
                                                               Appearance.colors.colSecondaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.terminalIcon()
                    iconSize: 48
                    fill: 1
                    color: RcloneService.backupState === "error" ? Appearance.colors.colOnErrorContainer :
                                                                   Appearance.colors.colOnSecondaryContainer
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.terminalTitle()
                color: Appearance.colors.colOnSurface
                font.family: Typography.headlineSmall.family
                font.pixelSize: Typography.headlineSmall.pixelSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                visible: RcloneService.backupState === "error"
                text: RcloneService.backupErrorMessage
                color: Appearance.colors.colError
                font.family: Typography.bodyMedium.family
                font.pixelSize: Typography.bodyMedium.pixelSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: RcloneService.backupState === "cancelled"
                text: qsTr("Files already synchronized to the remote will be retained.")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.bodyMedium.family
                font.pixelSize: Typography.bodyMedium.pixelSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: RcloneService.backupState === "success"
                text: qsTr("%1 · %2 files synchronized").arg(Format.bytes(
                                                                 RcloneService.backupCompletedBytes)).arg(
                          root.countText(RcloneService.backupCompletedTransfers))
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.titleMedium.family
                font.pixelSize: Typography.titleMedium.pixelSize
                font.weight: Typography.titleMedium.weight
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                visible: RcloneService.backupElapsedSeconds > 0
                text: qsTr("Elapsed %1").arg(Format.duration(RcloneService.backupElapsedSeconds))
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.bodyMedium.family
                font.pixelSize: Typography.bodyMedium.pixelSize
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    text: qsTr("Back")
                    iconName: "arrow_back"
                    onClicked: root.backRequested()
                }

                ActionButton {
                    visible: RcloneService.backupState === "cancelled" || RcloneService.backupState
                             === "error"
                    text: RcloneService.backupState === "error" ? qsTr("Retry") : qsTr("Start again")
                    iconName: "refresh"
                    filled: true
                    onClicked: root.restartRequested()
                }
            }
        }
    }
}
