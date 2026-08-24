pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    readonly property int supportedSchemaVersion: 1
    readonly property int historyLimit: 60
    readonly property int maximumReconnectAttempts: 5
    readonly property int maximumDiagnosticLines: 20
    readonly property int maximumDiagnosticCharacters: 2048

    // keytop is an independent CLI.  CLAVIS_KEYTOP is useful for local
    // fixtures; production resolves the executable through PATH.
    property string commandName: {
        const configured = String(Quickshell.env("CLAVIS_KEYTOP") || "").trim()
        return configured !== "" ? configured : "keytop"
    }
    property int configuredIntervalMs: UiPreferences.systemMonitorIntervalMs
    property double sourceIntervalMs: 0
    readonly property int intervalMs: configuredIntervalMs
    property var _consumerModules: ({})
    property var effectiveModules: []
    property var _streamModules: []
    property bool _reconcilePending: false
    property string state: "idle"
    property string errorMessage: ""
    property string errorDetails: ""
    property string actionError: ""
    property bool actionBusy: false

    property var cpu: ({})
    property var memory: ({})
    property var gpus: []
    property var disks: []
    property var network: ({})
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
    property string _autoGpuId: ""
    property string _effectiveGpuId: ""

    property var _terminalCandidates: []
    property int _terminalCandidateIndex: -1
    property int _terminalProbeGeneration: 0
    property int _terminalProbeHandledGeneration: -1
    property var _terminalCandidate: null
    property int _keyTopProbeGeneration: 0
    property int _keyTopProbeHandledGeneration: -1

    readonly property bool active: effectiveModules.length > 0
    readonly property bool hasData: _hasData
    readonly property bool loading: state === "loading"
    readonly property bool ready: state === "ready"
    readonly property bool stale: state === "stale"
    readonly property bool error: state === "error"
    readonly property bool reconnecting: state === "reconnecting"
    readonly property bool partial: errors.length > 0
    readonly property bool processRunning: streamProcess.running
    readonly property string selectedGpuId: _effectiveGpuId
    readonly property var selectedGpu: _gpuById(root.gpus, root.selectedGpuId)
    readonly property string statusText: {
        switch (state) {
        case "loading":
            return qsTr("正在连接");
        case "ready":
            return partial ? qsTr("部分传感器不可读取") : qsTr("实时");
        case "stale":
            return qsTr("数据已过期");
        case "reconnecting":
            return qsTr("正在重新连接");
        case "error":
            return qsTr("服务不可用");
        default:
            return qsTr("已暂停");
        }
    }

    function setConsumerModules(owner, modules) {
        const key = String(owner || "").trim();
        if (key === "")
            return;
        const allowed = ["cpu", "disk", "gpu", "memory", "network"];
        const unique = [];
        (Array.isArray(modules) ? modules : []).forEach(function(module) {
            const name = String(module || "").trim();
            if (allowed.indexOf(name) >= 0 && unique.indexOf(name) < 0)
                unique.push(name);
        });
        unique.sort();
        const next = Object.assign({}, root._consumerModules);
        if (unique.length > 0)
            next[key] = unique;
        else
            delete next[key];
        root._consumerModules = next;
        root._scheduleModuleReconcile();
    }

    function clearConsumer(owner) {
        root.setConsumerModules(owner, []);
    }

    function _scheduleModuleReconcile() {
        if (root._reconcilePending)
            return;
        root._reconcilePending = true;
        Qt.callLater(root._reconcileModules);
    }

    function _reconcileModules() {
        root._reconcilePending = false;
        const union = [];
        Object.keys(root._consumerModules).sort().forEach(function(owner) {
            root._consumerModules[owner].forEach(function(module) {
                if (union.indexOf(module) < 0)
                    union.push(module);
            });
        });
        union.sort();
        if (JSON.stringify(union) === JSON.stringify(root.effectiveModules))
            return;

        const previous = root.effectiveModules.slice();
        const changed = previous.filter(module => union.indexOf(module) < 0)
            .concat(union.filter(module => previous.indexOf(module) < 0));
        changed.forEach(root._clearModuleHistory);
        root.effectiveModules = union;
        root.sourceIntervalMs = 0;
        if (streamProcess.running)
            root._stopStream();
        else if (root.active)
            root._startStream();
        else
            root.state = root.hasData ? "stale" : "idle";
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
            "value",
            "stream",
            "--format",
            "jsonl",
            "--interval",
            String(root.configuredIntervalMs),
            "--modules",
            root._streamModules.join(",")
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
        root._streamModules = root.effectiveModules.slice();
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
                root.errorMessage = qsTr("系统监测服务不可用");
            root.errorDetails = root.errorDetails
                || qsTr("已达到自动重连次数上限，可检查 keytop 后端后重试。");
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
                ? qsTr("无法启动 keytop 系统监测服务")
                : qsTr("系统监测数据流已中断");
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
            root.errorMessage = qsTr("找不到或无法启动 keytop");
            root.errorDetails = qsTr("请安装独立 keytop 后重试。");
        } else if (reason === "data_timeout") {
            root.errorMessage = qsTr("系统监测数据长时间未更新");
            root.errorDetails = qsTr("数据流没有按预期间隔产生新快照。");
        } else if (reason === "first_snapshot_timeout") {
            root.errorMessage = qsTr("系统监测服务未返回首个快照");
            root.errorDetails = qsTr("keytop 已启动，但没有按时输出 JSONL 数据。");
        } else if (reason === "invalid_json") {
            root.errorMessage = qsTr("keytop 持续输出无效的 JSONL");
            root.errorDetails = qsTr("连续多行数据无法通过 JSON v1 校验。");
        } else {
            root.errorMessage = qsTr("系统监测数据流意外退出");
            root.errorDetails = exitCode >= 0
                ? qsTr("keytop 退出码：") + exitCode
                : qsTr("keytop 未报告退出码");
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
            return qsTr("JSON 顶层必须是对象");
        if (snapshot.schemaVersion !== root.supportedSchemaVersion)
            return "schemaVersion";
        if (!root._isFiniteNumber(snapshot.timestampMs)
                || !root._isFiniteNumber(snapshot.sequence)
                || !root._isFiniteNumber(snapshot.intervalMs)
                || snapshot.intervalMs < 0)
            return qsTr("时间戳、序列号或采样间隔无效");
        if (root._streamModules.indexOf("cpu") >= 0 && !root._isObject(snapshot.cpu))
            return qsTr("CPU 模块字段缺失或类型无效");
        if (root._streamModules.indexOf("memory") >= 0 && !root._isObject(snapshot.memory))
            return qsTr("内存模块字段缺失或类型无效");
        if (root._streamModules.indexOf("network") >= 0 && !root._isObject(snapshot.network))
            return qsTr("网络模块字段缺失或类型无效");
        if (root._streamModules.indexOf("gpu") >= 0 && !Array.isArray(snapshot.gpus))
            return qsTr("GPU 模块字段缺失或类型无效");
        if (root._streamModules.indexOf("disk") >= 0 && !Array.isArray(snapshot.disks))
            return qsTr("磁盘模块字段缺失或类型无效");
        if (!Array.isArray(snapshot.errors))
            return qsTr("设备或错误字段必须是数组");
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

    function _gpuId(gpu) {
        if (!root._isObject(gpu))
            return "";
        return String(gpu.id || "").trim();
    }

    function _gpuById(devices, id) {
        const wanted = String(id || "");
        for (let index = 0; index < devices.length; index += 1) {
            if (root._gpuId(devices[index]) === wanted)
                return devices[index];
        }
        return ({});
    }

    function _hasGpuId(devices, id) {
        return root._gpuId(root._gpuById(devices, id)) !== "";
    }

    function _resolveAutoGpuId(devices) {
        if (root._autoGpuId !== "" && root._hasGpuId(devices, root._autoGpuId))
            return root._autoGpuId;

        const ids = [];
        for (let index = 0; index < devices.length; index += 1) {
            const id = root._gpuId(devices[index]);
            if (id !== "")
                ids.push(id);
        }
        ids.sort();
        root._autoGpuId = ids.length > 0 ? ids[0] : "";
        return root._autoGpuId;
    }

    function _resolveSelectedGpuId(devices) {
        const preferred = String(UiPreferences.systemMonitorGpuId || "auto");
        if (preferred !== "auto" && root._hasGpuId(devices, preferred))
            return preferred;
        return root._resolveAutoGpuId(devices);
    }

    function _clearMonitorHistories() {
        root.cpuHistory = [];
        root.memoryHistory = [];
        root.gpuHistory = [];
        root.networkDownloadHistory = [];
        root.networkUploadHistory = [];
    }

    function _clearModuleHistory(module) {
        switch (module) {
        case "cpu":
            root.cpuHistory = [];
            break;
        case "memory":
            root.memoryHistory = [];
            break;
        case "gpu":
            root.gpuHistory = [];
            break;
        case "network":
            root.networkDownloadHistory = [];
            root.networkUploadHistory = [];
            break;
        }
    }

    function _applyConfiguredInterval() {
        root._clearMonitorHistories();
        root.sourceIntervalMs = 0;
        if (root.active && streamProcess.running)
            root._stopStream();
    }

    function _commitSnapshot(snapshot) {
        const snapshotGpus = Array.isArray(snapshot.gpus) ? snapshot.gpus : root.gpus;
        const nextSelectedGpuId = root._resolveSelectedGpuId(snapshotGpus);
        if (nextSelectedGpuId !== root._effectiveGpuId)
            root.gpuHistory = [];
        root._effectiveGpuId = nextSelectedGpuId;
        if (snapshot.cpu)
            root.cpu = snapshot.cpu;
        if (snapshot.memory)
            root.memory = snapshot.memory;
        if (Array.isArray(snapshot.gpus))
            root.gpus = snapshot.gpus.slice();
        if (Array.isArray(snapshot.disks))
            root.disks = snapshot.disks.slice();
        if (snapshot.network)
            root.network = snapshot.network;
        root.errors = snapshot.errors.slice(0, 32);

        root.cpuHistory = root._appendHistory(
            root.cpuHistory,
            snapshot.cpu ? snapshot.cpu.usagePercent : undefined
        );
        root.memoryHistory = root._appendHistory(
            root.memoryHistory,
            snapshot.memory ? snapshot.memory.usagePercent : undefined
        );
        const effectiveGpu = root._gpuById(snapshot.gpus || [], nextSelectedGpuId);
        if (root._gpuId(effectiveGpu) !== "") {
            root.gpuHistory = root._appendHistory(
                root.gpuHistory,
                effectiveGpu.utilizationPercent
            );
        }
        root.networkDownloadHistory = root._appendHistory(
            root.networkDownloadHistory,
            snapshot.network ? snapshot.network.downloadBytesPerSecond : undefined
        );
        root.networkUploadHistory = root._appendHistory(
            root.networkUploadHistory,
            snapshot.network ? snapshot.network.uploadBytesPerSecond : undefined
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
        if (root._terminationPending)
            return;
        const text = String(line || "").trim();
        if (text.length === 0)
            return;
        if (text.indexOf("Unknown command") >= 0
                || text.indexOf("Unknown subcommand") >= 0) {
            root.errorMessage = qsTr("keytop 不支持当前系统监测接口");
            root.errorDetails = text;
            root._terminateStream("invalid_json");
            return;
        }

        let snapshot;
        try {
            snapshot = JSON.parse(text);
        } catch (exception) {
            root.malformedLineCount += 1;
            root._consecutiveMalformedLines += 1;
            root.errorDetails = qsTr("收到损坏的 JSONL 数据行");
            if (!root.hasData)
                root.errorMessage = qsTr("无法解析 keytop 系统监测数据");
            if (root._consecutiveMalformedLines >= 3 && streamProcess.running) {
                root.errorMessage = qsTr("keytop 持续输出无效的 JSONL");
                root._terminateStream("invalid_json");
            }
            return;
        }

        const validationError = root._validateSnapshot(snapshot);
        if (validationError === "schemaVersion") {
            root.schemaMismatchCount += 1;
            root._fatalError = true;
            root.errorMessage = qsTr("系统监测数据 schema 不兼容");
            root.errorDetails = qsTr("需要重新构建 keytop（需要 schema v")
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
                : qsTr("keytop 返回的系统监测数据不完整");
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
            root.errorMessage = qsTr("keytop 不支持当前系统监测接口");
            root.errorDetails = text;
            root._terminateStream("invalid_json");
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
        keyTopProbe.command = [root.commandName, "--help"];
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
                qsTr("keytop 不可用，请安装独立 keytop");
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
            root.actionError = qsTr("未找到可用终端，无法打开 keytop");
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
            return [program, root.commandName];
        case "wezterm":
            return [program, "start", "--", root.commandName];
        case "gnome-terminal":
            return [program, "--", root.commandName];
        case "alacritty":
        case "konsole":
        default:
            return [program, "-e", root.commandName];
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
                root.actionError = qsTr("启动终端失败：") + exception;
            }
            return;
        }

        Qt.callLater(root._probeNextTerminal);
    }

    onConfiguredIntervalMsChanged: root._applyConfiguredInterval()

    Connections {
        target: UiPreferences

        function onSystemMonitorGpuIdChanged() {
            const nextSelectedGpuId = root._resolveSelectedGpuId(root.gpus);
            if (nextSelectedGpuId !== root._effectiveGpuId)
                root.gpuHistory = [];
            root._effectiveGpuId = nextSelectedGpuId;
        }
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
                        qsTr("系统监测服务未返回首个快照");
                    root.errorDetails = qsTr("正在重新启动 keytop 数据流。");
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
                root.errorMessage = qsTr("系统监测数据长时间未更新");
                    root.errorDetails = qsTr("正在重新连接 keytop 数据流。");
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
