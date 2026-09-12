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
    readonly property var toggleRows: rowsForToggles(QuickToggleConfig.toggles)
    readonly property var toggleRowKeys: toggleRows.map((row, index) => index)

    function openControlCenter() {
        WidgetState.quickSettingsOpen = false;
        ControlCenterService.open();
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
        return type === "network" || type === "bluetooth" || type === "caffeine" || type === "audio" || type
                === "mic" || type === "night";
    }

    function titleForType(type) {
        switch (type) {
        case "night":
            return qsTr("Night Mode");
        case "network":
            return qsTr("Network");
        case "bluetooth":
            return qsTr("Bluetooth");
        case "caffeine":
            return qsTr("Caffeine");
        case "mic":
            return qsTr("Microphone");
        case "audio":
            return qsTr("Sound");
        case "theme":
            return qsTr("Appearance");
        case "dnd":
            return qsTr("Do not disturb");
        default:
            return type;
        }
    }

    function subtitleForType(type) {
        switch (type) {
        case "night":
            return !DisplayColor.available ? qsTr("Unavailable") : DisplayColor.preferences.nightEnabled
                                             ? qsTr("%1 K").arg(DisplayColor.schedule.temperature) : "";
        case "network":
            if (!NetworkService.available)
                return qsTr("Unavailable");
            if (!NetworkService.wifiAvailable)
                return qsTr("No Wi-Fi device");
            return NetworkService.wifiEnabled ? NetworkService.activeConnection : qsTr("Off");
        case "bluetooth":
            if (!BluetoothService.available)
                return qsTr("Unavailable");
            if (!BluetoothService.enabled)
                return qsTr("Off");
            return BluetoothService.connected ? (BluetoothService.connectedName || qsTr("Connected")) : qsTr(
                                                    "On");
        case "caffeine":
            return IdleService.inhibited ? qsTr("Keep awake") : qsTr("Normal sleep");
        case "mic":
            return Volume.sourceMuted ? qsTr("Muted") : qsTr("On");
        case "audio":
            return Volume.sinkMuted ? qsTr("Muted") : Math.round(Volume.sinkVolume * 100) + "%";
        case "theme":
            return PersonalizationConfig.themeMode === "dark" ? qsTr("Dark") : qsTr("Light");
        case "dnd":
            return UiPreferences.dndEnabled ? qsTr("On") : qsTr("Off");
        default:
            return "";
        }
    }

    function iconForType(type) {
        switch (type) {
        case "night":
            return "nightlight";
        case "network":
            return NetworkService.wifiEnabled ? "wifi" : "wifi_off";
        case "bluetooth":
            return BluetoothService.connected ? "bluetooth_connected" : BluetoothService.enabled
                                                ? "bluetooth" : "bluetooth_disabled";
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
        case "night":
            return DisplayColor.preferences.nightEnabled;
        case "network":
            return NetworkService.wifiEnabled;
        case "bluetooth":
            return BluetoothService.enabled;
        case "caffeine":
            return IdleService.inhibited;
        case "mic":
            return !Volume.sourceMuted;
        case "audio":
            return !Volume.sinkMuted && Volume.sinkVolume > 0;
        case "theme":
            return PersonalizationConfig.themeMode === "dark";
        case "dnd":
            return UiPreferences.dndEnabled;
        default:
            return false;
        }
    }

    function availableForType(type) {
        switch (type) {
        case "night":
            return DisplayColor.ready && DisplayColor.available;
        case "network":
            return NetworkService.available && NetworkService.wifiAvailable;
        case "bluetooth":
            return BluetoothService.available;
        default:
            return true;
        }
    }

    function triggerType(type) {
        switch (type) {
        case "night":
            DisplayColor.setPreference("nightEnabled", !DisplayColor.preferences.nightEnabled);
            break;
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
        else if (type === "night")
            view = "night";

        if (view.length === 0)
            return;
        WidgetState.quickSettingsView = view;
        WidgetState.quickSettingsOpen = true;
    }

    function tooltipForType(type) {
        const subtitle = subtitleForType(type);
        const base = titleForType(type) + (subtitle ? " | " + subtitle : "");
        if (root.editMode)
            return base + qsTr("\nRight-click to change shape; scroll to reorder");
        if (root.hasAltActionForType(type))
            return base + qsTr("\nRight-click to open the details panel");
        return base;
    }

    function capturesWheelAt(x, y) {
        if (!root.capturesWheel)
            return false;

        const point = togglePanel.mapFromItem(root, x, y);
        return point.x >= 0 && point.x <= togglePanel.width && point.y >= 0 && point.y <= togglePanel.height;
    }

    headerTools: QuickToggleGroup {
        spacing: root.headerButtonSpacing

        QuickToggleButton {
            collapsedSize: root.headerButtonSize
            cellSpacing: root.headerButtonSpacing
            padding: root.headerButtonPadding
            iconName: "edit"
            toggled: root.editMode
            tooltipText: root.editMode ? qsTr(
                                             "Edit quick actions\nRight-click to change shape; scroll to reorder") :
                                         qsTr("Edit quick actions")
            onTriggered: root.editMode = !root.editMode
        }

        QuickToggleButton {
            collapsedSize: root.headerButtonSize
            cellSpacing: root.headerButtonSpacing
            padding: root.headerButtonPadding
            iconName: "restart_alt"
            tooltipText: qsTr("Restart Quickshell")
            onTriggered: Quickshell.reload(true)
        }

        QuickToggleButton {
            collapsedSize: root.headerButtonSize
            cellSpacing: root.headerButtonSpacing
            padding: root.headerButtonPadding
            iconName: "settings"
            tooltipText: qsTr("Settings")
            onTriggered: root.openControlCenter()
        }

        QuickToggleButton {
            collapsedSize: root.headerButtonSize
            cellSpacing: root.headerButtonSpacing
            padding: root.headerButtonPadding
            iconName: "power_settings_new"
            tooltipText: qsTr("Power menu")
            onTriggered: PowerMenuService.open(root.screen)
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

        Rectangle {
            id: togglePanel

            Layout.fillWidth: true
            Layout.preferredHeight: toggleContent.implicitHeight + root.togglePadding * 2
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1

            readonly property real baseCellWidth: {
                const availableWidth = width - root.togglePadding * 2 - root.toggleSpacing
                      * root.toggleColumns;
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

                                    onWheelMoved: delta => {
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
