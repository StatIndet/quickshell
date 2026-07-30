import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

WidgetPanel {
    id: root

    property var screen: null
    title: ""
    icon: "settings"

    property bool editMode: false
    readonly property bool capturesWheel: editMode
    property int toggleColumns: 5
    property real toggleSpacing: 6
    property real togglePadding: 6
    property real baseCellHeight: 56
    property real contentSpacing: 14
    property real headerButtonSize: 40
    property real headerButtonSpacing: 5
    property real headerButtonPadding: 5
    property real presentationProgress: 0
    property bool presentationAnimating: false
    property bool presentationPlayed: false
    readonly property var toggleRows: rowsForToggles(QuickToggleConfig.toggles)
    readonly property var toggleRowKeys: toggleRows.map((row, index) => index)
    readonly property bool presentationForeground:
        WidgetState.qsOpen && WidgetState.qsView === "settings"
    readonly property bool presentationLayoutReady:
        togglePanel.width > 0
            && togglePanel.baseCellWidth >= root.baseCellHeight

    function startPresentation() {
        if (presentationPlayed
                || !presentationForeground
                || !presentationLayoutReady)
            return

        presentationAnimation.stop()
        root.presentationPlayed = true
        root.presentationAnimating = true
        root.presentationProgress = 0
        presentationAnimation.restart()
    }

    onPresentationForegroundChanged: {
        if (presentationForeground)
            startPresentation()
    }
    onPresentationLayoutReadyChanged: {
        if (presentationLayoutReady)
            startPresentation()
    }

    Component.onCompleted: {
        if (presentationForeground)
            startPresentation()
    }

    NumberAnimation {
        id: presentationAnimation
        target: root
        property: "presentationProgress"
        from: 0
        to: 1
        duration: Appearance.animation.expressiveDefaultSpatial.duration
        easing.type: Appearance.animation.expressiveDefaultSpatial.type
        easing.bezierCurve:
            Appearance.animation.expressiveDefaultSpatial.bezierCurve
        onFinished: root.presentationAnimating = false
    }

    function openControlCenter() {
        WidgetState.qsOpen = false;
        Quickshell.execDetached([
            Paths.shellDir + "/scripts/open-control-center",
            "general"
        ]);
    }

    function sizeForToggle(toggle) {
        return Number(toggle && toggle.size) === 2 ? 2 : 1;
    }

    function rowsForToggles(togglesList) {
        const rows = [];
        let row = [];
        let totalSize = 0;

        for (let i = 0; i < togglesList.length; i += 1) {
            const toggle = togglesList[i];
            if (!toggle)
                continue;

            const size = Math.min(root.toggleColumns, Math.max(1, root.sizeForToggle(toggle)));
            if (totalSize + size > root.toggleColumns && row.length > 0) {
                rows.push(row);
                row = [];
                totalSize = 0;
            }

            row.push(toggle);
            totalSize += size;
        }

        if (row.length > 0)
            rows.push(row);

        return rows;
    }

    function hasAltActionForType(type) {
        return type === "network"
            || type === "bluetooth"
            || type === "caffeine"
            || type === "audio"
            || type === "mic";
    }

    function titleForType(type) {
        switch (type) {
        case "network": return qsTr("网络");
        case "bluetooth": return qsTr("蓝牙");
        case "caffeine": return qsTr("咖啡因");
        case "mic": return qsTr("麦克风");
        case "audio": return qsTr("声音");
        case "theme": return qsTr("外观");
        case "dnd": return qsTr("免打扰");
        default: return type;
        }
    }

    function subtitleForType(type) {
        switch (type) {
        case "network":
            if (!NetworkService.available)
                return qsTr("不可用");
            if (!NetworkService.wifiAvailable)
                return qsTr("无 Wi-Fi 设备");
            return NetworkService.wifiEnabled ? NetworkService.activeConnection : qsTr("已关闭");
        case "bluetooth":
            if (!BluetoothService.available)
                return qsTr("不可用");
            if (!BluetoothService.enabled)
                return qsTr("已关闭");
            return BluetoothService.connected ? (BluetoothService.connectedName || qsTr("已连接")) : qsTr("已开启");
        case "caffeine":
            return IdleService.inhibited ? qsTr("保持唤醒") : qsTr("正常休眠");
        case "mic":
            return Volume.sourceMuted ? qsTr("已静音") : qsTr("已开启");
        case "audio":
            return Volume.sinkMuted ? qsTr("已静音") : Math.round(Volume.sinkVolume * 100) + "%";
        case "theme":
            return PersonalizationConfig.themeMode === "dark" ? qsTr("深色") : qsTr("浅色");
        case "dnd":
            return UiPreferences.dndEnabled ? qsTr("已开启") : qsTr("已关闭");
        default:
            return "";
        }
    }

    function iconForType(type) {
        switch (type) {
        case "network":
            return NetworkService.wifiEnabled ? "wifi" : "wifi_off";
        case "bluetooth":
            return BluetoothService.connected ? "bluetooth_connected" : BluetoothService.enabled ? "bluetooth" : "bluetooth_disabled";
        case "caffeine":
            return "coffee";
        case "mic":
            return Volume.sourceMuted ? "mic_off" : "mic";
        case "audio":
            return Volume.sinkMuted || Volume.sinkVolume <= 0 ? "volume_off" : "volume_up";
        case "theme":
            return PersonalizationConfig.themeMode === "dark" ? "dark_mode" : "light_mode";
        case "dnd":
            return UiPreferences.dndEnabled ? "notifications_paused" : "notifications";
        default:
            return "toggle_off";
        }
    }

    function toggledForType(type) {
        switch (type) {
        case "network": return NetworkService.wifiEnabled;
        case "bluetooth": return BluetoothService.enabled;
        case "caffeine": return IdleService.inhibited;
        case "mic": return !Volume.sourceMuted;
        case "audio": return !Volume.sinkMuted && Volume.sinkVolume > 0;
        case "theme": return PersonalizationConfig.themeMode === "dark";
        case "dnd": return UiPreferences.dndEnabled;
        default: return false;
        }
    }

    function availableForType(type) {
        switch (type) {
        case "network": return NetworkService.available && NetworkService.wifiAvailable;
        case "bluetooth": return BluetoothService.available;
        default: return true;
        }
    }

    function triggerType(type) {
        switch (type) {
        case "network":
            NetworkService.toggleWifi();
            break;
        case "bluetooth":
            BluetoothService.toggle();
            break;
        case "caffeine":
            IdleService.toggleInhibited();
            break;
        case "mic":
            Volume.toggleSourceMute();
            break;
        case "audio":
            Volume.toggleSinkMute();
            break;
        case "theme":
            ThemeService.setThemeMode(PersonalizationConfig.themeMode === "dark" ? "light" : "dark");
            break;
        case "dnd":
            UiPreferences.toggleDnd();
            break;
        }
    }

    function altType(type) {
        let view = "";
        if (type === "network")
            view = "network";
        else if (type === "bluetooth")
            view = "bluetooth";
        else if (type === "caffeine")
            view = "idle";
        else if (type === "audio")
            view = "audio";
        else if (type === "mic")
            view = "microphone";

        if (view.length === 0)
            return;
        WidgetState.qsView = view;
        WidgetState.qsOpen = true;
    }

    function tooltipForType(type) {
        const base = titleForType(type) + " | " + subtitleForType(type);
        if (root.editMode)
            return base + qsTr("\n右键切换形状，滚轮调整顺序");
        if (root.hasAltActionForType(type))
            return base + qsTr("\n右键打开详情面板");
        return base;
    }

    function capturesWheelAt(x, y) {
        if (!root.capturesWheel)
            return false;

        const point = togglePanel.mapFromItem(root, x, y);
        return point.x >= 0 && point.x <= togglePanel.width
            && point.y >= 0 && point.y <= togglePanel.height;
    }

    headerTools: QuickToggleGroup {
        spacing: root.headerButtonSpacing

        QuickToggleButton {
            collapsedSize: root.headerButtonSize
            cellSpacing: root.headerButtonSpacing
            padding: root.headerButtonPadding
            iconName: "edit"
            toggled: root.editMode
            tooltipText: root.editMode ? qsTr("编辑快捷按钮\n右键切换形状，滚轮调整顺序") : qsTr("编辑快捷按钮")
            onTriggered: root.editMode = !root.editMode
        }

        QuickToggleButton {
            collapsedSize: root.headerButtonSize
            cellSpacing: root.headerButtonSpacing
            padding: root.headerButtonPadding
            iconName: "restart_alt"
            tooltipText: qsTr("重启 Quickshell")
            onTriggered: Quickshell.reload(true)
        }

        QuickToggleButton {
            collapsedSize: root.headerButtonSize
            cellSpacing: root.headerButtonSpacing
            padding: root.headerButtonPadding
            iconName: "settings"
            tooltipText: qsTr("设置")
            onTriggered: root.openControlCenter()
        }

        QuickToggleButton {
            collapsedSize: root.headerButtonSize
            cellSpacing: root.headerButtonSpacing
            padding: root.headerButtonPadding
            iconName: "power_settings_new"
            tooltipText: qsTr("电源菜单")
            onTriggered: Quickshell.execDetached([
                Paths.systemScriptsDir + "/power-menu.sh",
                PersonalizationConfig.powerMenuStyle
            ])
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: root.contentSpacing

        QuickSliders {
            screen: root.screen
            Layout.fillWidth: true
        }

        PowerProfileSelector {
            Layout.fillWidth: true
        }

        Rectangle {
            id: togglePanel

            Layout.fillWidth: true
            Layout.preferredHeight: toggleContent.implicitHeight + root.togglePadding * 2
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1

            readonly property real baseCellWidth: {
                const availableWidth = width - root.togglePadding * 2 - root.toggleSpacing * root.toggleColumns;
                return Math.max(root.baseCellHeight, availableWidth / root.toggleColumns);
            }

            Behavior on Layout.preferredHeight {
                NumberAnimation {
                    duration: Appearance.animation.expressiveDefaultSpatial.duration
                    easing.type: Appearance.animation.expressiveDefaultSpatial.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                }
            }

            Column {
                id: toggleContent

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: root.togglePadding
                }
                spacing: root.toggleSpacing

                Column {
                    id: usedRows

                    spacing: root.toggleSpacing

                    Repeater {
                        model: ScriptModel {
                            values: root.toggleRowKeys
                        }

                        QuickToggleGroup {
                            id: toggleRow

                            required property int modelData
                            readonly property var rowData: root.toggleRows[modelData] || []

                            spacing: root.toggleSpacing

                            Repeater {
                                model: ScriptModel {
                                    values: toggleRow.rowData
                                    objectProp: "type"
                                }

                                QuickToggleButton {
                                    required property var modelData

                                    readonly property string toggleType: modelData.type
                                    readonly property int toggleSize: root.sizeForToggle(modelData)

                                    presentationProgress: root.presentationProgress
                                    presentationAnimating:
                                        root.presentationAnimating
                                    title: root.titleForType(toggleType)
                                    subtitle: root.subtitleForType(toggleType)
                                    iconName: root.iconForType(toggleType)
                                    toggled: root.toggledForType(toggleType)
                                    available: root.availableForType(toggleType)
                                    expanded: toggleSize === 2
                                    editMode: root.editMode
                                    hasAltAction: root.hasAltActionForType(toggleType)
                                    baseCellWidth: togglePanel.baseCellWidth
                                    baseCellHeight: root.baseCellHeight
                                    cellSpacing: root.toggleSpacing
                                    cellSize: toggleSize
                                    tooltipText: root.tooltipForType(toggleType)

                                    onTriggered: {
                                        if (!root.editMode)
                                            root.triggerType(toggleType);
                                    }

                                    onAltTriggered: {
                                        if (root.editMode)
                                            QuickToggleConfig.toggleSize(toggleType);
                                        else
                                            root.altType(toggleType);
                                    }

                                    onWheelMoved: (delta) => {
                                        if (!root.editMode)
                                            return;
                                        QuickToggleConfig.move(toggleType, delta < 0 ? 1 : -1);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
