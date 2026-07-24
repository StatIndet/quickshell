import QtQuick
import M3Shapes
import qs.Common
import qs.Services
import qs.Widgets.common
import "./system"
import "./system/SystemGridLayout.js" as GridLayout
import "../../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    readonly property bool isForeground: root.visible
        && WidgetState.leftSidebarOpen
        && WidgetState.leftSidebarView === "sys"
    readonly property int gridColumns: GridLayout.columnCount
    readonly property int gridRows: GridLayout.rowCount
    readonly property real gridGap: Appearance.spacing.small
    readonly property real minimumRowHeight: 128
    readonly property real minimumGridHeight:
        root.gridRows * root.minimumRowHeight
            + (root.gridRows - 1) * root.gridGap
    readonly property int chartUpdateInterval: Math.max(
        250,
        Number(SystemMonitorService.sourceIntervalMs)
            || SystemMonitorService.intervalMs
    )
    readonly property var primaryGpu:
        SystemMonitorService.gpus.length > 0
            ? SystemMonitorService.gpus[0]
            : ({})
    readonly property var cpuTemperature:
        Format.isNumber(
            SystemMonitorService.cpu.packageTemperatureCelsius
        )
            ? SystemMonitorService.cpu.packageTemperatureCelsius
            : SystemMonitorService.cpu.temperatureCelsius
    readonly property var tileDefinitions: GridLayout.definitions()

    property bool serviceAcquired: false
    property bool preferencesApplied: false
    property var committedLayout: GridLayout.defaultLayout()
    property var previewLayout: []
    property string draggingTileId: ""
    property Item dragSourceItem: null
    property real dragPointerX: 0
    property real dragPointerY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property int targetColumn: -1
    property int targetRow: -1
    property bool dragTargetValid: false

    function normalizedPercent(value) {
        return Format.isNumber(value)
            ? Math.max(0, Math.min(1, value / 100))
            : -1;
    }

    function temperatureBadge(value) {
        return Format.isNumber(value)
            ? Math.round(value) + "°"
            : "";
    }

    function cpuDetail() {
        const system = SystemMonitorService.system;
        const physical = Number(system.physicalCoreCount || 0);
        const logical = Number(system.logicalCpuCount || 0);
        if (physical > 0 && logical > 0)
            return physical + " 核 · " + logical + " 线程";
        return "总体利用率";
    }

    function cpuSupporting() {
        const frequency = Format.frequencyMHz(
            SystemMonitorService.cpu.frequencyCurrentMHz
        );
        if (Format.isNumber(SystemMonitorService.cpu.powerWatts))
            return frequency + " · "
                + Format.watts(SystemMonitorService.cpu.powerWatts);
        return frequency;
    }

    function gpuSupporting() {
        if (SystemMonitorService.gpus.length === 0)
            return "未检测到可用图形设备";
        const gpu = root.primaryGpu;
        if (Format.isNumber(gpu.vramUsedBytes)
                && Format.isNumber(gpu.vramTotalBytes)) {
            return Format.bytes(gpu.vramUsedBytes)
                + " / " + Format.bytes(gpu.vramTotalBytes);
        }
        return Format.watts(gpu.powerWatts);
    }

    function layoutPlacement(layout, tileId) {
        return GridLayout.placementFor(layout, tileId);
    }

    function displayPlacement(tileId) {
        if (root.draggingTileId === tileId)
            return root.layoutPlacement(
                root.committedLayout,
                tileId
            );
        if (root.draggingTileId.length > 0
                && root.dragTargetValid) {
            return root.layoutPlacement(
                root.previewLayout,
                tileId
            );
        }
        return root.layoutPlacement(root.committedLayout, tileId);
    }

    function componentFor(tileId) {
        switch (tileId) {
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
        case "calendar":
            return calendarComponent;
        }
        return null;
    }

    function applyStoredLayout(forceRefresh) {
        if ((!forceRefresh && root.preferencesApplied)
                || !UiPreferences.preferencesReady
                || root.draggingTileId.length > 0) {
            return;
        }

        const hydrated = GridLayout.hydrateSaved(
            UiPreferences.systemGridLayout
        );
        const normalized = GridLayout.serializeLayout(hydrated);
        root.committedLayout = hydrated;
        root.preferencesApplied = true;
        if (JSON.stringify(normalized)
                !== JSON.stringify(
                    UiPreferences.systemGridLayout || {}
                )) {
            UiPreferences.setSystemGridLayout(normalized);
        }
    }

    function beginDrag(tileId, sourceItem, pointerX, pointerY) {
        if (root.draggingTileId.length > 0)
            root.cancelDrag();

        root.draggingTileId = tileId;
        root.dragSourceItem = sourceItem;
        root.dragPointerX = pointerX;
        root.dragPointerY = pointerY;
        root.dragOffsetX = pointerX - sourceItem.x;
        root.dragOffsetY = pointerY - sourceItem.y;
        root.targetColumn = -1;
        root.targetRow = -1;
        root.dragTargetValid = false;
        dashboard.forceActiveFocus();
        root.updateDrag(tileId, pointerX, pointerY);
    }

    function updateDrag(tileId, pointerX, pointerY) {
        if (tileId !== root.draggingTileId)
            return;

        root.dragPointerX = pointerX;
        root.dragPointerY = pointerY;
        const definition = GridLayout.definitionFor(tileId);
        if (!definition)
            return;

        const rawColumn = Math.round(
            (pointerX - root.dragOffsetX)
                / dashboard.columnStride
        );
        const rawRow = Math.round(
            (pointerY - root.dragOffsetY)
                / dashboard.rowStride
        );
        const anchor = GridLayout.clampAnchor(
            definition,
            rawColumn,
            rawRow
        );
        if (anchor.column === root.targetColumn
                && anchor.row === root.targetRow) {
            return;
        }

        root.targetColumn = anchor.column;
        root.targetRow = anchor.row;
        const solved = GridLayout.moveLayout(
            root.committedLayout,
            tileId,
            anchor.column,
            anchor.row
        );
        root.previewLayout = solved || [];
        root.dragTargetValid = solved !== null;
    }

    function finishDrag(tileId) {
        if (tileId !== root.draggingTileId)
            return;

        if (root.dragTargetValid) {
            root.committedLayout = root.previewLayout;
            UiPreferences.setSystemGridLayout(
                GridLayout.serializeLayout(root.committedLayout)
            );
        }
        root.resetDragState();
    }

    function cancelDrag(tileId) {
        if (tileId && tileId !== root.draggingTileId)
            return;
        root.resetDragState();
    }

    function resetDragState() {
        root.draggingTileId = "";
        root.dragSourceItem = null;
        root.previewLayout = [];
        root.dragTargetValid = false;
        root.targetColumn = -1;
        root.targetRow = -1;
    }

    function syncServiceOwnership() {
        if (root.isForeground && !root.serviceAcquired) {
            SystemMonitorService.acquire();
            root.serviceAcquired = true;
        } else if (!root.isForeground && root.serviceAcquired) {
            SystemMonitorService.release();
            root.serviceAcquired = false;
        }
    }

    onIsForegroundChanged: syncServiceOwnership()

    Component.onCompleted: {
        root.syncServiceOwnership();
        root.applyStoredLayout();
    }

    Component.onDestruction: {
        if (root.serviceAcquired)
            SystemMonitorService.release();
    }

    Connections {
        target: UiPreferences

        function onPreferencesReadyChanged() {
            root.applyStoredLayout();
        }

        function onSystemGridLayoutChanged() {
            if (root.preferencesApplied)
                root.applyStoredLayout(true);
        }
    }

    Component {
        id: timeComponent

        SystemClockCard {}
    }

    Component {
        id: batteryComponent

        SystemBatteryTank {
            battery: SystemMonitorService.battery
        }
    }

    Component {
        id: cpuComponent

        ExpressiveMetricTile {
            label: "CPU"
            iconName: "memory"
            detailText: root.cpuDetail()
            valueText: Format.percent(
                SystemMonitorService.cpu.usagePercent,
                0
            )
            supportingText: root.cpuSupporting()
            temperatureText:
                root.temperatureBadge(root.cpuTemperature)
            usage: root.normalizedPercent(
                SystemMonitorService.cpu.usagePercent
            )
            trendValues: SystemMonitorService.cpuHistory
            chartActive: root.isForeground
            updateInterval: root.chartUpdateInterval
            decorationSize: 50
            valueSize: Sizes.typeHeadlineMedium
            containerColor:
                Appearance.colors.colPrimaryContainer
            foregroundColor:
                Appearance.colors.colOnPrimaryContainer
            accentColor: Appearance.colors.colPrimary
            accentForegroundColor:
                Appearance.colors.colOnPrimary
        }
    }

    Component {
        id: gpuComponent

        ExpressiveMetricTile {
            label: "GPU"
            iconName: "developer_board"
            detailText: root.primaryGpu.name || "图形设备"
            valueText: SystemMonitorService.gpus.length > 0
                ? Format.percent(
                    root.primaryGpu.utilizationPercent,
                    0
                )
                : "—"
            supportingText: root.gpuSupporting()
            temperatureText: root.temperatureBadge(
                root.primaryGpu.temperatureCelsius
            )
            usage: SystemMonitorService.gpus.length > 0
                ? root.normalizedPercent(
                    root.primaryGpu.utilizationPercent
                )
                : -1
            trendValues: SystemMonitorService.gpuHistory
            chartActive: root.isForeground
            updateInterval: root.chartUpdateInterval
            shapeOverride: MaterialShape.Gem
            decorationSize: 50
            valueSize: Sizes.typeHeadlineMedium
            containerColor:
                Appearance.colors.colSecondaryContainer
            foregroundColor:
                Appearance.colors.colOnSecondaryContainer
            accentColor: Appearance.colors.colSecondary
            accentForegroundColor:
                Appearance.colors.colOnSecondary
        }
    }

    Component {
        id: memoryUsedComponent

        SystemLiquidMetricCard {
            iconName: "memory_alt"
            valueText: Format.percent(
                SystemMonitorService.memory.usagePercent,
                0
            )
            supportingText: Format.bytes(
                SystemMonitorService.memory.usedBytes
            ) + " / " + Format.bytes(
                SystemMonitorService.memory.totalBytes
            )
            level: root.normalizedPercent(
                SystemMonitorService.memory.usagePercent
            )
            valueAvailable: Format.isNumber(
                SystemMonitorService.memory.usagePercent
            )
            accessibilityName: "内存已使用 "
                + Format.percent(
                    SystemMonitorService.memory.usagePercent,
                    0
                )
                + "，" + Format.bytes(
                    SystemMonitorService.memory.usedBytes
                )
                + " / " + Format.bytes(
                    SystemMonitorService.memory.totalBytes
                )
            shapeId: MaterialShape.Slanted
            shapeColor: Appearance.colors.colPrimaryContainer
            liquidColor: Appearance.applyAlpha(
                Appearance.colors.colTertiary,
                0.66
            )
            contentColor: Appearance.colors.colOnPrimaryContainer
        }
    }

    Component {
        id: wifiComponent

        SystemLiquidMetricCard {
            iconName: NetworkService.wifiConnected
                ? "wifi"
                : "wifi_off"
            valueText:
                NetworkService.wifiConnected
                    ? Format.percent(
                        NetworkService.signalStrength,
                        0
                    )
                    : "—"
            supportingText: "Wi-Fi 信号强度"
            level: root.normalizedPercent(
                NetworkService.signalStrength
            )
            valueAvailable: NetworkService.wifiConnected
            accessibilityName:
                NetworkService.wifiConnected
                    ? "Wi-Fi 信号强度 "
                        + Format.percent(
                            NetworkService.signalStrength,
                            0
                        )
                    : "Wi-Fi 未连接"
            shapeId: MaterialShape.Pentagon
            shapeColor:
                Appearance.colors.colTertiaryContainer
            liquidColor: Appearance.applyAlpha(
                Appearance.colors.colTertiary,
                0.64
            )
            contentColor: Appearance.colors.colOnTertiaryContainer
        }
    }

    Component {
        id: networkComponent

        SystemNetworkCard {
            network: SystemMonitorService.network
            downloadHistory:
                SystemMonitorService.networkDownloadHistory
            uploadHistory:
                SystemMonitorService.networkUploadHistory
            chartActive: root.isForeground
            updateInterval: root.chartUpdateInterval
        }
    }

    Component {
        id: storageComponent

        SystemStorageCard {
            disks: SystemMonitorService.disks
        }
    }

    Component {
        id: calendarComponent

        SystemCalendarCard {}
    }

    Item {
        anchors {
            fill: parent
            margins: Appearance.spacing.small
        }

        SystemLoadingState {
            anchors.fill: parent
            visible: !SystemMonitorService.hasData
                && !SystemMonitorService.error
                && !SystemMonitorService.reconnecting
            message: "正在连接系统监测服务"
        }

        SystemUnavailableState {
            anchors {
                fill: parent
                topMargin: Appearance.spacing.large
                bottomMargin: Appearance.spacing.large
            }
            visible: !SystemMonitorService.hasData
                && (SystemMonitorService.error
                    || SystemMonitorService.reconnecting)
            title: SystemMonitorService.reconnecting
                ? "正在重新连接"
                : (SystemMonitorService.errorMessage
                    || "系统监测服务不可用")
            message: SystemMonitorService.error
                ? "请确认 key 已重新构建并可从当前环境运行。"
                : "连接中断后会使用有限指数退避自动恢复。"
            reconnecting: SystemMonitorService.reconnecting
            onRetryRequested: SystemMonitorService.retry()
        }

        StyledFlickable {
            id: dashboardScroll

            anchors.fill: parent
            visible: SystemMonitorService.hasData
            contentWidth: width
            contentHeight: Math.max(
                height,
                root.minimumGridHeight
            )
            interactive: contentHeight > height + 1
                && root.draggingTileId.length === 0
            showVerticalScrollBar: contentHeight > height + 1
            activeFocusOnTab: contentHeight > height + 1
            Accessible.name: contentHeight > height + 1
                ? "系统信息网格，可滚动并可拖动卡片"
                : "系统信息网格，可拖动卡片"

            function scrollBy(delta) {
                const next = dashboardScroll.clampContentY(
                    dashboardScroll.contentY + delta
                );
                dashboardScroll.scrollTargetY = next;
                dashboardScroll.contentY = next;
            }

            Keys.onPressed: event => {
                if (root.draggingTileId.length > 0
                        && event.key === Qt.Key_Escape) {
                    root.cancelDrag();
                    event.accepted = true;
                    return;
                }
                if (dashboardScroll.contentHeight
                        <= dashboardScroll.height + 1) {
                    return;
                }
                if (event.key === Qt.Key_Up)
                    dashboardScroll.scrollBy(-64);
                else if (event.key === Qt.Key_Down)
                    dashboardScroll.scrollBy(64);
                else if (event.key === Qt.Key_PageUp)
                    dashboardScroll.scrollBy(
                        -dashboardScroll.height * 0.8
                    );
                else if (event.key === Qt.Key_PageDown)
                    dashboardScroll.scrollBy(
                        dashboardScroll.height * 0.8
                    );
                else if (event.key === Qt.Key_Home)
                    dashboardScroll.scrollBy(
                        -dashboardScroll.contentHeight
                    );
                else if (event.key === Qt.Key_End)
                    dashboardScroll.scrollBy(
                        dashboardScroll.contentHeight
                    );
                else
                    return;
                event.accepted = true;
            }

            Item {
                id: dashboard

                width: dashboardScroll.width
                    - (dashboardScroll.contentHeight
                            > dashboardScroll.height + 1
                        ? Appearance.spacing.small
                        : 0)
                height: dashboardScroll.contentHeight
                focus: root.draggingTileId.length > 0

                readonly property real cellWidth:
                    (width - root.gridGap
                        * (root.gridColumns - 1))
                        / root.gridColumns
                readonly property real cellHeight:
                    (height - root.gridGap
                        * (root.gridRows - 1))
                        / root.gridRows
                readonly property real columnStride:
                    cellWidth + root.gridGap
                readonly property real rowStride:
                    cellHeight + root.gridGap

                Keys.onEscapePressed: event => {
                    if (root.draggingTileId.length === 0)
                        return;
                    root.cancelDrag();
                    event.accepted = true;
                }

                Rectangle {
                    id: targetPreview

                    x: root.targetColumn * dashboard.columnStride
                    y: root.targetRow * dashboard.rowStride
                    width: {
                        const definition = GridLayout.definitionFor(
                            root.draggingTileId
                        );
                        return definition
                            ? definition.columnSpan
                                * dashboard.cellWidth
                                + (definition.columnSpan - 1)
                                    * root.gridGap
                            : 0;
                    }
                    height: {
                        const definition = GridLayout.definitionFor(
                            root.draggingTileId
                        );
                        return definition
                            ? definition.rowSpan
                                * dashboard.cellHeight
                                + (definition.rowSpan - 1)
                                    * root.gridGap
                            : 0;
                    }
                    visible: root.draggingTileId.length > 0
                        && root.targetColumn >= 0
                        && root.targetRow >= 0
                    radius: Appearance.rounding.extraLarge
                    color: Appearance.applyAlpha(
                        root.dragTargetValid
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colError,
                        0.14
                    )
                    border.width: 2
                    border.color: root.dragTargetValid
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colError
                    z: 20

                    Behavior on x {
                        NumberAnimation {
                            duration: Appearance.animation
                                .expressiveEffects.duration
                            easing.type: Appearance.animation
                                .expressiveEffects.type
                            easing.bezierCurve: Appearance.animation
                                .expressiveEffects.bezierCurve
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.animation
                                .expressiveEffects.duration
                            easing.type: Appearance.animation
                                .expressiveEffects.type
                            easing.bezierCurve: Appearance.animation
                                .expressiveEffects.bezierCurve
                        }
                    }
                }

                Repeater {
                    model: root.tileDefinitions

                    delegate: SystemGridTile {
                        id: tile

                        required property var modelData
                        readonly property var definition: modelData
                        readonly property var placement:
                            root.displayPlacement(tile.tileId)

                        tileId: definition.id
                        x: placement
                            ? placement.column
                                * dashboard.columnStride
                            : 0
                        y: placement
                            ? placement.row
                                * dashboard.rowStride
                            : 0
                        width: definition.columnSpan
                            * dashboard.cellWidth
                            + (definition.columnSpan - 1)
                                * root.gridGap
                        height: definition.rowSpan
                            * dashboard.cellHeight
                            + (definition.rowSpan - 1)
                                * root.gridGap
                        sourceComponent:
                            root.componentFor(tile.tileId)
                        dragging:
                            root.draggingTileId === tile.tileId
                        z: dragging ? 30 : 1

                        onDragStarted: (
                            tileId,
                            sourceItem,
                            pointerX,
                            pointerY
                        ) => root.beginDrag(
                            tileId,
                            sourceItem,
                            pointerX,
                            pointerY
                        )
                        onDragMoved: (
                            tileId,
                            pointerX,
                            pointerY
                        ) => root.updateDrag(
                            tileId,
                            pointerX,
                            pointerY
                        )
                        onDragFinished: tileId =>
                            root.finishDrag(tileId)
                        onDragCanceled: tileId =>
                            root.cancelDrag(tileId)
                    }
                }

                ShaderEffectSource {
                    id: dragProxy

                    x: root.dragPointerX - root.dragOffsetX
                    y: root.dragPointerY - root.dragOffsetY
                    width: root.dragSourceItem
                        ? root.dragSourceItem.width
                        : 0
                    height: root.dragSourceItem
                        ? root.dragSourceItem.height
                        : 0
                    visible: root.dragSourceItem !== null
                    sourceItem: root.dragSourceItem
                    sourceRect: Qt.rect(0, 0, width, height)
                    hideSource: visible
                    live: true
                    smooth: true
                    opacity: 0.96
                    scale: visible ? 1.025 : 1
                    z: 50

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animation
                                .expressiveEffects.duration
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }
        }
    }
}
