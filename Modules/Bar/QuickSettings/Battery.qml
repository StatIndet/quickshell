import QtQuick
import QtQuick.Layouts
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
    readonly property bool showValue: PersonalizationConfig.barShowValues
    readonly property color foregroundColor: root.lowBattery ? BarColors.error : BarColors.foreground

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

    implicitWidth: root.vertical ? Math.max(28, batteryContent.implicitWidth) : batteryContent.implicitWidth
                                   + 8
    implicitHeight: root.vertical ? Math.max(Sizes.barControlCircleSize, batteryContent.implicitHeight) :
                                    Sizes.barControlCircleSize
    Accessible.name: root.tooltipText
    Accessible.role: Accessible.StaticText

    GridLayout {
        id: batteryContent
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        rowSpacing: 4
        columnSpacing: Sizes.barLabelSpacing
        MaterialSymbol {
            Layout.preferredWidth: Sizes.barControlCircleSize
            Layout.preferredHeight: Sizes.barControlCircleSize
            Layout.alignment: Qt.AlignCenter
            text: !root.valueAvailable ? "battery_android_question" : PowerService.charging
                                         ? "battery_android_bolt" : root.percentage >= 95
                                           ? "battery_android_full" : "battery_android_" + Math.max(0,
                                                                                                    Math.min(6,
                                                                                                             Math.floor(
                                                                                                                 root.percentage
                                                                                                                 * 7 / 100)))
            iconSize: Sizes.barIconSize
            fill: 1
            color: root.foregroundColor
        }
        Text {
            Layout.alignment: Qt.AlignCenter
            visible: root.showValue
            text: root.valueAvailable ? root.displayText + "%" : root.displayText
            font.family: Fonts.numeric
            font.pixelSize: 12
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
