pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common

Singleton {
    id: root

    // Policy defaults intentionally avoid automatic suspend and brightness changes.
    // Every stage remains independently configurable through configureStage().
    property bool policyEnabled: true
    // An external owner (Idle Control) can pause the in-shell timers without
    // overwriting the user's saved QuickShell policy.
    property bool externalOwner: false
    property bool dimEnabled: false
    property real dimTimeout: 300
    property bool dimRespectInhibitors: true
    property real dimFraction: 0.35

    property bool lockEnabled: true
    property real lockTimeout: 600
    property bool lockRespectInhibitors: true

    property bool displayOffEnabled: true
    property real displayOffTimeout: 900
    property bool displayOffRespectInhibitors: true

    property bool suspendEnabled: false
    property real suspendTimeout: 1800
    property bool suspendRespectInhibitors: true

    readonly property string policyConfigDir: Paths.configHome
    readonly property string policyConfigPath: policyConfigDir + "/idle-policy.json"
    readonly property bool policyReady: policyStoreReady && !policyLoading
    property bool policyStoreReady: false
    property bool policyLoading: true

    property bool inhibited: false
    property bool dimmed: false
    property bool displaysOff: false
    readonly property bool busy: lockPending || displayPowerProcess.running || suspendProcess.running
    property string lastError: ""

    readonly property var stages: [
        {
            "name": "dim",
            "enabled": dimEnabled,
            "timeout": dimTimeout,
            "respectInhibitors": dimRespectInhibitors,
            "active": dimMonitor.isIdle
        },
        {
            "name": "lock",
            "enabled": lockEnabled,
            "timeout": lockTimeout,
            "respectInhibitors": lockRespectInhibitors,
            "active": lockMonitor.isIdle
        },
        {
            "name": "displayOff",
            "enabled": displayOffEnabled,
            "timeout": displayOffTimeout,
            "respectInhibitors": displayOffRespectInhibitors,
            "active": displayOffMonitor.isIdle
        },
        {
            "name": "suspend",
            "enabled": suspendEnabled,
            "timeout": suspendTimeout,
            "respectInhibitors": suspendRespectInhibitors,
            "active": suspendMonitor.isIdle
        }
    ]

    property bool lockPending: false
    property bool _desiredDisplaysOff: false
    property bool _displayCommandTargetOff: false
    property var _savedBrightness: ({})

    signal operationStarted(string operation)
    signal operationSucceeded(string operation)
    signal operationFailed(string operation, string message)
    signal lockRequested()

    function setInhibited(value) {
        const requested = !!value;
        if (root.inhibited === requested)
            return;

        root.lastError = "";
        root.operationStarted("set-inhibited");
        root.inhibited = requested;
        root.savePolicy();
        root.operationSucceeded("set-inhibited");
    }

    function toggleInhibited() {
        root.setInhibited(!root.inhibited);
    }

    function toggle() {
        root.toggleInhibited();
    }

    function setPolicyEnabled(value) {
        const requested = !!value;
        if (root.policyEnabled === requested)
            return;
        root.lastError = "";
        root.operationStarted("set-policy-enabled");
        root.policyEnabled = requested;
        root.savePolicy();
        root.operationSucceeded("set-policy-enabled");
    }

    function setExternalOwner(value) {
        const requested = !!value;
        if (root.externalOwner === requested)
            return "UNCHANGED";
        root.externalOwner = requested;
        if (requested) {
            root._setDimmed(false);
            root._setDisplaysOff(false);
        }
        return requested ? "EXTERNAL_OWNER" : "QUICKSHELL_OWNER";
    }

    function openController() {
        Quickshell.execDetached(["idle-control-desktop"]);
    }

    function setDimFraction(value) {
        const requested = Math.max(0.05, Math.min(1, Number(value || 0)));
        if (Math.abs(root.dimFraction - requested) < 0.0001)
            return;
        root.lastError = "";
        root.operationStarted("set-dim-fraction");
        root.dimFraction = requested;
        root.savePolicy();
        root.operationSucceeded("set-dim-fraction");
    }

    function configureStage(stage, enabled, timeout, respectInhibitors = true) {
        const name = String(stage || "");
        if (["dim", "lock", "displayOff", "suspend"].indexOf(name) === -1) {
            root.lastError = qsTr("未知 Idle 阶段: ") + name;
            root.operationFailed("configure-stage", root.lastError);
            return;
        }

        const normalizedTimeout = Math.max(0, Number(timeout || 0));
        root.lastError = "";
        root.operationStarted("configure-stage");
        root[name + "Enabled"] = !!enabled;
        root[name + "Timeout"] = normalizedTimeout;
        root[name + "RespectInhibitors"] = !!respectInhibitors;
        root.savePolicy();
        root.operationSucceeded("configure-stage");
    }

    function _policyDefaults() {
        return {
            "inhibited": false,
            "policyEnabled": true,
            "dimEnabled": false,
            "dimTimeout": 300,
            "dimRespectInhibitors": true,
            "dimFraction": 0.35,
            "lockEnabled": true,
            "lockTimeout": 600,
            "lockRespectInhibitors": true,
            "displayOffEnabled": true,
            "displayOffTimeout": 900,
            "displayOffRespectInhibitors": true,
            "suspendEnabled": false,
            "suspendTimeout": 1800,
            "suspendRespectInhibitors": true
        };
    }

    function _policyBool(data, key, fallback) {
        return typeof data[key] === "boolean" ? data[key] : fallback;
    }

    function _policyNumber(data, key, fallback, minimum, maximum) {
        const value = Number(data[key]);
        if (!Number.isFinite(value))
            return fallback;
        return Math.max(minimum, Math.min(maximum, value));
    }

    function needsPolicyMigration(data) {
        return !data || typeof data !== "object" || Array.isArray(data)
            || typeof data.inhibited !== "boolean";
    }

    function loadPolicy(data) {
        const values = data && typeof data === "object" ? data : {};
        const defaults = root._policyDefaults();
        root.policyLoading = true;
        root.inhibited = root._policyBool(
            values, "inhibited", defaults.inhibited);
        root.policyEnabled = root._policyBool(values, "policyEnabled", defaults.policyEnabled);
        root.dimEnabled = root._policyBool(values, "dimEnabled", defaults.dimEnabled);
        root.dimTimeout = root._policyNumber(values, "dimTimeout", defaults.dimTimeout, 0, 86400);
        root.dimRespectInhibitors = root._policyBool(values, "dimRespectInhibitors", defaults.dimRespectInhibitors);
        root.dimFraction = root._policyNumber(values, "dimFraction", defaults.dimFraction, 0.05, 1);
        root.lockEnabled = root._policyBool(values, "lockEnabled", defaults.lockEnabled);
        root.lockTimeout = root._policyNumber(values, "lockTimeout", defaults.lockTimeout, 0, 86400);
        root.lockRespectInhibitors = root._policyBool(values, "lockRespectInhibitors", defaults.lockRespectInhibitors);
        root.displayOffEnabled = root._policyBool(values, "displayOffEnabled", defaults.displayOffEnabled);
        root.displayOffTimeout = root._policyNumber(values, "displayOffTimeout", defaults.displayOffTimeout, 0, 86400);
        root.displayOffRespectInhibitors = root._policyBool(values, "displayOffRespectInhibitors", defaults.displayOffRespectInhibitors);
        root.suspendEnabled = root._policyBool(values, "suspendEnabled", defaults.suspendEnabled);
        root.suspendTimeout = root._policyNumber(values, "suspendTimeout", defaults.suspendTimeout, 0, 86400);
        root.suspendRespectInhibitors = root._policyBool(values, "suspendRespectInhibitors", defaults.suspendRespectInhibitors);
        root.policyLoading = false;
    }

    function policyJson() {
        return {
            "inhibited": root.inhibited,
            "policyEnabled": root.policyEnabled,
            "dimEnabled": root.dimEnabled,
            "dimTimeout": root.dimTimeout,
            "dimRespectInhibitors": root.dimRespectInhibitors,
            "dimFraction": root.dimFraction,
            "lockEnabled": root.lockEnabled,
            "lockTimeout": root.lockTimeout,
            "lockRespectInhibitors": root.lockRespectInhibitors,
            "displayOffEnabled": root.displayOffEnabled,
            "displayOffTimeout": root.displayOffTimeout,
            "displayOffRespectInhibitors": root.displayOffRespectInhibitors,
            "suspendEnabled": root.suspendEnabled,
            "suspendTimeout": root.suspendTimeout,
            "suspendRespectInhibitors": root.suspendRespectInhibitors
        };
    }

    function savePolicy() {
        if (!root.policyStoreReady || root.policyLoading)
            return;
        policyFile.setText(JSON.stringify(root.policyJson(), null, 2));
    }

    function _monitorEnabled(stageEnabled, timeout, respectInhibitors) {
        return root.policyEnabled
            && !root.externalOwner
            && stageEnabled
            && timeout > 0
            && !(respectInhibitors && root.inhibited);
    }

    function _setDimmed(value) {
        const requested = !!value;
        if (root.dimmed === requested)
            return;

        if (requested) {
            const saved = {};
            for (const monitor of Brightness.monitors) {
                if (!monitor || !monitor.screen)
                    continue;
                saved[monitor.screenName] = Number(monitor.brightness);
                Brightness.setBrightnessForScreen(
                    monitor.screen,
                    Math.max(0.05, Number(monitor.brightness) * root.dimFraction)
                );
            }
            root._savedBrightness = saved;
            root.dimmed = true;
            return;
        }

        const previous = root._savedBrightness;
        root._savedBrightness = {};
        root.dimmed = false;
        for (const monitor of Brightness.monitors) {
            if (!monitor || !monitor.screen || previous[monitor.screenName] === undefined)
                continue;
            Brightness.setBrightnessForScreen(monitor.screen, Number(previous[monitor.screenName]));
        }
    }

    function _requestLock() {
        if (root.lockPending)
            return;
        root.lastError = "";
        root.lockPending = true;
        root.operationStarted("lock");
        root.lockRequested();
    }

    function reportLockResult(result) {
        if (!root.lockPending)
            return;
        root.lockPending = false;
        if (result === "LOCKED" || result === "ALREADY_LOCKED") {
            root.operationSucceeded("lock");
            return;
        }
        root.lastError = qsTr("锁屏请求失败: ") + String(result || "unknown");
        root.operationFailed("lock", root.lastError);
    }

    function _setDisplaysOff(value) {
        root._desiredDisplaysOff = !!value;
        if (displayPowerProcess.running)
            return;
        if (root.displaysOff === root._desiredDisplaysOff)
            return;

        root._displayCommandTargetOff = root._desiredDisplaysOff;
        root.lastError = "";
        root.operationStarted(root._displayCommandTargetOff ? "display-off" : "display-on");
        displayPowerProcess.exec([
            "niri",
            "msg",
            "action",
            root._displayCommandTargetOff ? "power-off-monitors" : "power-on-monitors"
        ]);
    }

    function _requestSuspend() {
        if (suspendProcess.running)
            return;
        root.lastError = "";
        root.operationStarted("suspend");
        suspendProcess.exec(["loginctl", "suspend"]);
    }

    IdleInhibitorSurface {
        id: inhibitorSurface
    }

    IdleInhibitor {
        window: inhibitorSurface
        enabled: root.inhibited
    }

    IdleMonitor {
        id: dimMonitor
        timeout: Math.max(1, root.dimTimeout)
        respectInhibitors: root.dimRespectInhibitors
        enabled: root._monitorEnabled(root.dimEnabled, root.dimTimeout, root.dimRespectInhibitors)

        onIsIdleChanged: root._setDimmed(isIdle)
    }

    IdleMonitor {
        id: lockMonitor
        timeout: Math.max(1, root.lockTimeout)
        respectInhibitors: root.lockRespectInhibitors
        enabled: root._monitorEnabled(root.lockEnabled, root.lockTimeout, root.lockRespectInhibitors)

        onIsIdleChanged: {
            if (isIdle)
                root._requestLock();
        }
    }

    IdleMonitor {
        id: displayOffMonitor
        timeout: Math.max(1, root.displayOffTimeout)
        respectInhibitors: root.displayOffRespectInhibitors
        enabled: root._monitorEnabled(
            root.displayOffEnabled,
            root.displayOffTimeout,
            root.displayOffRespectInhibitors
        )

        onIsIdleChanged: root._setDisplaysOff(isIdle)
    }

    IdleMonitor {
        id: suspendMonitor
        timeout: Math.max(1, root.suspendTimeout)
        respectInhibitors: root.suspendRespectInhibitors
        enabled: root._monitorEnabled(
            root.suspendEnabled,
            root.suspendTimeout,
            root.suspendRespectInhibitors
        )

        onIsIdleChanged: {
            if (isIdle)
                root._requestSuspend();
        }
    }

    Process {
        id: ensurePolicyStore

        command: ["mkdir", "-p", root.policyConfigDir]
        running: true
        onExited: {
            root.policyStoreReady = true;
            policyFile.reload();
        }
    }

    FileView {
        id: policyFile

        path: root.policyConfigPath
        blockLoading: true
        blockWrites: true
        atomicWrites: true

        onLoaded: {
            let repair = false;
            try {
                const parsed = JSON.parse(policyFile.text().trim() || "{}");
                repair = root.needsPolicyMigration(parsed);
                root.loadPolicy(parsed);
            } catch (error) {
                console.log("IdleService failed to load policy:", error);
                root.loadPolicy({});
                repair = true;
            }
            if (repair)
                root.savePolicy();
        }

        onLoadFailed: {
            root.loadPolicy({});
            root.savePolicy();
        }
    }

    Process {
        id: displayPowerProcess

        onExited: exitCode => {
            const operation = root._displayCommandTargetOff ? "display-off" : "display-on";
            if (exitCode === 0) {
                root.displaysOff = root._displayCommandTargetOff;
                root.operationSucceeded(operation);
            } else {
                root.lastError = qsTr("niri 显示器电源动作失败，退出码 ") + exitCode;
                root.operationFailed(operation, root.lastError);
            }

            if (root.displaysOff !== root._desiredDisplaysOff)
                Qt.callLater(root._setDisplaysOff, root._desiredDisplaysOff);
        }
    }

    Process {
        id: suspendProcess

        onExited: exitCode => {
            if (exitCode === 0) {
                root.operationSucceeded("suspend");
                return;
            }
            root.lastError = qsTr("systemd-logind 挂起动作失败，退出码 ") + exitCode;
            root.operationFailed("suspend", root.lastError);
        }
    }

    onInhibitedChanged: {
        if (inhibited) {
            root._setDimmed(false);
            root._setDisplaysOff(false);
        }
    }

    Component.onDestruction: {
        root._setDimmed(false);
        if (root.displaysOff)
            Quickshell.execDetached(["niri", "msg", "action", "power-on-monitors"]);
    }
}
