import "../../Common/functions/SystemFormat.js" as Format
import "./SystemCardCatalog.js" as CardCatalog
import M3Shapes
import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Components
import qs.Services

Item {
    id: root

    required property string tileId
    property bool active: true
    // A card may move between the sidebar and desktop without changing its
    // visual surface contract.  The first six cards retain the original
    // surface bindings; the remaining cards can opt into the shell-managed
    // surface introduced by the sidebar background work.
    property bool useShellManagedSurface: false
    readonly property var catalogEntry: CardCatalog.definitionFor(root.tileId)
    readonly property bool preserveDefaultSurface: root.catalogEntry !== null && root.catalogEntry.preserveDefaultSurface === true
    readonly property bool shellManagedSurface: root.useShellManagedSurface && !root.preserveDefaultSurface
    readonly property int chartUpdateInterval: Math.max(250, Number(SystemMonitorService.sourceIntervalMs) || SystemMonitorService.intervalMs)
    readonly property var primaryGpu: SystemMonitorService.selectedGpu
    readonly property var cpuTemperature: Format.isNumber(SystemMonitorService.cpu.packageTemperatureCelsius) ? SystemMonitorService.cpu.packageTemperatureCelsius : SystemMonitorService.cpu.temperatureCelsius
    readonly property var ioDisk: root.diskForDevice(UiPreferences.systemMonitorDiskDevice, true)
    readonly property var capacityDisk: UiPreferences.storageCapacityDiskDevice === "follow-io" ? root.ioDisk : root.diskForDevice(UiPreferences.storageCapacityDiskDevice, false)
    readonly property bool usesRectangularShadow: ["battery", "cpu", "gpu", "network", "storage", "calendar"].indexOf(root.tileId) >= 0
    readonly property int shadowShape: {
        switch (root.tileId) {
        case "memoryUsed":
            return MaterialShape.Slanted;
        case "wifi":
            return MaterialShape.Pentagon;
        case "storageCapacity":
            return MaterialShape.Cookie9Sided;
        default:
            return -1;
        }
    }
    readonly property color shadowSurfaceColor: {
        switch (root.tileId) {
        case "battery":
        case "gpu":
        case "storageCapacity":
            return root.surfaceColor(Appearance.m3colors.m3secondaryContainer, Appearance.colors.colSecondaryContainer);
        case "cpu":
        case "memoryUsed":
            return root.surfaceColor(Appearance.m3colors.m3primaryContainer, Appearance.colors.colPrimaryContainer);
        case "wifi":
            return root.surfaceColor(Appearance.m3colors.m3tertiaryContainer, Appearance.colors.colTertiaryContainer);
        case "network":
            return root.surfaceColor(Appearance.m3colors.m3primary, Appearance.colors.colPrimary);
        case "storage":
            return root.surfaceColor(Appearance.m3colors.m3tertiary, Appearance.colors.colTertiary);
        case "calendar":
            return root.surfaceColor(Appearance.m3colors.m3surfaceContainerHigh, Appearance.colors.colSurfaceContainerHigh);
        default:
            return Appearance.colors.colSurface;
        }
    }

    function normalizedPercent(value) {
        return Format.isNumber(value) ? Math.max(0, Math.min(1, value / 100)) : -1;
    }

    function diskForDevice(device, fallbackToFirst) {
        const wanted = String(device || "");
        for (let index = 0; index < SystemMonitorService.disks.length; index += 1) {
            const disk = SystemMonitorService.disks[index];
            if (String(disk.device || "") === wanted)
                return disk;

        }
        return fallbackToFirst && SystemMonitorService.disks.length > 0 ? SystemMonitorService.disks[0] : ({
        });
    }

    function surfaceColor(sidebarBaseColor, defaultColor) {
        const baseColor = root.shellManagedSurface ? sidebarBaseColor : defaultColor;
        return BlurService.solidBackgroundColor(baseColor);
    }

    function temperatureBadge(value) {
        return Format.isNumber(value) ? Math.round(UiPreferences.systemTemperature(value)) + "°" : "";
    }

    function cpuDetail() {
        const physical = SystemIdentityService.physicalCoreCount;
        const logical = SystemIdentityService.logicalCpuCount;
        if (physical > 0 && logical > 0)
            return physical + qsTr(" 核 · ") + logical + qsTr(" 线程");

        return qsTr("总体利用率");
    }

    function cpuSupporting() {
        const frequency = Format.frequencyMHz(SystemMonitorService.cpu.frequencyCurrentMHz);
        if (Format.isNumber(SystemMonitorService.cpu.powerWatts))
            return frequency + " · " + Format.watts(SystemMonitorService.cpu.powerWatts);

        return frequency;
    }

    function gpuSupporting() {
        if (SystemMonitorService.selectedGpuId === "")
            return qsTr("未检测到可用图形设备");

        const gpu = root.primaryGpu;
        if (Format.isNumber(gpu.vramUsedBytes) && Format.isNumber(gpu.vramTotalBytes))
            return Format.bytes(gpu.vramUsedBytes) + " / " + Format.bytes(gpu.vramTotalBytes);

        return Format.watts(gpu.powerWatts);
    }

    function componentFor(id) {
        switch (String(id)) {
        case "time":
            return timeComponent;
        case "battery":
            return batteryComponent;
        case "cpu":
            return cpuComponent;
        case "gpu":
            return gpuComponent;
        case "memoryUsed":
            return memoryUsedComponent;
        case "wifi":
            return wifiComponent;
        case "network":
            return networkComponent;
        case "storage":
            return storageComponent;
        case "storageCapacity":
            return storageCapacityComponent;
        case "calendar":
            return calendarComponent;
        case "weather":
            return weatherComponent;
        default:
            return null;
        }
    }

    Rectangle {
        id: rectangularShadowShape

        anchors.fill: parent
        visible: root.usesRectangularShadow
        radius: Appearance.rounding.extraLarge
        color: root.shadowSurfaceColor
        layer.enabled: visible

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.applyAlpha(Appearance.colors.colShadow, 0.4)
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }

    }

    MaterialShape {
        id: expressiveShadowShape

        anchors.centerIn: parent
        width: Math.max(72, Math.min(parent.width, parent.height) - Appearance.spacing.small)
        height: width
        visible: root.shadowShape >= 0
        shape: root.shadowShape
        color: root.shadowSurfaceColor
        layer.enabled: visible

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.applyAlpha(Appearance.colors.colShadow, 0.4)
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }

    }

    Loader {
        z: 1
        anchors.fill: parent
        sourceComponent: root.componentFor(root.tileId)
    }

    Component {
        id: timeComponent

        SystemClockCard {
            active: root.active
        }

    }

    Component {
        id: batteryComponent

        SystemBatteryTank {
            containerColor: root.surfaceColor(Appearance.m3colors.m3secondaryContainer, Appearance.colors.colSecondaryContainer)
            // The battery fill is data visualization, not the card surface;
            // keep it visible while the surrounding tank is transparent.
            levelColor: root.surfaceColor(Appearance.m3colors.m3secondary, Appearance.colors.colSecondary)
        }

    }

    Component {
        id: cpuComponent

        ExpressiveMetricTile {
            label: qsTr("CPU")
            iconName: "memory"
            detailText: root.cpuDetail()
            valueText: Format.percent(SystemMonitorService.cpu.usagePercent, 0)
            supportingText: root.cpuSupporting()
            temperatureText: root.temperatureBadge(root.cpuTemperature)
            usage: root.normalizedPercent(SystemMonitorService.cpu.usagePercent)
            trendValues: SystemMonitorService.cpuHistory
            chartActive: root.active
            updateInterval: root.chartUpdateInterval
            decorationSize: 50
            valueSize: Typography.headlineMedium.pixelSize
            containerColor: root.surfaceColor(Appearance.m3colors.m3primaryContainer, Appearance.colors.colPrimaryContainer)
            foregroundColor: Appearance.colors.colOnPrimaryContainer
            accentColor: Appearance.colors.colPrimary
            accentForegroundColor: Appearance.colors.colOnPrimary
        }

    }

    Component {
        id: gpuComponent

        ExpressiveMetricTile {
            label: qsTr("GPU")
            iconName: "developer_board"
            detailText: root.primaryGpu.name || qsTr("图形设备")
            valueText: SystemMonitorService.selectedGpuId !== "" ? Format.percent(root.primaryGpu.utilizationPercent, 0) : "—"
            supportingText: root.gpuSupporting()
            temperatureText: root.temperatureBadge(root.primaryGpu.temperatureCelsius)
            usage: SystemMonitorService.selectedGpuId !== "" ? root.normalizedPercent(root.primaryGpu.utilizationPercent) : -1
            trendValues: SystemMonitorService.gpuHistory
            chartActive: root.active
            updateInterval: root.chartUpdateInterval
            shapeOverride: MaterialShape.Gem
            decorationSize: 50
            valueSize: Typography.headlineMedium.pixelSize
            containerColor: root.surfaceColor(Appearance.m3colors.m3secondaryContainer, Appearance.colors.colSecondaryContainer)
            foregroundColor: Appearance.colors.colOnSecondaryContainer
            accentColor: Appearance.colors.colSecondary
            accentForegroundColor: Appearance.colors.colOnSecondary
        }

    }

    Component {
        id: memoryUsedComponent

        SystemLiquidMetricCard {
            iconName: "memory_alt"
            valueText: Format.percent(SystemMonitorService.memory.usagePercent, 0)
            supportingText: Format.bytes(SystemMonitorService.memory.usedBytes) + " / " + Format.bytes(SystemMonitorService.memory.totalBytes)
            level: root.normalizedPercent(SystemMonitorService.memory.usagePercent)
            valueAvailable: Format.isNumber(SystemMonitorService.memory.usagePercent)
            accessibilityName: qsTr("内存已使用 ") + Format.percent(SystemMonitorService.memory.usagePercent, 0) + "，" + Format.bytes(SystemMonitorService.memory.usedBytes) + " / " + Format.bytes(SystemMonitorService.memory.totalBytes)
            shapeId: MaterialShape.Slanted
            shapeColor: root.surfaceColor(Appearance.m3colors.m3primaryContainer, Appearance.colors.colPrimaryContainer)
            liquidColor: Appearance.applyAlpha(Appearance.colors.colTertiary, 0.66)
            contentColor: Appearance.colors.colOnPrimaryContainer
        }

    }

    Component {
        id: wifiComponent

        SystemLiquidMetricCard {
            iconName: NetworkService.wifiConnected ? "wifi" : "wifi_off"
            valueText: NetworkService.wifiConnected ? Format.percent(NetworkService.signalStrength, 0) : "—"
            supportingText: qsTr("Wi-Fi 信号强度")
            level: root.normalizedPercent(NetworkService.signalStrength)
            valueAvailable: NetworkService.wifiConnected
            accessibilityName: NetworkService.wifiConnected ? qsTr("Wi-Fi 信号强度 ") + Format.percent(NetworkService.signalStrength, 0) : qsTr("Wi-Fi 未连接")
            shapeId: MaterialShape.Pentagon
            shapeColor: root.surfaceColor(Appearance.m3colors.m3tertiaryContainer, Appearance.colors.colTertiaryContainer)
            liquidColor: Appearance.applyAlpha(Appearance.colors.colTertiary, 0.64)
            contentColor: Appearance.colors.colOnTertiaryContainer
        }

    }

    Component {
        id: networkComponent

        SystemNetworkCard {
            network: SystemMonitorService.network
            downloadHistory: SystemMonitorService.networkDownloadHistory
            uploadHistory: SystemMonitorService.networkUploadHistory
            chartActive: root.active
            updateInterval: root.chartUpdateInterval
            surfaceColor: root.surfaceColor(Appearance.m3colors.m3primary, Appearance.colors.colPrimary)
            panelColor: root.surfaceColor(Appearance.m3colors.m3primaryContainer, Appearance.colors.colPrimaryContainer)
        }

    }

    Component {
        id: storageComponent

        SystemStorageCard {
            disks: SystemMonitorService.disks
            readHistories: SystemMonitorService.diskReadHistories
            writeHistories: SystemMonitorService.diskWriteHistories
            preferredDiskDevice: UiPreferences.systemMonitorDiskDevice
            chartActive: root.active
            updateInterval: root.chartUpdateInterval
            surfaceColor: root.surfaceColor(Appearance.m3colors.m3tertiary, Appearance.colors.colTertiary)
            panelColor: root.surfaceColor(Appearance.m3colors.m3tertiaryContainer, Appearance.colors.colTertiaryContainer)
            onDiskSelected: (device) => {
                return UiPreferences.setSystemMonitorDiskDevice(device);
            }
        }

    }

    Component {
        id: storageCapacityComponent

        SystemLiquidMetricCard {
            readonly property bool diskAvailable: String(root.capacityDisk.device || "") !== ""
            readonly property bool capacityAvailable: diskAvailable && Format.isNumber(root.capacityDisk.usagePercent)

            iconName: "data_usage"
            valueText: capacityAvailable ? Format.percent(root.capacityDisk.usagePercent, 0) : "—"
            supportingText: diskAvailable ? Format.bytes(root.capacityDisk.usedBytes) + " / " + Format.bytes(root.capacityDisk.totalBytes) : qsTr("未检测到磁盘")
            level: root.normalizedPercent(root.capacityDisk.usagePercent)
            valueAvailable: capacityAvailable
            accessibilityName: diskAvailable ? qsTr("磁盘 %1，已使用 %2，共 %3，占用 %4").arg(String(root.capacityDisk.device), Format.bytes(root.capacityDisk.usedBytes), Format.bytes(root.capacityDisk.totalBytes), Format.percent(root.capacityDisk.usagePercent, 0)) : qsTr("未检测到磁盘")
            shapeId: MaterialShape.Cookie9Sided
            shapeColor: root.surfaceColor(Appearance.m3colors.m3secondaryContainer, Appearance.colors.colSecondaryContainer)
            liquidColor: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.66)
            contentColor: Appearance.colors.colOnSecondaryContainer
        }

    }

    Component {
        id: calendarComponent

        SystemCalendarCard {
            active: root.active
            surfaceColor: root.surfaceColor(Appearance.m3colors.m3surfaceContainerHigh, Appearance.colors.colSurfaceContainerHigh)
        }

    }

    Component {
        id: weatherComponent

        SystemWeatherCard {
        }

    }

}
