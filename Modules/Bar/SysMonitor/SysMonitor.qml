import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common
import "../../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    property bool vertical: false
    property string ownerId: "bar-sysmonitor"
    readonly property bool isHovered: mouseArea.containsMouse
    readonly property var memory: SystemMonitorService.memory || ({
    })
    readonly property var cpu: SystemMonitorService.cpu || ({
    })
    readonly property var disk: Format.rootDisk(SystemMonitorService.disks)
    readonly property real memoryUsage: root.normalizedPercent(root.memory.usagePercent)
    readonly property real diskUsage: root.normalizedPercent(root.disk.usagePercent)
    readonly property real temperatureValue: Format.isNumber(root.cpu.packageTemperatureCelsius) ? root.cpu.packageTemperatureCelsius : root.cpu.temperatureCelsius
    readonly property real temperatureUsage: root.normalizedTemperature(root.temperatureValue)
    readonly property real cpuUsage: root.normalizedPercent(root.cpu.usagePercent)
    readonly property bool useFahrenheit: UiPreferences.systemTemperatureUnit === "fahrenheit"
    readonly property real displayTemperature: root.useFahrenheit && Format.isNumber(root.temperatureValue) ? root.temperatureValue * 9 / 5 + 32 : root.temperatureValue
    readonly property string memoryDisplayText: Format.number(root.memory.usagePercent, 0)
    readonly property string diskDisplayText: Format.number(root.disk.usagePercent, 0)
    readonly property string temperatureDisplayText: Format.number(root.displayTemperature, 0)
    readonly property string cpuDisplayText: Format.number(root.cpu.usagePercent, 0)
    // Match the ordinary circular controls in QuickSettings. Vertical bars
    // use the same circle geometry while intentionally hiding percentages.
    readonly property real horizontalIndicatorSize: Sizes.barControlCircleSize
    readonly property real verticalIndicatorSize: Sizes.barControlCircleSize
    readonly property real indicatorSize: root.vertical ? root.verticalIndicatorSize : root.horizontalIndicatorSize
    readonly property real indicatorIconSize: 15
    readonly property real indicatorSpacing: root.vertical ? Appearance.spacing.small : Appearance.spacing.xSmall
    readonly property string tooltipText: [qsTr("内存") + "    " + root.bytesPair(root.memory), qsTr("磁盘") + "    " + root.bytesPair(root.disk), qsTr("温度") + "    " + Format.temperature(root.temperatureValue, UiPreferences.systemTemperatureUnit === "fahrenheit"), qsTr("CPU") + "    " + Format.percent(root.cpu.usagePercent)].join("\n")

    function clamp(value) {
        const numeric = Number(value);
        if (!isFinite(numeric))
            return 0;

        return Math.max(0, Math.min(1, numeric));
    }

    function normalizedPercent(value) {
        return Format.isNumber(value) ? root.clamp(value / 100) : 0;
    }

    // CPU temperature uses the same 90 °C visual ceiling already used by the
    // lock-screen SystemGrid. Only its text is converted for presentation.
    function normalizedTemperature(value) {
        return Format.isNumber(value) ? root.clamp(value / 90) : 0;
    }

    function bytesPair(item) {
        const used = Format.bytes(item && item.usedBytes);
        const total = Format.bytes(item && item.totalBytes);
        return used === Format.unavailable() || total === Format.unavailable() ? Format.unavailable() : used + " / " + total;
    }

    implicitWidth: root.vertical ? Sizes.barVisualThickness : resourceLayout.implicitWidth + 2 * Sizes.barPillHorizontalPadding
    implicitHeight: root.vertical ? resourceLayout.implicitHeight + 2 * Sizes.barPillHorizontalPadding : Sizes.barPillThickness
    Component.onCompleted: SystemMonitorService.setConsumerModules(root.ownerId, ["cpu", "memory", "disk"])
    Component.onDestruction: SystemMonitorService.clearConsumer(root.ownerId)

    TopBarPillBackground {
        anchors.fill: parent
    }

    GridLayout {
        id: resourceLayout

        anchors.centerIn: parent
        rowSpacing: root.indicatorSpacing
        columnSpacing: root.indicatorSpacing
        columns: root.vertical ? 1 : 4

        ResourcePie {
            Layout.alignment: Qt.AlignCenter
            indicatorSize: root.indicatorSize
            iconSize: root.indicatorIconSize
            value: root.memoryUsage
            showText: !root.vertical
            displayText: root.memoryDisplayText
            icon: "memory_alt"
            fillColor: Appearance.colors.colPrimary
            trackColor: Appearance.colors.colPrimaryContainer
            iconColor: Appearance.colors.colOnPrimary
        }

        ResourcePie {
            Layout.alignment: Qt.AlignCenter
            indicatorSize: root.indicatorSize
            iconSize: root.indicatorIconSize
            value: root.diskUsage
            showText: !root.vertical
            displayText: root.diskDisplayText
            icon: "hard_drive"
            fillColor: Appearance.colors.colSecondary
            trackColor: Appearance.colors.colSecondaryContainer
            iconColor: Appearance.colors.colOnSecondary
        }

        ResourcePie {
            Layout.alignment: Qt.AlignCenter
            indicatorSize: root.indicatorSize
            iconSize: root.indicatorIconSize
            value: root.temperatureUsage
            showText: !root.vertical
            displayText: root.temperatureDisplayText
            icon: "thermostat"
            fillColor: Appearance.colors.colTertiary
            trackColor: Appearance.colors.colTertiaryContainer
            iconColor: Appearance.colors.colOnTertiary
        }

        ResourcePie {
            Layout.alignment: Qt.AlignCenter
            indicatorSize: root.indicatorSize
            iconSize: root.indicatorIconSize
            value: root.cpuUsage
            showText: !root.vertical
            displayText: root.cpuDisplayText
            icon: "developer_board"
            fillColor: Appearance.colors.colTertiary
            trackColor: Appearance.colors.colTertiaryContainer
            iconColor: Appearance.colors.colOnTertiary
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["gnome-system-monitor"])
    }

    PopupToolTip {
        extraVisibleCondition: root.isHovered
        text: root.tooltipText
    }

}
