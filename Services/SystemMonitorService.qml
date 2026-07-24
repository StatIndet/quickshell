pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int supportedSchemaVersion: 1
    readonly property int historyLimit: 60
    readonly property int maximumReconnectAttempts: 5
    readonly property int maximumDiagnosticLines: 20
    readonly property int maximumDiagnosticCharacters: 2048

    // CLAVIS_KEY is treated as one argv executable, never as shell input.
    // Production uses the installed `key`; local smoke tests can select the
    // just-built backend without changing the service.
    property string commandName: {
        const configured = String(
            Quickshell.env("CLAVIS_KEY") || ""
        ).trim();
        return configured.length > 0
            && configured.indexOf("\n") < 0
            && configured.indexOf("\r") < 0
            ? configured
            : "key";
    }
    property int configuredIntervalMs: 1000
    property double sourceIntervalMs: 0
    readonly property int intervalMs: configuredIntervalMs
    property int consumerCount: 0
    property string state: "idle"
    property string errorMessage: ""
    property string errorDetails: ""
    property string actionError: ""
    property bool actionBusy: false

    property var system: ({})
    property var cpu: ({})
    property var memory: ({})
    property var gpus: []
    property var disks: []
    property var network: ({})
    property var battery: ({})
    property var errors: []

    property var cpuHistory: []
    property var memoryHistory: []
    property var gpuHistory: []
    property var networkDownloadHistory: []
    property var networkUploadHistory: []

    property double sourceTimestampMs: 0
    property double lastUpdatedMs: 0
    property double sequence: -1
    property int reconnectAttempt: 0
    property int malformedLineCount: 0
    property int schemaMismatchCount: 0
    property var diagnostics: []

    property bool _hasData: false
    property bool _fatalError: false
    property bool _stopRequested: false
    property bool _timeoutRestartIssued: false
    property bool _terminationPending: false
    property string _forcedRestartReason: ""
    property double _streamStartedAtMs: 0
    property int _consecutiveMalformedLines: 0
    property int _streamGeneration: 0
    property int _startedGeneration: -1
    property int _handledGeneration: -1
    property int _retryDelayMs: 1000
    property int _forceStopProbeCount: 0

    property var _terminalCandidates: []
    property int _terminalCandidateIndex: -1
    property int _terminalProbeGeneration: 0
    property int _terminalProbeHandledGeneration: -1
    property var _terminalCandidate: null
    property int _keyTopProbeGeneration: 0
    property int _keyTopProbeHandledGeneration: -1

    readonly property bool active: consumerCount > 0
    readonly property bool hasData: _hasData
    readonly property bool loading: state === "loading"
    readonly property bool ready: state === "ready"
    readonly property bool stale: state === "stale"
    readonly property bool error: state === "error"
    readonly property bool reconnecting: state === "reconnecting"
    readonly property bool partial: errors.length > 0
    readonly property bool processRunning: streamProcess.running
    readonly property string statusText: {
        switch (state) {
        case "loading":
            return "正在连接";
        case "ready":
            return partial ? "部分传感器不可读取" : "实时";
        case "stale":
            return "数据已过期";
        case "reconnecting":
            return "正在重新连接";
        case "error":
            return "服务不可用";
        default:
            return "已暂停";
        }
    }

    function acquire() {
        root.consumerCount += 1;
    }

    function release() {
        root.consumerCount = Math.max(0, root.consumerCount - 1);
    }

    function retry() {
        root._fatalError = false;
        root.reconnectAttempt = 0;
        root._retryDelayMs = 1000;
        root.errorMessage = "";
        root.errorDetails = "";
        reconnectTimer.stop();
        if (root.active && !streamProcess.running)
            root._startStream();
    }

    function _streamCommand() {
        return [
            root.commandName,
            "sysmon",
            "stream",
            "--format",
            "jsonl",
            "--interval",
            String(root.configuredIntervalMs),
            "--modules",
            "system,cpu,memory,gpu,disk,network,battery"
        ];
    }

    function _startStream() {
        if (!root.active || streamProcess.running || root._fatalError)
            return;

        reconnectTimer.stop();
        forceStopTimer.stop();
        root._stopRequested = false;
        root._timeoutRestartIssued = false;
        root._terminationPending = false;
        root._forceStopProbeCount = 0;
        root._forcedRestartReason = "";
        root._streamGeneration += 1;
        root._startedGeneration = -1;
        root._handledGeneration = -1;
        root._consecutiveMalformedLines = 0;
        root._streamStartedAtMs = Date.now();
        root.state = root.hasData || root.reconnectAttempt > 0
            ? "reconnecting"
            : "loading";
        streamProcess.command = root._streamCommand();
        streamProcess.running = true;

        const generation = root._streamGeneration;
        Qt.callLater(function() {
            if (generation === root._streamGeneration
                    && !streamProcess.running
                    && root._startedGeneration !== generation) {
                root._handleStreamStopped(generation, "failed_to_start", -1);
            }
        });
    }

    function _stopStream() {
        reconnectTimer.stop();
        root._stopRequested = true;
        if (streamProcess.running)
            root._terminateStream("");
        else {
            forceStopTimer.stop();
            root._terminationPending = false;
            root.state = root._fatalError
                ? "error"
                : (root.hasData ? "stale" : "idle");
        }
    }

    function _terminateStream(reason) {
        if (reason && root._forcedRestartReason === "")
            root._forcedRestartReason = reason;
        if (!streamProcess.running)
            return;
        if (root._terminationPending)
            return;
        root._terminationPending = true;
        root._forceStopProbeCount = 0;
        forceStopTimer.interval = 2000;
        streamProcess.running = false;
        forceStopTimer.start();
    }

    function _scheduleReconnect(reason) {
        if (!root.active || root._fatalError)
            return;

        if (root.reconnectAttempt >= root.maximumReconnectAttempts) {
            root.state = "error";
            if (!root.errorMessage)
                root.errorMessage = "系统监测服务不可用";
            root.errorDetails = root.errorDetails
                || "已达到自动重连次数上限，可检查 key 后端后重试。";
            return;
        }

        root.reconnectAttempt += 1;
        root._retryDelayMs = Math.min(
            16000,
            1000 * Math.pow(2, root.reconnectAttempt - 1)
        );
        root.state = "reconnecting";
        if (!root.errorMessage) {
            root.errorMessage = reason === "failed_to_start"
                ? "无法启动 key 系统监测服务"
                : "系统监测数据流已中断";
        }
        reconnectTimer.interval = root._retryDelayMs;
        reconnectTimer.restart();
    }

    function _handleStreamStopped(generation, reason, exitCode) {
        if (generation !== root._streamGeneration
                || root._handledGeneration === generation)
            return;

        root._handledGeneration = generation;
        forceStopTimer.stop();
        root._terminationPending = false;
        root._forceStopProbeCount = 0;
        const requestedStop = root._stopRequested;
        const intentionallyStopped = requestedStop || !root.active;
        root._stopRequested = false;

        if (intentionallyStopped) {
            root.state = root._fatalError
                ? "error"
                : (root.hasData ? "stale" : "idle");
            if (root.active && requestedStop)
                Qt.callLater(root._startStream);
            return;
        }

        if (root._fatalError) {
            root.state = "error";
            return;
        }

        if (reason === "failed_to_start") {
            root.errorMessage = "找不到或无法启动 key";
            root.errorDetails = "请重新构建并安装 key 后端，然后重试。";
        } else if (reason === "data_timeout") {
            root.errorMessage = "系统监测数据长时间未更新";
            root.errorDetails = "数据流没有按预期间隔产生新快照。";
        } else if (reason === "first_snapshot_timeout") {
            root.errorMessage = "系统监测服务未返回首个快照";
            root.errorDetails = "key 已启动，但没有按时输出 JSONL 数据。";
        } else if (reason === "invalid_json") {
            root.errorMessage = "key 持续输出无效的 JSONL";
            root.errorDetails = "连续多行数据无法通过 JSON v1 校验。";
        } else {
            root.errorMessage = "系统监测数据流意外退出";
            root.errorDetails = exitCode >= 0
                ? "key 退出码：" + exitCode
                : "key 未报告退出码";
        }

        root._scheduleReconnect(reason);
    }

    function _isObject(value) {
        return value !== null
            && typeof value === "object"
            && !Array.isArray(value);
    }

    function _isFiniteNumber(value) {
        return typeof value === "number" && isFinite(value);
    }

    function _validateSnapshot(snapshot) {
        if (!root._isObject(snapshot))
            return "JSON 顶层必须是对象";
        if (snapshot.schemaVersion !== root.supportedSchemaVersion)
            return "schemaVersion";
        if (!root._isFiniteNumber(snapshot.timestampMs)
                || !root._isFiniteNumber(snapshot.sequence)
                || !root._isFiniteNumber(snapshot.intervalMs)
                || snapshot.intervalMs < 0)
            return "时间戳、序列号或采样间隔无效";
        if (!root._isObject(snapshot.system)
                || !root._isObject(snapshot.cpu)
                || !root._isObject(snapshot.memory)
                || !root._isObject(snapshot.network)
                || !root._isObject(snapshot.battery))
            return "系统模块字段缺失或类型无效";
        if (!Array.isArray(snapshot.gpus)
                || !Array.isArray(snapshot.disks)
                || !Array.isArray(snapshot.errors))
            return "设备或错误字段必须是数组";
        return "";
    }

    function _appendHistory(values, value) {
        if (!root._isFiniteNumber(value))
            return values;
        const next = values.slice(
            Math.max(0, values.length - root.historyLimit + 1)
        );
        next.push(value);
        return next;
    }

    function _commitSnapshot(snapshot) {
        root.system = snapshot.system;
        root.cpu = snapshot.cpu;
        root.memory = snapshot.memory;
        root.gpus = snapshot.gpus.slice();
        root.disks = snapshot.disks.slice();
        root.network = snapshot.network;
        root.battery = snapshot.battery;
        root.errors = snapshot.errors.slice(0, 32);

        root.cpuHistory = root._appendHistory(
            root.cpuHistory,
            snapshot.cpu.usagePercent
        );
        root.memoryHistory = root._appendHistory(
            root.memoryHistory,
            snapshot.memory.usagePercent
        );
        if (snapshot.gpus.length > 0) {
            root.gpuHistory = root._appendHistory(
                root.gpuHistory,
                snapshot.gpus[0].utilizationPercent
            );
        }
        root.networkDownloadHistory = root._appendHistory(
            root.networkDownloadHistory,
            snapshot.network.downloadBytesPerSecond
        );
        root.networkUploadHistory = root._appendHistory(
            root.networkUploadHistory,
            snapshot.network.uploadBytesPerSecond
        );

        root.sourceTimestampMs = snapshot.timestampMs;
        root.lastUpdatedMs = Date.now();
        root.sequence = snapshot.sequence;
        root.sourceIntervalMs = snapshot.intervalMs;
        root._hasData = true;
        root._timeoutRestartIssued = false;
        root._consecutiveMalformedLines = 0;
        root.reconnectAttempt = 0;
        root._retryDelayMs = 1000;
        root.errorMessage = "";
        root.errorDetails = "";
        root.state = "ready";
    }

    function _consumeLine(line) {
        const text = String(line || "").trim();
        if (text.length === 0)
            return;
        if (text.indexOf("Unknown command") >= 0
                || text.indexOf("Unknown subcommand") >= 0) {
            root._markBackendOutdated();
            return;
        }

        let snapshot;
        try {
            snapshot = JSON.parse(text);
        } catch (exception) {
            root.malformedLineCount += 1;
            root._consecutiveMalformedLines += 1;
            root.errorDetails = "收到损坏的 JSONL 数据行";
            if (!root.hasData)
                root.errorMessage = "无法解析 key 系统监测数据";
            if (root._consecutiveMalformedLines >= 3 && streamProcess.running) {
                root.errorMessage = "key 持续输出无效的 JSONL";
                root._terminateStream("invalid_json");
            }
            return;
        }

        const validationError = root._validateSnapshot(snapshot);
        if (validationError === "schemaVersion") {
            root.schemaMismatchCount += 1;
            root._fatalError = true;
            root.errorMessage = "系统监测协议版本不兼容";
            root.errorDetails = "需要重新构建 key 后端（需要 schema v"
                + root.supportedSchemaVersion + "）。";
            root.state = "error";
            root._terminateStream("schema_mismatch");
            return;
        }
        if (validationError !== "") {
            root.malformedLineCount += 1;
            root._consecutiveMalformedLines += 1;
            root.errorMessage = root.hasData
                ? root.errorMessage
                : "key 返回的系统监测数据不完整";
            root.errorDetails = validationError;
            if (root._consecutiveMalformedLines >= 3
                    && streamProcess.running) {
                root._terminateStream("invalid_json");
            }
            return;
        }

        root._commitSnapshot(snapshot);
    }

    function _consumeDiagnostic(line) {
        const text = String(line || "").trim();
        if (text.length === 0)
            return;
        if (text.indexOf("Unknown command") >= 0
                || text.indexOf("Unknown subcommand") >= 0) {
            root._markBackendOutdated();
            return;
        }

        const next = root.diagnostics.slice(
            Math.max(0, root.diagnostics.length
                - root.maximumDiagnosticLines + 1)
        );
        next.push(text.slice(0, 256));
        root.diagnostics = next;
        root.errorDetails = next.join("\n").slice(
            -root.maximumDiagnosticCharacters
        );
    }

    function _markBackendOutdated() {
        root._fatalError = true;
        root.errorMessage = "key 版本过旧";
        root.errorDetails =
            "当前 key 不支持 sysmon，请重新构建并安装 key 后端。";
        root.state = "error";
        root._terminateStream("outdated_backend");
    }

    function _safeTerminalEnvironmentValue() {
        const value = String(Quickshell.env("TERMINAL") || "").trim();
        if (value.length === 0 || /\s/.test(value))
            return "";
        return value;
    }

    function _buildTerminalCandidates() {
        const candidates = [];
        const seen = ({});
        const configured = root._safeTerminalEnvironmentValue();
        const programs = [
            configured,
            "kitty",
            "foot",
            "alacritty",
            "wezterm",
            "konsole",
            "gnome-terminal"
        ];
        for (let index = 0; index < programs.length; index += 1) {
            const program = programs[index];
            if (!program || seen[program])
                continue;
            seen[program] = true;
            candidates.push({ "program": program });
        }
        return candidates;
    }

    function openFullMonitor() {
        if (root.actionBusy)
            return;
        root.actionError = "";
        root.actionBusy = true;
        root._keyTopProbeGeneration += 1;
        root._keyTopProbeHandledGeneration = -1;
        const generation = root._keyTopProbeGeneration;
        keyTopProbe.command = [root.commandName, "top", "--help"];
        keyTopProbe.running = true;

        Qt.callLater(function() {
            if (generation === root._keyTopProbeGeneration
                    && !keyTopProbe.running) {
                root._handleKeyTopProbe(generation, 127);
            }
        });
    }

    function _handleKeyTopProbe(generation, exitCode) {
        if (generation !== root._keyTopProbeGeneration
                || root._keyTopProbeHandledGeneration === generation)
            return;
        root._keyTopProbeHandledGeneration = generation;

        if (exitCode !== 0) {
            root.actionBusy = false;
            root.actionError =
                "key top 不可用，请重新构建并安装 key 后端";
            return;
        }

        root._terminalCandidates = root._buildTerminalCandidates();
        root._terminalCandidateIndex = -1;
        root._probeNextTerminal();
    }

    function _probeNextTerminal() {
        root._terminalCandidateIndex += 1;
        if (root._terminalCandidateIndex >= root._terminalCandidates.length) {
            root.actionBusy = false;
            root.actionError = "未找到可用终端，无法打开 key top";
            return;
        }

        root._terminalCandidate =
            root._terminalCandidates[root._terminalCandidateIndex];
        const program = root._terminalCandidate.program;
        root._terminalProbeGeneration += 1;
        root._terminalProbeHandledGeneration = -1;
        const generation = root._terminalProbeGeneration;
        terminalProbe.command = program.indexOf("/") >= 0
            ? ["test", "-x", program]
            : ["which", program];
        terminalProbe.running = true;

        Qt.callLater(function() {
            if (generation === root._terminalProbeGeneration
                    && !terminalProbe.running) {
                root._handleTerminalProbe(generation, 127);
            }
        });
    }

    function _terminalCommand(program) {
        const parts = program.split("/");
        const executable = parts[parts.length - 1];
        switch (executable) {
        case "kitty":
        case "foot":
            return [program, root.commandName, "top"];
        case "wezterm":
            return [program, "start", "--", root.commandName, "top"];
        case "gnome-terminal":
            return [program, "--", root.commandName, "top"];
        case "alacritty":
        case "konsole":
        default:
            return [program, "-e", root.commandName, "top"];
        }
    }

    function _handleTerminalProbe(generation, exitCode) {
        if (generation !== root._terminalProbeGeneration
                || root._terminalProbeHandledGeneration === generation)
            return;
        root._terminalProbeHandledGeneration = generation;

        if (exitCode === 0 && root._terminalCandidate) {
            try {
                Quickshell.execDetached(
                    root._terminalCommand(root._terminalCandidate.program)
                );
                root.actionBusy = false;
                root.actionError = "";
            } catch (exception) {
                root.actionBusy = false;
                root.actionError = "启动终端失败：" + exception;
            }
            return;
        }

        Qt.callLater(root._probeNextTerminal);
    }

    onActiveChanged: {
        if (active)
            root._startStream();
        else
            root._stopStream();
    }

    Timer {
        id: reconnectTimer

        repeat: false
        onTriggered: root._startStream()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active

        onTriggered: {
            if (!streamProcess.running)
                return;

            const now = Date.now();
            if (!root.hasData) {
                const firstSnapshotAfter = Math.max(
                    6000,
                    root.configuredIntervalMs * 6
                );
                if (now - root._streamStartedAtMs > firstSnapshotAfter
                        && !root._terminationPending) {
                    root.errorMessage =
                        "系统监测服务未返回首个快照";
                    root.errorDetails = "正在重新启动 key 数据流。";
                    root._terminateStream("first_snapshot_timeout");
                }
                return;
            }

            const age = now - root.lastUpdatedMs;
            const staleAfter = Math.max(
                4000,
                root.configuredIntervalMs * 3.5
            );
            const restartAfter = Math.max(
                10000,
                root.configuredIntervalMs * 8
            );
            if (age > staleAfter && root.state === "ready")
                root.state = "stale";
            if (age > restartAfter && streamProcess.running
                    && !root._timeoutRestartIssued) {
                root._timeoutRestartIssued = true;
                root.errorMessage = "系统监测数据长时间未更新";
                root.errorDetails = "正在重新连接 key 数据流。";
                root._terminateStream("data_timeout");
            }
        }
    }

    Timer {
        id: forceStopTimer

        interval: 2000
        repeat: false
        onTriggered: {
            const processId = Number(streamProcess.processId);
            if (streamProcess.running
                    && root._startedGeneration === root._streamGeneration
                    && isFinite(processId)
                    && processId > 0) {
                streamProcess.signal(9);
                return;
            }
            if (streamProcess.running
                    && root._terminationPending
                    && root._forceStopProbeCount < 8) {
                root._forceStopProbeCount += 1;
                forceStopTimer.interval = 250;
                forceStopTimer.restart();
            }
        }
    }

    Process {
        id: streamProcess

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root._consumeLine(line)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => root._consumeDiagnostic(line)
        }

        onStarted: {
            root._startedGeneration = root._streamGeneration;
            root._streamStartedAtMs = Date.now();
            if (root._terminationPending || !root.active) {
                root._terminationPending = true;
                root._forceStopProbeCount = 0;
                streamProcess.running = false;
                forceStopTimer.interval = 2000;
                forceStopTimer.restart();
            }
        }
        onExited: (exitCode, exitStatus) => {
            const reason = root._timeoutRestartIssued
                ? "data_timeout"
                : (root._forcedRestartReason || "unexpected_exit");
            root._handleStreamStopped(
                root._streamGeneration,
                reason,
                exitCode
            );
        }
        onRunningChanged: {
            if (running)
                return;
            const generation = root._streamGeneration;
            Qt.callLater(function() {
                if (generation !== root._streamGeneration
                        || streamProcess.running)
                    return;
                const reason = root._startedGeneration === generation
                    ? (root._timeoutRestartIssued
                        ? "data_timeout"
                        : (root._forcedRestartReason
                            || "unexpected_exit"))
                    : "failed_to_start";
                root._handleStreamStopped(generation, reason, -1);
            });
        }
    }

    Process {
        id: keyTopProbe

        onExited: (exitCode, exitStatus) => {
            root._handleKeyTopProbe(
                root._keyTopProbeGeneration,
                exitCode
            );
        }
        onRunningChanged: {
            if (running)
                return;
            const generation = root._keyTopProbeGeneration;
            Qt.callLater(function() {
                if (generation === root._keyTopProbeGeneration
                        && !keyTopProbe.running) {
                    root._handleKeyTopProbe(generation, 127);
                }
            });
        }
    }

    Process {
        id: terminalProbe

        onExited: (exitCode, exitStatus) => {
            root._handleTerminalProbe(
                root._terminalProbeGeneration,
                exitCode
            );
        }
        onRunningChanged: {
            if (running)
                return;
            const generation = root._terminalProbeGeneration;
            Qt.callLater(function() {
                if (generation === root._terminalProbeGeneration
                        && !terminalProbe.running) {
                    root._handleTerminalProbe(generation, 127);
                }
            });
        }
    }
}
