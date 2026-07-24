import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common
import "../../../ControlCenter" as ControlCenter
import "../../../../Common/functions/SystemFormat.js" as Format

Rectangle {
    id: root

    property var disks: []
    property int currentDiskIndex: 0
    property bool selectionInitialized: false
    readonly property var disk:
        root.disks.length > 0
            ? root.disks[Math.max(
                0,
                Math.min(root.currentDiskIndex, root.disks.length - 1)
            )]
            : ({})
    readonly property var diskOptions: {
        const options = [];
        for (let index = 0; index < root.disks.length; index += 1) {
            const disk = root.disks[index];
            options.push({
                "value": String(index),
                "label": String(
                    disk.mountPoint || disk.device || "存储设备"
                )
            });
        }
        return options;
    }
    readonly property bool valueAvailable:
        Format.isNumber(root.disk.usagePercent)
    readonly property real normalizedUsage: root.valueAvailable
        ? Math.max(0, Math.min(1, root.disk.usagePercent / 100))
        : 0

    function defaultDiskIndex() {
        for (let index = 0; index < root.disks.length; index += 1) {
            if (root.disks[index].mountPoint === "/")
                return index;
        }
        return 0;
    }

    onDisksChanged: {
        if (root.disks.length === 0) {
            root.currentDiskIndex = 0;
            root.selectionInitialized = false;
            return;
        }
        if (!root.selectionInitialized) {
            root.currentDiskIndex = root.defaultDiskIndex();
            root.selectionInitialized = true;
        } else if (root.currentDiskIndex >= root.disks.length) {
            root.currentDiskIndex = root.disks.length - 1;
        }
    }

    radius: Appearance.rounding.extraLarge
    color: Appearance.colors.colSurfaceContainer
    Accessible.name: "存储 "
        + String(root.disk.mountPoint || "")
        + "，" + Format.percent(root.disk.usagePercent, 0)
        + "，已使用 " + Format.bytes(root.disk.usedBytes)

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Appearance.spacing.xSmall
            rightMargin: Appearance.spacing.xSmall
        }
        spacing: Appearance.spacing.medium

        Item {
            Layout.preferredWidth: Math.min(
                root.height,
                root.width * 0.32
            )
            Layout.preferredHeight: width
            Layout.alignment: Qt.AlignVCenter

            ArcGauge {
                anchors.fill: parent
                value: root.normalizedUsage
                icon: ""
                progressColor: Appearance.colors.colSecondary
                trackColor:
                    Appearance.colors.colSecondaryContainer
                handleColor: Appearance.colors.colSecondary
                iconColor: Appearance.colors.colSecondary
                iconFont: Sizes.fontMaterialSymbols
                iconSize: 1
                arcRadius: (width - lineWidth) / 2 - 1
                lineWidth: 11
                gapAngle: 45
                handleSpacing: Appearance.spacing.small
                showHandle: false
                animDuration:
                    Appearance.animation.expressiveSlowSpatial.duration
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: -2

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "hard_drive"
                    color: Appearance.colors.colSecondary
                    iconSize: Sizes.typeTitleMedium
                    fill: 1
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Format.percent(
                        root.disk.usagePercent,
                        0
                    )
                    color: Appearance.colors.colSecondary
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeHeadlineSmall
                    font.weight: Font.Bold
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Used"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeLabelMedium
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.xSmall

            Item {
                Layout.fillHeight: true
            }

            Text {
                Layout.fillWidth: true
                text: "Storage"
                color: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.typeTitleLarge
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.disks.length > 0
                    ? Format.bytes(root.disk.usedBytes)
                        + " / "
                        + Format.bytes(root.disk.totalBytes)
                    : "未检测到存储盘"
                color: Appearance.colors.colSecondary
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.typeBodyLarge
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            ControlCenter.SplitMenuButton {
                id: diskSelector

                Layout.fillWidth: true
                Layout.preferredHeight: 42
                buttonHeight: 42
                minimumWidth: 190
                maximumWidth: 480
                menuMinimumWidth: Math.min(320, width)
                menuMaximumWidth: Math.max(320, width)
                model: root.diskOptions
                currentValue: String(root.currentDiskIndex)
                leadingIcon: "hard_drive"
                enabled: root.diskOptions.length > 0
                opacity: enabled ? 1 : 0.38
                buttonColor:
                    Appearance.colors.colSecondaryContainer
                buttonHoverColor:
                    Appearance.colors.colSecondaryContainerHover
                buttonPressedColor:
                    Appearance.colors.colSecondaryContainerActive
                buttonTextColor:
                    Appearance.colors.colOnSecondaryContainer
                Accessible.name: "选择存储盘"
                onValueSelected: value =>
                    root.currentDiskIndex = Number(value)
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
