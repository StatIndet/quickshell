pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    signal brightnessChanged()

    property var ddcMonitors: []
    property var pendingDdcMonitors: []
    property real fallbackBrightnessValue: 0.5
    property var monitors: []
    property string focusedScreenName: ""
    readonly property var activeScreen: root.getScreenByName(root.focusedScreenName) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    readonly property var activeMonitor: root.getMonitorByName(root.focusedScreenName) || (root.monitors.length > 0 ? root.monitors[0] : null)
    readonly property real brightnessValue: root.activeMonitor ? root.activeMonitor.brightness : root.fallbackBrightnessValue

    Component.onCompleted: {
        root.rebuildMonitors();
        root.refreshFocusedOutput();
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.rebuildMonitors();
        }
    }

    function rebuildMonitors() {
        for (let i = 0; i < root.monitors.length; i += 1)
            root.monitors[i].destroy();

        const next = [];
        for (let i = 0; i < Quickshell.screens.length; i += 1)
            next.push(monitorComponent.createObject(root, {
                screen: Quickshell.screens[i]
            }));

        root.monitors = next;
        root.rescanDdcMonitors();
    }

    function refreshFocusedOutput() {
        if (!focusedOutputProcess.running)
            focusedOutputProcess.running = true;
    }

    function parseFocusedOutput(text) {
        const firstLine = String(text || "").split("\n")[0] || "";
        const match = firstLine.match(/\(([^)]+)\)/);
        if (!match)
            return;

        const screenName = root.normalizeConnectorName(match[1]);
        if (screenName.length > 0)
            root.focusedScreenName = screenName;
    }

    function clampBrightness(value, allowZero) {
        const numericValue = Number(value);
        const safeValue = isNaN(numericValue) ? root.fallbackBrightnessValue : numericValue;
        return Math.max(allowZero ? 0.0 : 0.01, Math.min(1.0, safeValue));
    }

    function normalizeConnectorName(name) {
        const raw = String(name || "").trim();
        if (raw.length === 0)
            return "";
        return raw.replace(/^card[0-9]+-/, "");
    }

    function getMonitorForScreen(screen) {
        if (!screen)
            return root.activeMonitor;
        return root.getMonitorByName(screen.name);
    }

    function getScreenByName(name) {
        const normalizedName = root.normalizeConnectorName(name);
        if (normalizedName.length === 0)
            return null;
        return Quickshell.screens.find(screen => root.normalizeConnectorName(screen.name) === normalizedName) || null;
    }

    function getMonitorByName(name) {
        const normalizedName = root.normalizeConnectorName(name);
        if (normalizedName.length === 0)
            return null;
        return root.monitors.find(m => root.normalizeConnectorName(m.screenName) === normalizedName) || null;
    }

    function setBrightness(val, allowZero) {
        root.setBrightnessForScreen(null, val, allowZero);
    }

    function setBrightnessForScreen(screen, val, allowZero) {
        const monitor = root.getMonitorForScreen(screen);
        if (monitor) {
            monitor.setBrightness(val, allowZero);
            return;
        }

        const safeVal = root.clampBrightness(val, allowZero);
        const pct = Math.round(safeVal * 100);
        fallbackBrightnessValue = safeVal;
        fallbackSetProc.exec(["brightnessctl", "--class", "backlight", "s", pct + "%", "--quiet"]);
        root.brightnessChanged();
    }

    function rescanDdcMonitors() {
        if (ddcDetectProcess.running)
            ddcDetectProcess.running = false;
        pendingDdcMonitors = [];
        ddcDetectProcess.running = true;
    }

    function parseDdcBlock(data) {
        const block = String(data || "").trim();
        if (!block.startsWith("Display "))
            return;

        const lines = block.split("\n").map(line => line.trim());
        const busLine = lines.find(line => line.startsWith("I2C bus:"));
        const connectorLine = lines.find(line => line.startsWith("DRM connector:"));
        if (!busLine || !connectorLine)
            return;

        const busMatch = busLine.match(/\/dev\/i2c-([0-9]+)/);
        const connector = root.normalizeConnectorName(connectorLine.split(":").slice(1).join(":"));
        if (!busMatch || connector.length === 0)
            return;

        const next = pendingDdcMonitors.slice();
        next.push({
            name: connector,
            busNum: busMatch[1]
        });
        pendingDdcMonitors = next;
    }

    function initializeMonitor(index) {
        if (index >= root.monitors.length)
            return;
        root.monitors[index].initialize();
    }

    Process {
        id: ddcDetectProcess

        command: ["ddcutil", "detect", "--brief"]

        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => root.parseDdcBlock(data)
        }

        onExited: {
            root.ddcMonitors = root.pendingDdcMonitors;
            root.pendingDdcMonitors = [];
            root.initializeMonitor(0);
        }
    }

    Process {
        id: fallbackSetProc
    }

    Process {
        id: focusedOutputProcess

        command: ["niri", "msg", "focused-output"]

        stdout: StdioCollector {
            onStreamFinished: root.parseFocusedOutput(this.text)
        }
    }

    Timer {
        id: pollTimer

        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (root.activeMonitor && !root.activeMonitor.isDdc)
                root.activeMonitor.refresh();
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refreshFocusedOutput()
    }

    Component {
        id: monitorComponent

        QtObject {
            id: monitor

            required property var screen
            readonly property string screenName: screen ? screen.name : ""
            property bool isDdc: false
            property string busNum: ""
            property int rawMaxBrightness: 100
            property real brightness: root.fallbackBrightnessValue
            property bool ready: false
            property bool pendingSync: false
            property bool reading: false

            onBrightnessChanged: {
                if (reading)
                    return;

                root.fallbackBrightnessValue = brightness;
                root.brightnessChanged();

                if (!ready) {
                    pendingSync = true;
                    return;
                }

                scheduleSync();
            }

            function initialize() {
                ready = false;
                pendingSync = false;

                const connectorName = root.normalizeConnectorName(screenName);
                const match = root.ddcMonitors.find(m => root.normalizeConnectorName(m.name) === connectorName);
                isDdc = !!match;
                busNum = match ? match.busNum : "";
                refresh();
            }

            function refresh() {
                reading = true;
                if (isDdc)
                    readProcess.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
                else
                    readProcess.command = ["brightnessctl", "--class", "backlight", "-m"];
                readProcess.running = true;
            }

            function parseReadOutput(text) {
                const data = String(text || "").trim();
                if (data.length === 0)
                    return;

                if (isDdc) {
                    const fields = data.split(/\s+/);
                    if (fields.length < 5)
                        return;
                    const current = parseInt(fields[3]);
                    const max = parseInt(fields[4]);
                    if (!isNaN(current) && !isNaN(max) && max > 0) {
                        rawMaxBrightness = max;
                        brightness = Math.max(0, Math.min(1, current / max));
                    }
                    return;
                }

                const parts = data.split(",");
                if (parts.length < 5)
                    return;

                const percent = parseInt(parts[3].replace("%", ""));
                const max = parseInt(parts[4]);
                if (!isNaN(max) && max > 0)
                    rawMaxBrightness = max;
                if (!isNaN(percent))
                    brightness = Math.max(0, Math.min(1, percent / 100.0));
            }

            function setBrightness(value, allowZero) {
                brightness = root.clampBrightness(value, allowZero);
            }

            function scheduleSync() {
                if (isDdc)
                    ddcSetTimer.restart();
                else
                    syncBrightness();
            }

            function syncBrightness() {
                const safeBrightness = Math.max(0, Math.min(1, brightness));
                if (isDdc) {
                    const rawValue = Math.max(1, Math.floor(safeBrightness * rawMaxBrightness));
                    setProcess.exec(["ddcutil", "-b", busNum, "setvcp", "10", String(rawValue)]);
                    return;
                }

                const percent = Math.round(safeBrightness * 100);
                setProcess.exec(["brightnessctl", "--class", "backlight", "s", percent + "%", "--quiet"]);
            }

            readonly property Process readProcess: Process {
                stdout: StdioCollector {
                    onStreamFinished: monitor.parseReadOutput(this.text)
                }

                onExited: {
                    monitor.reading = false;
                    monitor.ready = true;

                    if (monitor.pendingSync) {
                        monitor.pendingSync = false;
                        monitor.scheduleSync();
                    }

                    root.initializeMonitor(root.monitors.indexOf(monitor) + 1);
                }
            }

            readonly property Process setProcess: Process {}

            readonly property Timer ddcSetTimer: Timer {
                id: ddcSetTimer

                interval: 300
                running: false
                repeat: false
                onTriggered: monitor.syncBrightness()
            }
        }
    }
}
