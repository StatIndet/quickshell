import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

WidgetPanel {
    id: root

    property var screen: null
    title: "快捷设置"
    icon: "settings"
    closeAction: () => WidgetState.qsOpen = false

    property bool editMode: false
    property int toggleColumns: 5
    property real toggleSpacing: 6
    property real togglePadding: 6
    property real baseCellHeight: 56
    readonly property var toggleRows: rowsForToggles(QuickToggleConfig.toggles)
    readonly property var unusedToggleRows: rowsForToggles(QuickToggleConfig.unusedToggleTypes.map(type => ({ "type": type, "size": 1 })))

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
        return type === "network" || type === "audio" || type === "mic" || type === "bluetooth";
    }

    function titleForType(type) {
        switch (type) {
        case "network": return "网络";
        case "bluetooth": return "蓝牙";
        case "caffeine": return "咖啡因";
        case "mic": return "麦克风";
        case "audio": return "声音";
        case "theme": return "外观";
        case "dnd": return "免打扰";
        default: return type;
        }
    }

    function subtitleForType(type) {
        switch (type) {
        case "network":
            return Network.wifiEnabled ? Network.activeConnection : "已关闭";
        case "bluetooth":
            if (!BluetoothService.available)
                return "不可用";
            if (!BluetoothService.enabled)
                return "已关闭";
            return BluetoothService.connected ? (BluetoothService.connectedName || "已连接") : "已开启";
        case "caffeine":
            return Idle.inhibited ? "保持唤醒" : "正常休眠";
        case "mic":
            return Volume.sourceMuted ? "已静音" : "已开启";
        case "audio":
            return Volume.sinkMuted ? "已静音" : Math.round(Volume.sinkVolume * 100) + "%";
        case "theme":
            return UiPreferences.darkMode ? "深色" : "浅色";
        case "dnd":
            return UiPreferences.dndEnabled ? "已开启" : "已关闭";
        default:
            return "";
        }
    }

    function iconForType(type) {
        switch (type) {
        case "network":
            return Network.wifiEnabled ? "wifi" : "wifi_off";
        case "bluetooth":
            return BluetoothService.connected ? "bluetooth_connected" : BluetoothService.enabled ? "bluetooth" : "bluetooth_disabled";
        case "caffeine":
            return "coffee";
        case "mic":
            return Volume.sourceMuted ? "mic_off" : "mic";
        case "audio":
            return Volume.sinkMuted || Volume.sinkVolume <= 0 ? "volume_off" : "volume_up";
        case "theme":
            return UiPreferences.darkMode ? "dark_mode" : "light_mode";
        case "dnd":
            return UiPreferences.dndEnabled ? "notifications_paused" : "notifications";
        default:
            return "toggle_off";
        }
    }

    function toggledForType(type) {
        switch (type) {
        case "network": return Network.wifiEnabled;
        case "bluetooth": return BluetoothService.enabled;
        case "caffeine": return Idle.inhibited;
        case "mic": return !Volume.sourceMuted;
        case "audio": return !Volume.sinkMuted && Volume.sinkVolume > 0;
        case "theme": return UiPreferences.darkMode;
        case "dnd": return UiPreferences.dndEnabled;
        default: return false;
        }
    }

    function availableForType(type) {
        switch (type) {
        case "bluetooth": return BluetoothService.available;
        default: return true;
        }
    }

    function triggerType(type) {
        switch (type) {
        case "network":
            Network.toggleWifi();
            break;
        case "bluetooth":
            BluetoothService.toggle();
            break;
        case "caffeine":
            Idle.toggle();
            break;
        case "mic":
            Volume.toggleSourceMute();
            break;
        case "audio":
            Volume.toggleSinkMute();
            break;
        case "theme":
            UiPreferences.toggleDarkMode();
            break;
        case "dnd":
            UiPreferences.toggleDnd();
            break;
        }
    }

    function altType(type) {
        if (type === "network") {
            WidgetState.qsView = "network";
            WidgetState.qsOpen = true;
        } else if (type === "audio" || type === "mic") {
            WidgetState.qsView = "audio";
            WidgetState.qsOpen = true;
        } else if (type === "bluetooth") {
            WidgetState.qsView = "bluetooth";
            WidgetState.qsOpen = true;
        }
    }

    function tooltipForType(type) {
        const base = titleForType(type) + " | " + subtitleForType(type);
        if (root.editMode)
            return base + "\n左键启用/隐藏，右键切换形状，滚轮调整顺序";
        if (type === "network" || type === "audio" || type === "mic" || type === "bluetooth")
            return base + "\n右键打开详情面板";
        return base;
    }

    headerTools: QuickToggleGroup {
        spacing: 5

        QuickToggleButton {
            collapsedSize: 40
            cellSpacing: 5
            padding: 5
            iconName: "edit"
            toggled: root.editMode
            tooltipText: root.editMode ? "编辑快捷按钮\n左键启用/隐藏，右键切换形状，滚轮调整顺序" : "编辑快捷按钮"
            onTriggered: root.editMode = !root.editMode
        }

        QuickToggleButton {
            collapsedSize: 40
            cellSpacing: 5
            padding: 5
            iconName: "restart_alt"
            tooltipText: "重启 Quickshell"
            onTriggered: Quickshell.reload(true)
        }

        QuickToggleButton {
            collapsedSize: 40
            cellSpacing: 5
            padding: 5
            iconName: "settings"
            tooltipText: "设置"
            onTriggered: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("controlcenter.qml")])
        }

        QuickToggleButton {
            collapsedSize: 40
            cellSpacing: 5
            padding: 5
            iconName: "power_settings_new"
            tooltipText: "会话"
            onTriggered: Quickshell.execDetached(["wlogout", "-p", "layer-shell", "-b", "2"])
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 14

        QuickSliders {
            screen: root.screen
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
                spacing: root.editMode ? 12 : root.toggleSpacing

                Column {
                    id: usedRows

                    spacing: root.toggleSpacing

                    Repeater {
                        model: root.toggleRows

                        QuickToggleGroup {
                            required property var modelData

                            spacing: root.toggleSpacing

                            Repeater {
                                model: modelData

                                QuickToggleButton {
                                    required property var modelData

                                    readonly property string toggleType: modelData.type
                                    readonly property int toggleSize: root.sizeForToggle(modelData)

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
                                        if (root.editMode)
                                            QuickToggleConfig.toggleEnabled(toggleType);
                                        else
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

                Rectangle {
                    width: Math.max(0, togglePanel.baseCellWidth * 4)
                    height: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.editMode
                    color: Appearance.colors.colOutlineVariant
                }

                Column {
                    id: unusedRows

                    visible: root.editMode && root.unusedToggleRows.length > 0
                    spacing: root.toggleSpacing

                    Repeater {
                        model: root.unusedToggleRows

                        QuickToggleGroup {
                            required property var modelData

                            spacing: root.toggleSpacing

                            Repeater {
                                model: modelData

                                QuickToggleButton {
                                    required property var modelData

                                    readonly property string toggleType: modelData.type

                                    title: root.titleForType(toggleType)
                                    subtitle: "已隐藏"
                                    iconName: root.iconForType(toggleType)
                                    toggled: false
                                    available: root.availableForType(toggleType)
                                    expanded: false
                                    editMode: true
                                    baseCellWidth: togglePanel.baseCellWidth
                                    baseCellHeight: root.baseCellHeight
                                    cellSpacing: root.toggleSpacing
                                    cellSize: 1
                                    opacity: 0.6
                                    tooltipText: root.titleForType(toggleType) + "\n左键添加到快捷设置，右键添加为长条"

                                    onTriggered: QuickToggleConfig.toggleEnabled(toggleType)
                                    onAltTriggered: {
                                        QuickToggleConfig.toggleEnabled(toggleType);
                                        QuickToggleConfig.toggleSize(toggleType);
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
