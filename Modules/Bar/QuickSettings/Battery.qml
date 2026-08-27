import QtQuick
import Quickshell.Services.UPower
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    property bool vertical: false
    readonly property bool valueAvailable: PowerService.present && Format.isNumber(PowerService.percentage)
    readonly property real percentage: root.valueAvailable ? Math.max(0, Math.min(100, PowerService.percentage * 100)) : NaN
    readonly property bool lowBattery: root.valueAvailable && root.percentage <= 15 && PowerService.discharging
    readonly property string displayText: root.valueAvailable ? String(Math.round(root.percentage)) : "—"
    readonly property color containerColor: {
        if (!PowerService.ready || !PowerService.present)
            return Appearance.colors.colSurfaceContainerHigh;

        if (root.lowBattery)
            return Appearance.colors.colErrorContainer;

        if (PowerService.powerConnected)
            return Appearance.colors.colPrimaryContainer;

        return Appearance.colors.colSecondaryContainer;
    }
    readonly property color foregroundColor: {
        if (!PowerService.ready || !PowerService.present)
            return Appearance.colors.colOnSurfaceVariant;

        if (root.lowBattery)
            return Appearance.colors.colOnErrorContainer;

        if (PowerService.powerConnected)
            return Appearance.colors.colOnPrimaryContainer;

        return Appearance.colors.colOnSecondaryContainer;
    }
    readonly property string tooltipText: root.buildTooltip()

    function stateAndTimeText() {
        if (PowerService.full)
            return qsTr("状态：已充满");

        if (PowerService.charging)
            return Format.isNumber(PowerService.timeToFull) ? qsTr("状态：充电中 · 充满还需 ") + Format.duration(PowerService.timeToFull) : qsTr("状态：充电中 · 充满时间未知");

        if (PowerService.discharging)
            return Format.isNumber(PowerService.timeToEmpty) ? qsTr("状态：放电中 · 剩余 ") + Format.duration(PowerService.timeToEmpty) : qsTr("状态：放电中 · 剩余时间未知");

        if (PowerService.state === UPowerDeviceState.Empty)
            return qsTr("状态：电量已耗尽");

        if (PowerService.state === UPowerDeviceState.PendingCharge)
            return qsTr("状态：等待充电");

        if (PowerService.state === UPowerDeviceState.PendingDischarge)
            return qsTr("状态：等待放电");

        return PowerService.powerConnected ? qsTr("状态：已插电，未在充电") : qsTr("状态：未知");
    }

    function powerText() {
        const label = PowerService.charging ? qsTr("实时充电功率：") : PowerService.discharging ? qsTr("实时放电功率：") : qsTr("实时功率：");
        return label + (Format.isNumber(PowerService.changeRate) ? Format.watts(Math.abs(PowerService.changeRate)) : qsTr("未知"));
    }

    function buildTooltip() {
        if (!PowerService.ready)
            return [qsTr("正在检测电池"), qsTr("UPower 尚未提供电池数据"), qsTr("插电状态、功率与健康度暂不可用")].join("\n");

        if (!PowerService.present)
            return [qsTr("未检测到电池"), qsTr("此设备可能没有内置电池"), qsTr("插电：") + (PowerService.powerConnected ? qsTr("是") : qsTr("否")), qsTr("充放电状态、功率与健康度不可用")].join("\n");

        return [qsTr("电池电量：") + Format.percent(root.percentage, 0), qsTr("插电：") + (PowerService.powerConnected ? qsTr("是") : qsTr("否")), root.stateAndTimeText(), root.powerText(), qsTr("健康度：") + (Format.isNumber(PowerService.healthPercentage) ? Format.percent(PowerService.healthPercentage, 0) : qsTr("未知"))].join("\n");
    }

    implicitWidth: root.vertical ? Sizes.barControlCircleSize : 56
    implicitHeight: root.vertical ? 40 : Sizes.barControlCircleSize
    Accessible.name: root.tooltipText
    Accessible.role: Accessible.StaticText

    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: root.containerColor

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveEffects.duration
            }

        }

    }

    Row {
        anchors.centerIn: parent
        visible: !root.vertical
        spacing: 2

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 31
            height: 16

            Rectangle {
                id: batteryBody

                radius: 4
                color: root.valueAvailable ? root.foregroundColor : "transparent"
                border.width: root.valueAvailable ? 0 : 1
                border.color: root.foregroundColor

                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    right: batteryTerminal.left
                    rightMargin: 1
                }

                Text {
                    anchors.centerIn: parent
                    text: root.displayText
                    color: root.valueAvailable ? root.containerColor : root.foregroundColor
                    font.family: Fonts.expressive
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.hintingPreference: Font.PreferNoHinting
                }

            }

            Rectangle {
                id: batteryTerminal

                width: 3
                height: parent.height * 0.5
                radius: width / 2
                color: root.foregroundColor

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

            }

        }

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            visible: PowerService.charging
            width: visible ? 12 : 0
            height: width
            text: "bolt"
            iconSize: width
            fill: 1
            color: root.foregroundColor
        }

    }

    Column {
        anchors.centerIn: parent
        visible: root.vertical
        spacing: PowerService.charging ? 1 : 0

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 16
            height: 22

            Rectangle {
                id: verticalBatteryTerminal

                width: parent.width * 0.5
                height: 2
                radius: 1
                color: root.foregroundColor

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }

            }

            Rectangle {
                radius: 3
                color: root.valueAvailable ? root.foregroundColor : "transparent"
                border.width: root.valueAvailable ? 0 : 1
                border.color: root.foregroundColor

                anchors {
                    left: parent.left
                    right: parent.right
                    top: verticalBatteryTerminal.bottom
                    bottom: parent.bottom
                    topMargin: 1
                }

                Text {
                    anchors.centerIn: parent
                    text: root.displayText
                    color: root.valueAvailable ? root.containerColor : root.foregroundColor
                    font.family: Fonts.expressive
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    font.hintingPreference: Font.PreferNoHinting
                }

            }

        }

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: PowerService.charging
            width: visible ? 10 : 0
            height: width
            text: "bolt"
            iconSize: width
            fill: 1
            color: root.foregroundColor
        }

    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    PopupToolTip {
        extraVisibleCondition: hoverArea.containsMouse
        text: root.tooltipText
    }

}
