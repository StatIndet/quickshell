import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components
import qs.Services
import "../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    property color containerColor: Appearance.colors.colSecondaryContainer
    property color levelColor: Appearance.colors.colSecondary
    readonly property bool present: PowerService.present
    readonly property bool valueAvailable: root.present && Format.isNumber(PowerService.percentage)
    readonly property real chargePercent: root.valueAvailable ? PowerService.percentage * 100 : NaN
    readonly property real targetLevel: root.valueAvailable ? Math.max(0, Math.min(1, PowerService.percentage)) : 0
    property real animatedLevel: targetLevel
    readonly property bool charging: PowerService.charging
    readonly property bool full: PowerService.full || (root.valueAvailable && root.chargePercent >= 100 && !root.charging)
    readonly property bool powerConnected: PowerService.powerConnected
    readonly property bool lowBattery: root.valueAvailable && root.chargePercent <= 15 && !root.powerConnected
    readonly property real batteryIconCenterY: Appearance.spacing.medium + 18
    readonly property bool batteryIconCovered: root.animatedLevel >= 1 - root.batteryIconCenterY / Math.max(1, batteryBody.height)
    readonly property real bodyRadius: Math.min(Appearance.rounding.extraLarge, batteryBody.width * 0.16)

    function batteryIconName() {
        if (!root.present || !root.valueAvailable)
            return "battery_unknown";

        const percent = root.chargePercent;
        if (root.charging) {
            if (percent <= 15)
                return "battery_charging_20";

            if (percent <= 35)
                return "battery_charging_30";

            if (percent <= 55)
                return "battery_charging_50";

            if (percent <= 70)
                return "battery_charging_60";

            if (percent <= 85)
                return "battery_charging_80";

            if (percent <= 95)
                return "battery_charging_90";

            return "battery_charging_full";
        }
        if (percent <= 5)
            return "battery_0_bar";

        if (percent <= 15)
            return "battery_1_bar";

        if (percent <= 30)
            return "battery_2_bar";

        if (percent <= 45)
            return "battery_3_bar";

        if (percent <= 60)
            return "battery_4_bar";

        if (percent <= 75)
            return "battery_5_bar";

        if (percent <= 90)
            return "battery_6_bar";

        return "battery_full";
    }

    function timingText() {
        if (root.full)
            return "—";

        if (root.charging)
            return Format.isNumber(PowerService.timeToFull) ? qsTr("充满还需 ") + Format.duration(PowerService.timeToFull) : qsTr("充满时长未知");

        if (PowerService.discharging || !root.powerConnected)
            return Format.isNumber(PowerService.timeToEmpty) ? qsTr("耗电时长 ") + Format.duration(PowerService.timeToEmpty) : qsTr("耗电时长未知");

        return qsTr("已接通电源，未在充电");
    }

    function statusText() {
        if (!root.present)
            return qsTr("不可用");

        if (root.full)
            return qsTr("已充满");

        if (root.charging)
            return qsTr("充电中");

        if (PowerService.discharging)
            return qsTr("放电中");

        return root.powerConnected ? qsTr("已接通电源") : qsTr("状态未知");
    }

    Accessible.name: qsTr("电池，") + (root.present ? Format.percent(root.chargePercent, 0) + "，" + root.statusText() + "，" + (root.powerConnected ? qsTr("已接通电源") : qsTr("未接通电源")) : qsTr("未检测到电池"))

    Rectangle {
        id: bodyShadow

        anchors.fill: batteryBody
        radius: root.bodyRadius
        color: root.containerColor
        layer.enabled: true

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.applyAlpha(Appearance.colors.colShadow, 0.4)
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            autoPaddingEnabled: true
        }

    }

    Rectangle {
        id: batteryTerminalOuter

        width: Math.max(34, Math.min(54, parent.width * 0.3))
        height: 12
        radius: 6
        color: Appearance.colors.colOutline

        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            radius: Math.max(1, parent.radius - 2)
            color: root.containerColor

            anchors {
                fill: parent
                margins: 2
                bottomMargin: 0
            }

        }

    }

    Rectangle {
        id: batteryBody

        radius: root.bodyRadius
        color: root.containerColor
        border.width: 2
        border.color: Appearance.applyAlpha(Appearance.colors.colOutline, 0.82)

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: 3
            rightMargin: 3
            topMargin: 8
            bottomMargin: 2
        }

    }

    Rectangle {
        parent: batteryBody
        z: 3
        radius: Math.max(1, batteryBody.radius - 5)
        color: "transparent"
        border.width: 1
        border.color: Appearance.applyAlpha(Appearance.colors.colOnSecondaryContainer, 0.2)

        anchors {
            fill: parent
            margins: 5
        }

    }

    BatteryContents {
        parent: batteryBody
        z: 1
        anchors.fill: parent
        anchors.margins: Appearance.spacing.medium
        foregroundColor: Appearance.colors.colOnSecondaryContainer
    }

    // Item.clip is rectangular, so mask the liquid layer explicitly to the
    // Material rounded container at every charge level.
    Rectangle {
        id: roundedMask

        parent: batteryBody
        anchors.fill: parent
        radius: batteryBody.radius
        color: "white"
        visible: false
        layer.enabled: true
    }

    Item {
        parent: batteryBody
        z: 2
        anchors.fill: parent
        layer.enabled: true

        Item {
            id: levelClip

            height: parent.height * root.animatedLevel
            clip: true

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            Rectangle {
                width: batteryBody.width
                height: batteryBody.height
                y: levelClip.height - height
                color: root.levelColor

                BatteryContents {
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.medium
                    foregroundColor: Appearance.colors.colOnSecondary
                    Accessible.ignored: true
                }

            }

        }

        layer.effect: OpacityMask {
            maskSource: roundedMask
        }

    }

    MaterialSymbol {
        parent: batteryBody
        z: 4
        text: root.batteryIconName()
        iconSize: 36
        fill: 1
        color: {
            if (root.batteryIconCovered)
                return Appearance.colors.colOnSecondary;

            if (!root.present)
                return Appearance.colors.colOnSecondaryContainer;

            if (root.lowBattery)
                return Appearance.colors.colError;

            if (root.powerConnected)
                return Appearance.colors.colPrimary;

            return Appearance.colors.colSecondary;
        }

        anchors {
            top: parent.top
            right: parent.right
            margins: Appearance.spacing.medium
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveEffects.duration
            }

        }

    }

    Behavior on animatedLevel {
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveSlowSpatial.bezierCurve
        }

    }

    component BatteryContents: Item {
        id: contents

        required property color foregroundColor

        Text {
            text: qsTr("电池")
            color: contents.foregroundColor
            font.family: Fonts.ui
            font.pixelSize: Typography.titleSmall.pixelSize
            font.weight: Font.DemiBold

            anchors {
                left: parent.left
                top: parent.top
            }

        }

        ColumnLayout {
            visible: root.present
            spacing: Appearance.spacing.xSmall

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    text: "schedule"
                    iconSize: 15
                    fill: 0
                    color: contents.foregroundColor
                }

                Text {
                    Layout.fillWidth: true
                    text: root.timingText()
                    color: contents.foregroundColor
                    opacity: 0.78
                    font.family: Fonts.ui
                    font.pixelSize: Typography.labelSmall.pixelSize
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
                    text: Format.isNumber(PowerService.changeRate) ? (root.powerConnected ? (root.charging ? qsTr("充电 ") : qsTr("功率 ")) : qsTr("放电 ")) + Format.watts(Math.abs(PowerService.changeRate)) : qsTr("功率未知")
                    color: contents.foregroundColor
                    opacity: 0.78
                    font.family: Fonts.numeric
                    font.pixelSize: Typography.labelSmall.pixelSize
                    elide: Text.ElideRight
                }

            }

            RowLayout {
                Layout.fillWidth: true
                visible: Format.isNumber(PowerService.healthPercentage)
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    text: "health_and_safety"
                    iconSize: 15
                    color: contents.foregroundColor
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("健康 ") + Format.percent(PowerService.healthPercentage, 0)
                    color: contents.foregroundColor
                    opacity: 0.78
                    font.family: Fonts.ui
                    font.pixelSize: Typography.labelSmall.pixelSize
                    elide: Text.ElideRight
                }

            }

        }

        Text {
            anchors.centerIn: parent
            visible: !root.present
            text: qsTr("未检测到\n电池")
            color: contents.foregroundColor
            opacity: 0.76
            font.family: Fonts.ui
            font.pixelSize: Typography.titleSmall.pixelSize
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            spacing: 0

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            Text {
                Layout.alignment: Qt.AlignRight
                text: root.present ? root.statusText() : qsTr("不可用")
                color: contents.foregroundColor
                opacity: 0.74
                font.family: Fonts.ui
                font.pixelSize: Typography.bodySmall.pixelSize
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: Appearance.spacing.xSmall

                Item {
                    Layout.fillWidth: true
                }

                MaterialSymbol {
                    text: root.powerConnected ? "power" : "power_off"
                    iconSize: 22
                    fill: 1
                    color: contents.foregroundColor
                }

                Text {
                    text: root.present ? Format.percent(root.chargePercent, 0) : "—"
                    color: contents.foregroundColor
                    font.family: Fonts.numeric
                    font.pixelSize: Typography.headlineSmall.pixelSize
                    font.weight: Font.Bold
                }

            }

        }

    }

}
