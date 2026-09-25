import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    required property string itemId
    required property var screen
    property string edge: "top"
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool nameLabel: itemId === "network" || itemId === "bluetooth"
    readonly property bool rotateLabel: vertical && nameLabel
    property real maximumNameWidth: 160
    readonly property var connectedDeviceNames: BluetoothService.connectedDevices.map(device => device.name)
    readonly property var player: MediaManager.active
    readonly property var monitor: Brightness.getMonitorForScreen(screen)
    readonly property real brightness: monitor ? monitor.brightness : Brightness.brightnessValue
    required property string ownerId
    readonly property bool batteryAvailable: PowerService.ready && PowerService.present && Format.isNumber(
                                                 PowerService.percentage)
    readonly property string displayText: {
        switch (itemId) {
        case "weather":
            return WeatherPlugin.hasValidData ? Math.round(UiPreferences.weatherTemperature(
                                                               WeatherPlugin.currentTemperatureC)) + "°" :
                                                "--°";
        case "network":
            return root.tooltipText;
        case "bluetooth":
            return connectedDeviceNames.length === 1 ? connectedDeviceNames[0] : connectedDeviceNames.length
                                                       > 1 ? qsTr("%n device(s)", "",
                                                                  connectedDeviceNames.length) : "";
        case "brightness":
            return Format.percent(brightness * 100, 0);
        case "volume":
            return Volume.outputAvailable ? Format.percent(Volume.sinkVolume * 100, 0) : Format.unavailable();
        case "microphone":
            return Volume.inputAvailable ? Format.percent(Volume.sourceVolume * 100, 0) : Format.unavailable(
                                               );

        case "battery":
            return batteryAvailable ? Format.percent(PowerService.percentage * 100, 0) : Format.unavailable();
        default:
            return "";
        }
    }
    readonly property string label: {
        const option = PersonalizationConfig.keystoneLongItemOptions.find(option => option.value
                                                                                    === root.itemId);
        return option ? option.label : "";
    }
    readonly property string iconName: {
        switch (itemId) {
        case "weather":
            return WeatherPlugin.hasValidData ? WeatherPlugin.currentIconName || "cloud" : "cloud_off";
        case "media":
            return player ? (player.isPlaying ? "play_arrow" : "pause") : "music_note";
        case "network":
            if (!NetworkService.connected)
                return "wifi_off";
            if (NetworkService.activeConnectionType === "ETHERNET")
                return "settings_ethernet";
            const strength = Number(NetworkService.signalStrength || 0);
            return strength >= 80 ? "signal_wifi_4_bar" : strength >= 60 ? "network_wifi_3_bar" : strength
                                                                           >= 40 ? "network_wifi_2_bar" :
                                                                                   strength >= 20
                                                                                   ? "network_wifi_1_bar" :
                                                                                     "signal_wifi_0_bar";
        case "bluetooth":
            return BluetoothService.connected ? "bluetooth_connected" : BluetoothService.enabled
                                                ? "bluetooth" : "bluetooth_disabled";
        case "battery":
            if (!batteryAvailable)
                return "battery_android_question";
            if (PowerService.charging)
                return "battery_android_bolt";
            const level = PowerService.percentage;
            return level >= 0.95 ? "battery_android_full" : "battery_android_" + Math.max(0, Math.min(6, Math.floor(
                                                                                                          level * 7)));
        case "volume":
            return !Volume.outputAvailable || Volume.sinkMuted || Volume.sinkVolume <= 0 ? "volume_off" :
                                                                                           Volume.isHeadphone
                                                                                           ? "headphones" :
                                                                                             Volume.sinkVolume
                                                                                             < 0.5 ? "volume_down" :
                                                                                                     "volume_up";
        case "microphone":
            return !Volume.inputAvailable || Volume.sourceMuted ? "mic_off" : "mic";
        case "brightness":
            return "brightness_medium";
        default:
            return "monitor_heart";
        }
    }
    readonly property string tooltipText: {
        switch (itemId) {
        case "weather":
            return [WeatherPlugin.locationName, WeatherPlugin.hasValidData ? WeatherPlugin.currentWeatherText :
                                                                             WeatherPlugin.errorMessage,
                    root.displayText].filter(value => !!value).join("\n");
        case "media":
            return player ? [player.trackTitle, player.trackArtist, player.identity].filter(value => !!value).join(
                                "\n") : qsTr("No media");
        case "network":
            return NetworkService.connected ? NetworkService.activeConnection || qsTr("Network connected") :
                                              qsTr("Network disconnected");
        case "bluetooth":
            if (connectedDeviceNames.length > 0)
                return connectedDeviceNames.join("\n");
            return !BluetoothService.available ? qsTr("Bluetooth unavailable") : BluetoothService.enabled
                                                 ? qsTr("Bluetooth on") : qsTr("Bluetooth off");
        case "battery":
            if (!PowerService.ready)
                return qsTr("Detecting battery");
            if (!PowerService.present)
                return qsTr("No battery detected");
            const state = PowerService.full ? qsTr("Fully charged") : PowerService.charging ? qsTr("Charging") :
                                                                                              PowerService.discharging
                                                                                              ? qsTr("Discharging") :
                                                                                                qsTr("Plugged in");
            return qsTr("Battery: %1% · %2").arg(Math.round(PowerService.percentage * 100)).arg(state);
        case "brightness":
            return qsTr("Brightness: %1%\n%2\nScroll to adjust").arg(Math.round(brightness * 100)).arg(screen
                                                                                                       ? screen.name :
                                                                                                         "");
        case "volume":
            return !Volume.outputAvailable ? qsTr("No audio output") : (Volume.sinkMuted ? qsTr(
                                                                                               "Volume: muted\n%1").arg(
                                                                                               Volume.sinkName) :
                                                                                           qsTr("Volume: %1%\n%2").arg(
                                                                                               Math.round(
                                                                                                   Volume.sinkVolume
                                                                                                   * 100)).arg(
                                                                                               Volume.sinkName));
        case "microphone":
            return !Volume.inputAvailable ? qsTr("No audio input") : (Volume.sourceMuted ? qsTr(
                                                                                               "Microphone: muted\n%1").arg(
                                                                                               Volume.sourceName) :
                                                                                           qsTr("Microphone: %1%\n%2").arg(
                                                                                               Math.round(
                                                                                                   Volume.sourceVolume
                                                                                                   * 100)).arg(
                                                                                               Volume.sourceName));
        default:
            return [SystemMonitorService.statusText, qsTr(
                        "CPU: %1\nMemory: %2\nDisk: %3\nTemperature: %4").arg(Format.percent(
                                                                                  SystemMonitorService.cpu.usagePercent)).arg(
                        Format.percent(SystemMonitorService.memory.usagePercent)).arg(Format.percent(
                                                                                          Format.rootDisk(
                                                                                              SystemMonitorService.disks).usagePercent)).arg(
                        Format.temperature(Format.isNumber(
                                               SystemMonitorService.cpu.packageTemperatureCelsius)
                                           ? SystemMonitorService.cpu.packageTemperatureCelsius :
                                             SystemMonitorService.cpu.temperatureCelsius,
                                           UiPreferences.systemTemperatureUnit === "fahrenheit")),
                    SystemMonitorService.errorMessage].filter(value => !!value).join("\n");
        }
    }

    signal mediaRequested

    function activate(button) {
        if (itemId === "media") {
            if (button === Qt.MiddleButton && player && player.canTogglePlaying)
                player.togglePlaying();
            else
                mediaRequested();
            return;
        }
        if (button === Qt.MiddleButton && itemId === "volume") {
            Volume.toggleSinkMute();
            return;
        }
        if (button === Qt.MiddleButton && itemId === "microphone") {
            Volume.toggleSourceMute();
            return;
        }
        if (itemId === "systemMonitor") {
            WidgetState.dashboardSidebarView = "info";
            WidgetState.dashboardSidebarOpen = true;
            return;
        }
        const view = itemId === "volume" ? "audio" : itemId;
        if (["network", "bluetooth", "audio", "microphone"].indexOf(view) < 0)
            return;
        if (screen)
            WidgetState.quickSettingsScreenName = screen.name;
        if (WidgetState.quickSettingsOpen && WidgetState.quickSettingsView === view)
            WidgetState.quickSettingsOpen = false;
        else {
            WidgetState.quickSettingsView = view;
            WidgetState.quickSettingsOpen = true;
        }
    }

    implicitWidth: Math.max(32, contentLayout.implicitWidth + 12)
    implicitHeight: Math.max(32, contentLayout.implicitHeight + 12)
    Accessible.role: itemId === "battery" || itemId === "brightness" || itemId === "weather"
                     ? Accessible.StaticText : Accessible.Button

    Accessible.name: label
    Accessible.description: tooltipText
    Accessible.onPressAction: activate(Qt.LeftButton)
    Component.onCompleted: {
        if (itemId === "systemMonitor")
            SystemMonitorService.setConsumerModules(ownerId, ["cpu", "memory", "disk"]);
    }
    Component.onDestruction: {
        if (itemId === "systemMonitor")
            SystemMonitorService.clearConsumer(ownerId);
    }

    GridLayout {
        id: contentLayout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        rowSpacing: 4
        columnSpacing: 6

        MaterialSymbol {
            id: statusIcon
            Layout.alignment: Qt.AlignCenter
            text: root.iconName
            iconSize: 20
            fill: 1
            color: root.itemId === "battery" && root.batteryAvailable && PowerService.discharging
                   && PowerService.percentage <= 0.15 ? Appearance.colors.colError : pointer.containsMouse
                                                        ? Appearance.colors.colPrimary :
                                                          Appearance.colors.colOnSurface
        }

        Item {
            id: labelSlot
            readonly property real labelExtent: root.nameLabel ? Math.min(Math.max(0, root.maximumNameWidth),
                                                                          statusText.implicitWidth) :
                                                                 statusText.implicitWidth
            visible: root.displayText !== "" && (root.nameLabel ? PersonalizationConfig.keystoneLongShowNames :
                                                                  root.itemId === "weather"
                                                                  || PersonalizationConfig.keystoneLongShowValues)
            implicitWidth: root.rotateLabel ? statusText.implicitHeight : labelExtent
            implicitHeight: root.rotateLabel ? labelExtent : statusText.implicitHeight
            Layout.alignment: Qt.AlignCenter

            Item {
                id: labelViewport
                anchors.centerIn: parent
                width: labelSlot.labelExtent
                height: statusText.implicitHeight
                rotation: root.rotateLabel ? (root.edge === "left" ? -90 : 90) : 0
                clip: true
                readonly property bool overflowing: root.nameLabel && statusText.implicitWidth > width
                                                    && width > 0

                function restartScroll() {
                    labelScroll.stop();
                    labelStrip.x = 0;
                    if (overflowing && root.visible)
                        labelScroll.start();
                }

                onWidthChanged: Qt.callLater(restartScroll)
                onOverflowingChanged: Qt.callLater(restartScroll)
                Component.onCompleted: restartScroll()

                Item {
                    id: labelStrip
                    width: statusText.implicitWidth
                    height: parent.height

                    Text {
                        id: statusText
                        text: root.displayText
                        textFormat: Text.PlainText
                        font.family: root.nameLabel ? Fonts.ui : Fonts.numeric
                        font.pixelSize: 12
                        color: statusIcon.color
                        onTextChanged: Qt.callLater(labelViewport.restartScroll)
                        onImplicitWidthChanged: Qt.callLater(labelViewport.restartScroll)
                    }

                    Text {
                        x: statusText.implicitWidth + 32
                        text: root.displayText
                        textFormat: Text.PlainText
                        font: statusText.font
                        color: statusText.color
                        visible: labelViewport.overflowing
                    }
                }

                Connections {
                    target: root
                    function onVisibleChanged() {
                        labelViewport.restartScroll();
                    }
                }

                SequentialAnimation {
                    id: labelScroll
                    loops: Animation.Infinite
                    PropertyAction {
                        target: labelStrip
                        property: "x"
                        value: 0
                    }
                    PauseAnimation {
                        duration: 1200
                    }
                    NumberAnimation {
                        target: labelStrip
                        property: "x"
                        from: 0
                        to: -(statusText.implicitWidth + 32)
                        duration: (statusText.implicitWidth + 32) * 35
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: root.itemId === "battery" || root.itemId === "brightness" || root.itemId === "weather"
                     ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: mouse => root.activate(mouse.button)
        onWheel: wheel => {
            const delta = wheel.angleDelta.y || wheel.angleDelta.x;
            if (!delta)
                return;
            const step = delta > 0 ? 0.05 : -0.05;
            if (root.itemId === "volume" && Volume.outputAvailable)
                Volume.setSinkVolume(Volume.sinkVolume + step);
            else if (root.itemId === "microphone" && Volume.inputAvailable)
                Volume.setSourceVolume(Volume.sourceVolume + step);
            else if (root.itemId === "brightness")
                Brightness.setBrightnessForScreen(root.screen, root.brightness + step);
            else {
                wheel.accepted = false;
                return;
            }
            wheel.accepted = true;
        }
    }

    PopupToolTip {
        extraVisibleCondition: pointer.containsMouse
        text: root.tooltipText
        textFormat: Text.PlainText
    }
}
