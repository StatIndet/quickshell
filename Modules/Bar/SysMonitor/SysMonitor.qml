import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common
import "../../../Common/functions/SystemFormat.js" as Format

TopBarPill {
    id: root
    property bool flatIndicators: false

    property bool vertical: false
    property bool showValues: true
    property string ownerId: "bar-sysmonitor"
    readonly property bool isHovered: mouseArea.pointerHovered
    readonly property var memory: SystemMonitorService.memory || ({})
    readonly property var cpu: SystemMonitorService.cpu || ({})
    readonly property var disk: Format.rootDisk(SystemMonitorService.disks)
    readonly property real memoryUsage: root.normalizedPercent(root.memory.usagePercent)
    readonly property real diskUsage: root.normalizedPercent(root.disk.usagePercent)
    readonly property real temperatureValue: Format.isNumber(root.cpu.packageTemperatureCelsius)
                                             ? root.cpu.packageTemperatureCelsius :
                                               root.cpu.temperatureCelsius
    readonly property real temperatureUsage: root.normalizedTemperature(root.temperatureValue)
    readonly property real cpuUsage: root.normalizedPercent(root.cpu.usagePercent)
    readonly property bool useFahrenheit: UiPreferences.systemTemperatureUnit === "fahrenheit"
    readonly property real displayTemperature: root.useFahrenheit && Format.isNumber(root.temperatureValue)
                                               ? root.temperatureValue * 9 / 5 + 32 : root.temperatureValue
    readonly property string memoryDisplayText: Format.number(root.memory.usagePercent, 0)
    readonly property string diskDisplayText: Format.number(root.disk.usagePercent, 0)
    readonly property string temperatureDisplayText: Format.number(root.displayTemperature, 0)
    readonly property string cpuDisplayText: Format.number(root.cpu.usagePercent, 0)
    // Match the ordinary circular controls in QuickSettings.
    readonly property real horizontalIndicatorSize: Sizes.barControlCircleSize
    readonly property real verticalIndicatorSize: Sizes.barControlCircleSize
    readonly property real indicatorSize: root.vertical ? root.verticalIndicatorSize :
                                                          root.horizontalIndicatorSize
    readonly property real indicatorIconSize: 15
    readonly property real indicatorSpacing: Sizes.barItemSpacing + (root.showValues ? 0 : Metrics.spacingXXS)

    readonly property string tooltipText: [qsTr("Memory") + "    " + root.bytesPair(root.memory), qsTr("Disk")
        + "    " + root.bytesPair(root.disk), qsTr("Temperature") + "    " + Format.temperature(root.temperatureValue,
                                                                                                UiPreferences.systemTemperatureUnit
                                                                                                === "fahrenheit"),
        qsTr("CPU") + "    " + Format.percent(root.cpu.usagePercent)].join("\n")

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
        return used === Format.unavailable() || total === Format.unavailable() ? Format.unavailable() : used
                                                                                 + " / " + total;
    }

    implicitWidth: root.vertical ? root.pillThickness : mouseArea.implicitWidth
    implicitHeight: root.vertical ? mouseArea.implicitHeight : root.pillThickness
    Component.onCompleted: SystemMonitorService.setConsumerModules(root.ownerId, ["cpu", "memory", "disk"])
    Component.onDestruction: SystemMonitorService.clearConsumer(root.ownerId)

    BarActionButton {
        id: mouseArea

        anchors.fill: parent
        vertical: root.vertical
        contentPadding: root.pillPadding + 2
        contentItem: Item {
            implicitWidth: resourceLayout.implicitWidth
            implicitHeight: resourceLayout.implicitHeight
            GridLayout {
                id: resourceLayout

                anchors.centerIn: parent
                rowSpacing: root.indicatorSpacing
                columnSpacing: root.indicatorSpacing
                columns: root.vertical ? 1 : 4

                ResourcePie {
                    flat: root.flatIndicators
                    Layout.alignment: Qt.AlignCenter
                    indicatorSize: root.indicatorSize
                    iconSize: root.indicatorIconSize
                    value: root.memoryUsage
                    showText: root.showValues
                    vertical: root.vertical
                    displayText: root.memoryDisplayText
                    icon: "memory_alt"
                    fillColor: BarColors.selected
                    trackColor: BarColors.indicatorTrack
                    iconColor: BarColors.onIndicator
                }

                ResourcePie {
                    flat: root.flatIndicators
                    Layout.alignment: Qt.AlignCenter
                    indicatorSize: root.indicatorSize
                    iconSize: root.indicatorIconSize
                    value: root.diskUsage
                    showText: root.showValues
                    vertical: root.vertical
                    displayText: root.diskDisplayText
                    icon: "hard_drive"
                    fillColor: BarColors.selected
                    trackColor: BarColors.indicatorTrack
                    iconColor: BarColors.onIndicator
                }

                ResourcePie {
                    flat: root.flatIndicators
                    Layout.alignment: Qt.AlignCenter
                    indicatorSize: root.indicatorSize
                    iconSize: root.indicatorIconSize
                    value: root.temperatureUsage
                    showText: root.showValues
                    vertical: root.vertical
                    displayText: root.temperatureDisplayText
                    icon: "thermostat"
                    fillColor: BarColors.selected
                    trackColor: BarColors.indicatorTrack
                    iconColor: BarColors.onIndicator
                }

                ResourcePie {
                    flat: root.flatIndicators
                    Layout.alignment: Qt.AlignCenter
                    indicatorSize: root.indicatorSize
                    iconSize: root.indicatorIconSize
                    value: root.cpuUsage
                    showText: root.showValues
                    vertical: root.vertical
                    displayText: root.cpuDisplayText
                    icon: "developer_board"
                    fillColor: BarColors.selected
                    trackColor: BarColors.indicatorTrack
                    iconColor: BarColors.onIndicator
                }
            }
        }
        Accessible.name: root.tooltipText
        onClicked: ApplicationService.launchCommand(["gnome-system-monitor"])
    }

    PopupToolTip {
        extraVisibleCondition: root.isHovered
        text: root.tooltipText
    }
}
