pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Common/functions/AwwwCommand.js" as AwwwCommand

Singleton {
    id: root

    readonly property string namespaceName: "clavis-desktop"
    readonly property string awwwCommand:
        Quickshell.env("CLAVIS_AWWW_COMMAND") || "awww"
    readonly property string daemonCommand:
        Quickshell.env("CLAVIS_AWWW_DAEMON_COMMAND")
            || "awww-daemon"

    property bool primaryInstance: false
    property bool available: false
    property bool probeComplete: false
    property bool daemonRunning: false
    property bool daemonStopRequested: false
    property bool quickshellContentVisible: true
    property string requestedBackend: "quickshell"
    property string effectiveBackend: "quickshell"
    property string state: "probing"
    property string lastError: ""

    property int queryAttempts: 0
    property bool daemonStartAttempted: false
    property var applyOutputs: []
    property int applyIndex: 0
    property bool reapplyPending: false
    property string activeApplyKey: ""
    property string pendingApplyKey: ""
    property string lastAppliedKey: ""
    property var activeTransitionOptions: ({})

    readonly property bool busy:
        state === "starting"
        || state === "waiting-socket"
        || state === "applying"
        || state === "stopping"

    function backendIsAwww() {
        return PersonalizationConfig.desktopWallpaperBackend === "awww";
    }

    function screenNames() {
        const names = [];
        for (let index = 0; index < Quickshell.screens.length;
                index += 1) {
            names.push(String(Quickshell.screens[index].name));
        }
        return names;
    }

    function transitionOptions() {
        return {
            type: PersonalizationConfig.awwwDesktopTransitionType,
            fps: PersonalizationConfig.awwwTransitionFps,
            step: PersonalizationConfig.awwwTransitionStep,
            durationMs: PersonalizationConfig.transitionDurationMs,
            easingMode:
                PersonalizationConfig.transitionEasingMode,
            bezierCurve:
                PersonalizationConfig.transitionBezierCurve,
            angle: PersonalizationConfig.awwwTransitionAngle,
            position:
                PersonalizationConfig.awwwTransitionPosition,
            wave: PersonalizationConfig.awwwTransitionWave
        };
    }

    function applyRequestKey() {
        const outputs = root.screenNames();
        const targets = [];
        for (let index = 0; index < outputs.length; index += 1) {
            const output = outputs[index];
            targets.push({
                output: output,
                source: WallpaperService.wallpaperForScreen(output),
                fillMode: WallpaperService.fillModeForScreen(output)
            });
        }
        return JSON.stringify({
            revision: WallpaperService.revision,
            settingsRevision: WallpaperService.settingsRevision,
            targets: targets,
            transition: root.transitionOptions()
        });
    }

    function supportsDuration(transitionType) {
        return AwwwCommand.supportsDuration(transitionType);
    }

    function supportsBezier(transitionType) {
        return AwwwCommand.supportsBezier(transitionType);
    }

    function supportsStep(transitionType) {
        return AwwwCommand.supportsStep(transitionType);
    }

    function setRequestedBackend(value) {
        const backend = value === "awww" ? "awww" : "quickshell";
        root.requestedBackend = backend;
        if (!root.primaryInstance) {
            root.quickshellContentVisible = true;
            root.effectiveBackend = "quickshell";
            root.state = root.probeComplete ? "passive" : "probing";
            return;
        }
        if (backend === "awww")
            root.beginAwwwActivation();
        else
            root.beginQuickshellActivation();
    }

    function beginAwwwActivation() {
        if (!root.primaryInstance)
            return;
        if (!root.probeComplete) {
            root.state = "probing";
            return;
        }

        if (!root.available) {
            root.lastError =
                qsTr("未找到 awww 或 awww-daemon，已回退到 Quickshell");
            root.quickshellContentVisible = true;
            root.effectiveBackend = "quickshell";
            root.state = "error";
            if (root.backendIsAwww())
                PersonalizationConfig
                    .setDesktopWallpaperBackend("quickshell");
            return;
        }

        if (stopProcess.running || root.daemonStopRequested) {
            root.quickshellContentVisible = true;
            root.state = "starting";
            return;
        }

        root.lastError = "";
        root.quickshellContentVisible = true;
        if (root.effectiveBackend === "awww"
                && root.daemonRunning
                && root.state === "ready") {
            root.scheduleApplyAll();
            return;
        }

        root.state = "starting";
        root.queryAttempts = 0;
        root.daemonStartAttempted = false;
        root.runQuery();
    }

    function beginQuickshellActivation() {
        if (!root.primaryInstance)
            return;
        queryRetry.stop();
        root.quickshellContentVisible = true;
        root.effectiveBackend = "quickshell";
        root.lastError = "";
        root.applyOutputs = [];
        root.applyIndex = 0;
        root.reapplyPending = false;
        root.activeApplyKey = "";
        root.pendingApplyKey = "";
        root.lastAppliedKey = "";
        root.activeTransitionOptions = ({});

        if (root.daemonRunning || daemonProcess.running) {
            root.state = "stopping";
            root.stopDaemon();
        } else {
            root.state = "ready";
        }
    }

    function failAwwwActivation(message) {
        root.lastError = message || qsTr("awww 桌面后端启动失败");
        root.quickshellContentVisible = true;
        root.effectiveBackend = "quickshell";
        root.state = "error";
        root.applyOutputs = [];
        root.applyIndex = 0;
        root.reapplyPending = false;
        root.activeApplyKey = "";
        root.pendingApplyKey = "";
        root.lastAppliedKey = "";
        root.activeTransitionOptions = ({});
        if (root.daemonRunning || daemonProcess.running)
            root.stopDaemon();
    }

    function runQuery() {
        if (!root.primaryInstance
                || queryProcess.running || !root.backendIsAwww())
            return;
        root.state = "waiting-socket";
        queryProcess.command = AwwwCommand.query(
            root.awwwCommand, root.namespaceName);
        queryProcess.running = true;
    }

    function startDaemon() {
        if (!root.primaryInstance || !root.backendIsAwww())
            return;
        root.daemonStartAttempted = true;
        if (daemonProcess.running) {
            queryRetry.restart();
            return;
        }
        root.state = "starting";
        daemonProcess.command = AwwwCommand.daemon(
            root.daemonCommand, root.namespaceName);
        daemonProcess.running = true;
    }

    function scheduleApplyAll() {
        if (!root.primaryInstance || !root.backendIsAwww()
                || !root.available || !root.daemonRunning)
            return;
        const requestKey = root.applyRequestKey();
        if (applyProcess.running || root.state === "applying") {
            if (requestKey === root.activeApplyKey
                    || requestKey === root.pendingApplyKey)
                return;
            root.reapplyPending = true;
            root.pendingApplyKey = requestKey;
            return;
        }
        if (requestKey === root.lastAppliedKey)
            return;

        root.applyOutputs = root.screenNames();
        root.applyIndex = 0;
        root.activeApplyKey = requestKey;
        root.pendingApplyKey = "";
        root.activeTransitionOptions =
            AwwwCommand.resolvedTransitionOptions(
                root.transitionOptions(), Math.random(), Math.random());
        root.state = "applying";
        root.applyNext();
    }

    function applyNext() {
        if (!root.backendIsAwww()) {
            root.applyOutputs = [];
            root.applyIndex = 0;
            root.reapplyPending = false;
            return;
        }

        if (root.applyIndex >= root.applyOutputs.length) {
            root.applyOutputs = [];
            root.applyIndex = 0;
            root.lastError = "";
            root.effectiveBackend = "awww";
            root.quickshellContentVisible = false;
            root.state = "ready";
            root.lastAppliedKey = root.activeApplyKey;
            root.activeApplyKey = "";
            root.activeTransitionOptions = ({});

            if (root.reapplyPending) {
                root.reapplyPending = false;
                root.pendingApplyKey = "";
                Qt.callLater(() => {
                    if (root.backendIsAwww())
                        root.scheduleApplyAll();
                });
            }
            return;
        }

        const output = root.applyOutputs[root.applyIndex];
        const source = WallpaperService.wallpaperForScreen(output);
        if (!source) {
            root.failAwwwActivation(
                qsTr("没有可应用到 %1 的桌面壁纸").arg(output));
            return;
        }

        applyProcess.outputName = output;
        applyProcess.command = AwwwCommand.apply(
            root.awwwCommand,
            root.namespaceName,
            output,
            source,
            WallpaperService.fillModeForScreen(output),
            root.activeTransitionOptions);
        applyProcess.running = true;
    }

    function stopDaemon() {
        if (!root.primaryInstance)
            return;
        root.daemonStopRequested = true;
        if (stopProcess.running)
            return;
        stopProcess.command = AwwwCommand.stop(
            root.awwwCommand, root.namespaceName);
        stopProcess.running = true;
    }

    Component.onCompleted: probeClient.running = true

    onPrimaryInstanceChanged: {
        if (root.primaryInstance && root.probeComplete) {
            root.setRequestedBackend(
                PersonalizationConfig.desktopWallpaperBackend);
        }
    }

    Connections {
        target: PersonalizationConfig
        enabled: root.primaryInstance

        function onDesktopWallpaperBackendChanged() {
            root.setRequestedBackend(
                PersonalizationConfig.desktopWallpaperBackend);
        }
    }

    Connections {
        target: WallpaperService
        enabled: root.primaryInstance

        function onRevisionChanged() {
            if (root.backendIsAwww()
                    && root.effectiveBackend === "awww")
                root.scheduleApplyAll();
        }

        function onSettingsRevisionChanged() {
            if (root.backendIsAwww()
                    && root.effectiveBackend === "awww")
                root.scheduleApplyAll();
        }
    }

    Connections {
        target: Quickshell
        enabled: root.primaryInstance

        function onScreensChanged() {
            if (root.backendIsAwww()
                    && root.effectiveBackend === "awww")
                root.scheduleApplyAll();
        }
    }

    Process {
        id: probeClient
        command: ["which", root.awwwCommand]
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.available = false;
                root.probeComplete = true;
                root.setRequestedBackend(
                    PersonalizationConfig.desktopWallpaperBackend);
                return;
            }
            probeDaemon.running = true;
        }
    }

    Process {
        id: probeDaemon
        command: ["which", root.daemonCommand]
        onExited: exitCode => {
            root.available = exitCode === 0;
            root.probeComplete = true;
            root.setRequestedBackend(
                PersonalizationConfig.desktopWallpaperBackend);
        }
    }

    Process {
        id: daemonProcess

        onRunningChanged: {
            if (!running)
                return;
            root.daemonRunning = true;
            if (root.backendIsAwww()) {
                root.queryAttempts = 0;
                queryRetry.restart();
            } else {
                root.stopDaemon();
            }
        }

        onExited: exitCode => {
            const expectedStop = root.daemonStopRequested;
            root.daemonRunning = false;
            if (expectedStop) {
                root.daemonStopRequested = false;
                if (root.backendIsAwww()
                        && root.state !== "error")
                    root.beginAwwwActivation();
                else if (!root.backendIsAwww())
                    root.state = "ready";
                return;
            }
            if (!root.backendIsAwww()) {
                root.state = "ready";
                return;
            }
            if (root.state === "starting"
                    || root.state === "waiting-socket"
                    || root.state === "error") {
                return;
            }
            root.failAwwwActivation(
                qsTr("awww-daemon 意外退出，退出码 %1")
                    .arg(exitCode));
        }
    }

    Process {
        id: queryProcess

        onExited: exitCode => {
            if (!root.backendIsAwww()) {
                if (exitCode === 0) {
                    root.daemonRunning = true;
                    root.stopDaemon();
                }
                return;
            }

            if (exitCode === 0) {
                queryRetry.stop();
                root.daemonRunning = true;
                root.queryAttempts = 0;
                if (root.daemonStartAttempted) {
                    root.scheduleApplyAll();
                } else {
                    root.lastError = "";
                    root.effectiveBackend = "awww";
                    root.quickshellContentVisible = false;
                    root.state = "ready";
                }
                return;
            }

            if (!root.daemonStartAttempted) {
                root.startDaemon();
                return;
            }

            root.queryAttempts += 1;
            if (root.queryAttempts >= 20) {
                root.failAwwwActivation(
                    qsTr("awww namespace clavis-desktop 未在超时前就绪"));
                return;
            }
            queryRetry.restart();
        }
    }

    Timer {
        id: queryRetry
        interval: 100
        repeat: false
        onTriggered: {
            if (root.backendIsAwww())
                root.runQuery();
        }
    }

    Process {
        id: applyProcess

        property string outputName: ""

        onExited: exitCode => {
            if (!root.backendIsAwww()) {
                root.applyOutputs = [];
                root.applyIndex = 0;
                root.reapplyPending = false;
                return;
            }

            if (exitCode !== 0) {
                const message =
                    qsTr("awww 无法为 %1 应用桌面壁纸，退出码 %2")
                        .arg(outputName).arg(exitCode);
                WallpaperService.reportDesktopError(
                    outputName, message);
                root.failAwwwActivation(message);
                return;
            }

            WallpaperService.clearDesktopError(outputName);
            root.applyIndex += 1;
            root.applyNext();
        }
    }

    Process {
        id: stopProcess

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.daemonStopRequested = false;
                root.lastError =
                    qsTr("停止 clavis-desktop awww namespace 失败，退出码 %1")
                        .arg(exitCode);
                root.state = "error";
                return;
            }

            if (daemonProcess.running)
                return;

            root.daemonRunning = false;
            root.daemonStopRequested = false;
            if (root.backendIsAwww()) {
                if (root.state !== "error")
                    root.beginAwwwActivation();
                return;
            }
            root.lastError = "";
            root.state = "ready";
        }
    }
}
