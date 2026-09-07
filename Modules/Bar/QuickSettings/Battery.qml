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
    readonly property real percentage: root.valueAvailable ? Math.max(0, Math.min(100,
                                                                                  PowerService.percentage
                                                                                  * 100)) : NaN
    readonly property bool lowBattery: root.valueAvailable && root.percentage <= 15
                                       && PowerService.discharging

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
            return qsTr("Status: Fully charged");

        if (PowerService.charging)
            return Format.isNumber(PowerService.timeToFull) ? qsTr("Status: Charging · Full in ")
                                                              + Format.duration(PowerService.timeToFull) :
                                                              qsTr("Status: Charging · Time to full unknown");

        if (PowerService.discharging)
            return Format.isNumber(PowerService.timeToEmpty) ? qsTr("Status: Discharging · ")
                                                               + Format.duration(PowerService.timeToEmpty) :
                                                               qsTr("Status: Discharging · Remaining time unknown");

        if (PowerService.state === UPowerDeviceState.Empty)
            return qsTr("Status: Empty");

        if (PowerService.state === UPowerDeviceState.PendingCharge)
            return qsTr("Status: Pending charge");

        if (PowerService.state === UPowerDeviceState.PendingDischarge)
            return qsTr("Status: Pending discharge");

        return PowerService.powerConnected ? qsTr("Status: Plugged in, not charging") : qsTr(
                                                 "Status: Unknown");
    }

    function powerText() {
        const label = PowerService.charging ? qsTr("Live charging power: ") : PowerService.discharging ? qsTr(
                                                                                                             "Live discharging power: ") :
                                                                                                         qsTr("Live power: ");
        return label + (Format.isNumber(PowerService.changeRate) ? Format.watts(Math.abs(
                                                                                    PowerService.changeRate)) :
                                                                   qsTr("Unknown"));
    }

    function buildTooltip() {
        if (!PowerService.ready)
            return [qsTr("Detecting battery"), qsTr("UPower has not provided battery data yet"), qsTr(
                        "Plug status, power, and health are temporarily unavailable")].join("\n");

        if (!PowerService.present)
            return [qsTr("No battery detected"), qsTr("This device may not have a built-in battery"), qsTr(
                        "Plugged in: ") + (PowerService.powerConnected ? qsTr("Yes") : qsTr("No")), qsTr(
                        "Charge state, power, and health are unavailable")].join("\n");

        return [qsTr("Battery level: ") + Format.percent(root.percentage, 0), qsTr("Plugged in: ") + (PowerService.powerConnected
                                                                                                      ? qsTr("Yes") :
                                                                                                        qsTr("No")),
                root.stateAndTimeText(), root.powerText(), qsTr("Health: ") + (Format.isNumber(
                                                                                   PowerService.healthPercentage)
                                                                               ? Format.percent(
                                                                                     PowerService.healthPercentage,
                                                                                     0) : qsTr(
                                                                                     "Unknown"))].join("\n");
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
            width: batteryGlyph.width
            height: batteryGlyph.height

            BatteryGlyph {
                id: batteryGlyph

                showValue: true
                embeddedCharging: false
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
        spacing: 0

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 16
            height: 31

            BatteryGlyph {
                anchors.centerIn: parent
                rotation: -90
                showValue: false
                embeddedCharging: true
            }
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

    component BatteryGlyph: Item {
        id: glyphRoot

        required property bool showValue
        required property bool embeddedCharging

        width: 31
        height: 16

        Rectangle {
            id: glyphBody

            radius: 4
            color: root.valueAvailable ? root.foregroundColor : "transparent"
            border.width: root.valueAvailable ? 0 : 1
            border.color: root.foregroundColor

            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                right: glyphTerminal.left
                rightMargin: 1
            }

            Text {
                anchors.centerIn: parent
                visible: glyphRoot.showValue
                text: root.displayText
                color: root.valueAvailable ? root.containerColor : root.foregroundColor
                font.family: Fonts.expressive
                font.pixelSize: 11
                font.weight: Font.Bold
                font.hintingPreference: Font.PreferNoHinting
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: glyphRoot.embeddedCharging && PowerService.charging
                rotation: 90
                text: "bolt"
                iconSize: 12
                fill: 1
                color: root.valueAvailable ? root.containerColor : root.foregroundColor
            }
        }

        Rectangle {
            id: glyphTerminal

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
}
