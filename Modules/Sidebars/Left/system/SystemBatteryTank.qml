import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import M3Shapes
import qs.Common
import qs.Components
import "../../../../Common/functions/SystemFormat.js" as Format

Rectangle {
    id: root

    property var battery: ({})
    readonly property bool present: root.battery.present === true
    readonly property bool valueAvailable:
        root.present && Format.isNumber(root.battery.chargePercent)
    readonly property real targetLevel: root.valueAvailable
        ? Math.max(0, Math.min(1, root.battery.chargePercent / 100))
        : 0
    property real animatedLevel: targetLevel
    readonly property bool charging:
        String(root.battery.status || "").toLowerCase() === "charging"

    radius: Appearance.rounding.extraLarge
    color: Appearance.colors.colSecondaryContainer
    Accessible.name: "电池，"
        + (root.present
            ? Format.percent(root.battery.chargePercent, 0)
                + "，" + Format.batteryStatus(root.battery.status)
            : "未检测到电池")

    Behavior on animatedLevel {
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve:
                Appearance.animation.expressiveSlowSpatial.bezierCurve
        }
    }

    BatteryContents {
        anchors.fill: parent
        anchors.margins: Appearance.spacing.medium
        foregroundColor: Appearance.colors.colOnSecondaryContainer
        accentColor: Appearance.colors.colSecondary
    }

    // Item.clip is rectangular, so mask the liquid layer explicitly to the
    // Material rounded container at every charge level.
    Rectangle {
        id: roundedMask

        anchors.fill: parent
        radius: root.radius
        color: "white"
        visible: false
        layer.enabled: true
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: roundedMask
        }

        Item {
            id: levelClip

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: parent.height * root.animatedLevel
            clip: true

            Rectangle {
                width: root.width
                height: root.height
                y: levelClip.height - height
                color: Appearance.colors.colSecondary

                BatteryContents {
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.medium
                    foregroundColor: Appearance.colors.colOnSecondary
                    accentColor: Appearance.colors.colSecondaryContainer
                    Accessible.ignored: true
                }
            }
        }

        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: Appearance.spacing.small
            color: Appearance.colors.colPrimary
            opacity: root.charging ? 1 : 0.42
        }
    }

    component BatteryContents: Item {
        id: contents

        required property color foregroundColor
        required property color accentColor

        Text {
            anchors {
                left: parent.left
                top: parent.top
            }
            text: "电池"
            color: contents.foregroundColor
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeTitleSmall
            font.weight: Font.DemiBold
        }

        MaterialShape {
            anchors {
                top: parent.top
                right: parent.right
            }
            implicitSize: 44
            shape: root.charging
                ? MaterialShape.Sunny
                : MaterialShape.Cookie7Sided
            color: parent.accentColor
            animationDuration:
                Appearance.animation.expressiveSlowSpatial.duration
            animationEasing: Easing.OutBack

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.charging
                    ? "battery_charging_full"
                    : (root.present
                        ? "battery_full"
                        : "battery_unknown")
                iconSize: 22
                fill: 1
                color: contents.foregroundColor
            }
        }

        ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            visible: root.present
            spacing: Appearance.spacing.xSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    text: "schedule"
                    iconSize: 15
                    color: contents.foregroundColor
                }

                Text {
                    Layout.fillWidth: true
                    text: Format.isNumber(
                        root.battery.timeRemainingSeconds
                    )
                        ? Format.duration(
                            root.battery.timeRemainingSeconds
                        )
                        : "接通电源"
                    color: contents.foregroundColor
                    opacity: 0.78
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeLabelSmall
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    text: "electric_bolt"
                    iconSize: 15
                    color: contents.foregroundColor
                }

                Text {
                    Layout.fillWidth: true
                    text: Format.isNumber(root.battery.powerWatts)
                        ? Format.watts(root.battery.powerWatts)
                        : "功率未知"
                    color: contents.foregroundColor
                    opacity: 0.78
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeLabelSmall
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Format.isNumber(root.battery.healthPercent)
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    text: "health_and_safety"
                    iconSize: 15
                    color: contents.foregroundColor
                }

                Text {
                    Layout.fillWidth: true
                    text: "健康 "
                        + Format.percent(
                            root.battery.healthPercent,
                            0
                        )
                    color: contents.foregroundColor
                    opacity: 0.78
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeLabelSmall
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.present
            text: "未检测到\n电池"
            color: contents.foregroundColor
            opacity: 0.76
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeTitleSmall
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignRight
                text: root.present
                    ? Format.batteryStatus(root.battery.status)
                    : "不可用"
                color: contents.foregroundColor
                opacity: 0.74
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.typeBodySmall
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    visible: root.charging
                    text: "bolt"
                    iconSize: 24
                    fill: 1
                    color: contents.accentColor
                }

                Text {
                    text: root.present
                        ? Format.percent(root.battery.chargePercent, 0)
                        : "—"
                    color: contents.foregroundColor
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeHeadlineSmall
                    font.weight: Font.Bold
                }
            }
        }
    }
}
