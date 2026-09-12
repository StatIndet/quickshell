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
        const configured = String(Quickshell.env("CLAVIS_KEYTOP") || "").trim();
        return configured !== "" ? configured : "keytop";
    }
    property int configuredIntervalMs: UiPreferences.systemMonitorIntervalMs
    property double sourceIntervalMs: 0
    readonly property int intervalMs: configuredIntervalMs
    property var _consumerModules: ({})
    property var effectiveModules: []
    property var _streamModules: []
    property bool _reconcilePending: false
    property var _streamProcess: firstStream
    property var _replacementProcess: null
    property int _replacementSnapshots: 0
    property double _replacementTimestampMs: -1
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
    property var diskReadHistories: ({})
    property var diskWriteHistories: ({})

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
    property int _generationCounter: 0
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
    readonly property bool processRunning: root._streamProcess.running
    readonly property string selectedGpuId: _effectiveGpuId
    readonly property var selectedGpu: _gpuById(root.gpus, root.selectedGpuId)
    readonly property string statusText: {
        switch (state) {
        case "loading":
            return qsTr("Connecting");
        case "ready":
            return partial ? qsTr("Some sensors cannot be read") : qsTr("Live");
        case "stale":
            return qsTr("Data is stale");
        case "reconnecting":
            return qsTr("Reconnecting");
        case "error":
            return qsTr("Service unavailable");
        default:
            return qsTr("Paused");
        }
    }

    function setConsumerModules(owner, modules) {
        const key = String(owner || "").trim();
        if (key === "")
            return;
        const allowed = ["cpu", "disk", "gpu", "memory", "network"];
        const unique = [];
        (Array.isArray(modules) ? modules : []).forEach(function (module) {
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
        Object.keys(root._consumerModules).sort().forEach(function (owner) {
            root._consumerModules[owner].forEach(function (module) {
                if (union.indexOf(module) < 0)
                    union.push(module);
            });
        });
        union.sort();
        if (JSON.stringify(union) === JSON.stringify(root.effectiveModules))
            return;

        const previous = root.effectiveModules.slice();
        const changed = previous.filter(module => union.indexOf(module) < 0).concat(union.filter(module
                                                                                                 => previous.indexOf(
                                                                                                        module) < 0));
        changed.forEach(root._clearModuleHistory);
        root.effectiveModules = union;
        if (!root.active)
            root._stopStream();
        else if (root._streamProcess.running)
            root._prepareReplacement();
        else
            root._startStream();
    }

    // Module changes must not reset the counter baselines of visible cards.
    // Keep the current stream alive until the replacement has a full interval
    // of samples, then retire it. Only one process remains in steady state.
    function _cancelReplacement() {
        const pending = root._replacementProcess;
        root._replacementProcess = null;
        if (pending)
            pending.terminate();
    }

    function _prepareReplacement() {
        if (!root.active || !root._streamProcess.running || root._terminationPending || root._fatalError)
            return;
        const wanted = JSON.stringify(root.effectiveModules);
        if (wanted === JSON.stringify(root._streamModules)) {
            root._cancelReplacement();
            return;
        }
        if (root._replacementProcess && wanted === JSON.stringify(root._replacementProcess.modules))
            return;
        root._cancelReplacement();
        const next = root._streamProcess === firstStream ? secondStream : firstStream;
        // A retired process may still be exiting after a rapid toggle.
        if (next.running)
            return;
        next.generation = ++root._generationCounter;
        next.modules = root.effectiveModules.slice();
        next.startedAtMs = Date.now();
        next.didStart = false;
        next.malformedLines = 0;
        next.command = root._streamCommand(next.modules);
        root._replacementSnapshots = 0;
        root._replacementTimestampMs = -1;
        root._replacementProcess = next;
        next.running = true;
        Qt.callLater(function () {
            if (root._replacementProcess === next && !next.running && !next.didStart)
                root._terminateStream("failed_to_start");
        });
    }

    function _adoptReplacement() {
        const previous = root._streamProcess;
        const next = root._replacementProcess;
        root._replacementProcess = null;
        root._streamProcess = next;
        root._streamModules = next.modules.slice();
        root._streamGeneration = next.generation;
        root._startedGeneration = root._streamGeneration;
        root._handledGeneration = -1;
        root._streamStartedAtMs = next.startedAtMs;
        previous.terminate();
    }

    function retry() {
        root._fatalError = false;
        root.reconnectAttempt = 0;
        root._retryDelayMs = 1000;
        root.errorMessage = "";
        root.errorDetails = "";
        reconnectTimer.stop();
        if (root.active && !root._streamProcess.running)
            root._startStream();
    }

    function _streamCommand(modules) {
        return [root.commandName, "value", "stream", "--format", "jsonl", "--interval", String(
                    root.configuredIntervalMs), "--modules", modules.join(",")];
    }

    function _startStream() {
        if (!root.active || root._streamProcess.running || root._fatalError)
            return;
        reconnectTimer.stop();
        forceStopTimer.stop();
        root._stopRequested = false;
        root._timeoutRestartIssued = false;
        root._terminationPending = false;
        root._forceStopProbeCount = 0;
        root._forcedRestartReason = "";
        root._streamGeneration = ++root._generationCounter;
        root._startedGeneration = -1;
        root._handledGeneration = -1;
        root._streamProcess.malformedLines = 0;
        root._streamStartedAtMs = Date.now();
        root._streamModules = root.effectiveModules.slice();
        root.state = root.hasData || root.reconnectAttempt > 0 ? "reconnecting" : "loading";
        root._streamProcess.modules = root._streamModules.slice();
        root._streamProcess.generation = root._streamGeneration;
        root._streamProcess.didStart = false;
        root._streamProcess.startedAtMs = root._streamStartedAtMs;
        root._streamProcess.command = root._streamCommand(root._streamModules);
        root._streamProcess.running = true;

        const generation = root._streamGeneration;
        Qt.callLater(function () {
            if (generation === root._streamGeneration && !root._streamProcess.running
                    && root._startedGeneration !== generation) {
                root._handleStreamStopped(generation, "failed_to_start", -1);
            }
        });
    }

    function _stopStream() {
        root._cancelReplacement();
        reconnectTimer.stop();
        root._stopRequested = true;
        if (root._streamProcess.running)
            root._terminateStream("");
        else {
            forceStopTimer.stop();
            root._terminationPending = false;
            root.state = root._fatalError ? "error" : (root.hasData ? "stale" : "idle");
        }
    }

    function _terminateStream(reason) {
        root._cancelReplacement();
        if (reason && root._forcedRestartReason === "")
            root._forcedRestartReason = reason;
        if (!root._streamProcess.running)
            return;
        if (root._terminationPending)
            return;
        root._terminationPending = true;
        root._forceStopProbeCount = 0;
        forceStopTimer.interval = 2000;
        root._streamProcess.running = false;
        forceStopTimer.start();
    }

    function _scheduleReconnect(reason) {
        if (!root.active || root._fatalError)
            return;

        if (root.reconnectAttempt >= root.maximumReconnectAttempts) {
            root.state = "error";
            if (!root.errorMessage)
                root.errorMessage = qsTr("System monitor service unavailable");
            root.errorDetails = root.errorDetails || qsTr(
                        "The automatic reconnect limit was reached. Check the keytop backend and try again.");
            return;
        }

        root.reconnectAttempt += 1;
        root._retryDelayMs = Math.min(16000, 1000 * Math.pow(2, root.reconnectAttempt - 1));
        root.state = "reconnecting";
        if (!root.errorMessage) {
            root.errorMessage = reason === "failed_to_start" ? qsTr(
                                                                   "Could not start the keytop system monitoring service") :
                                                               qsTr("The system monitor data stream was interrupted");
        }
        reconnectTimer.interval = root._retryDelayMs;
        reconnectTimer.restart();
    }

    function _handleStreamStopped(generation, reason, exitCode) {
        if (generation !== root._streamGeneration || root._handledGeneration === generation)
            return;

        root._handledGeneration = generation;
        forceStopTimer.stop();
        root._terminationPending = false;
        root._forceStopProbeCount = 0;
        const requestedStop = root._stopRequested;
        const intentionallyStopped = requestedStop || !root.active;
        root._stopRequested = false;

        if (intentionallyStopped) {
            root.state = root._fatalError ? "error" : (root.hasData ? "stale" : "idle");
            if (root.active && requestedStop)
                Qt.callLater(root._startStream);
            return;
        }

        if (root._fatalError) {
            root.state = "error";
            return;
        }

        if (reason === "failed_to_start") {
            root.errorMessage = qsTr("keytop was not found or could not be started");
            root.errorDetails = qsTr("Install the standalone keytop package and try again.");
        } else if (reason === "data_timeout") {
            root.errorMessage = qsTr("System monitor data has not updated for a long time");
            root.errorDetails = qsTr(
                        "The data stream is not producing new snapshots at the expected interval.");
        } else if (reason === "first_snapshot_timeout") {
            root.errorMessage = qsTr("The system monitor service did not return its first snapshot");
            root.errorDetails = qsTr("keytop started but did not produce JSONL data in time.");
        } else if (reason === "invalid_json") {
            root.errorMessage = qsTr("keytop keeps producing invalid JSONL");
            root.errorDetails = qsTr("Several consecutive lines failed JSON v1 validation.");
        } else {
            root.errorMessage = qsTr("The system monitor data stream exited unexpectedly");
            root.errorDetails = exitCode >= 0 ? qsTr("keytop exit code: ") + exitCode : qsTr(
                                                    "keytop did not report an exit code");

        }

        root._scheduleReconnect(reason);
    }

    function _isObject(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value);
    }

    function _isFiniteNumber(value) {
        return typeof value === "number" && isFinite(value);
    }

    function _validateSnapshot(snapshot, modules) {
        if (!root._isObject(snapshot))
            return qsTr("The top-level JSON value must be an object");
        if (snapshot.schemaVersion !== root.supportedSchemaVersion)
            return "schemaVersion";
        if (!root._isFiniteNumber(snapshot.timestampMs) || !root._isFiniteNumber(snapshot.sequence) || !root._isFiniteNumber(
                    snapshot.intervalMs) || snapshot.intervalMs < 0)
            return qsTr("The timestamp, sequence number, or sampling interval is invalid");
        if (modules.indexOf("cpu") >= 0 && !root._isObject(snapshot.cpu))
            return qsTr("Missing or invalid CPU data fields");
        if (modules.indexOf("memory") >= 0 && !root._isObject(snapshot.memory))
            return qsTr("Missing or invalid memory data fields");
        if (modules.indexOf("network") >= 0 && !root._isObject(snapshot.network))
            return qsTr("Missing or invalid network data fields");
        if (modules.indexOf("gpu") >= 0 && !Array.isArray(snapshot.gpus))
            return qsTr("Missing or invalid GPU data fields");
        if (modules.indexOf("disk") >= 0 && !Array.isArray(snapshot.disks))
            return qsTr("Missing or invalid disk data fields");
        if (!Array.isArray(snapshot.errors))
            return qsTr("The devices and errors fields must be arrays");
        return "";
    }

    function _appendHistory(values, value) {
        if (!root._isFiniteNumber(value))
            return values;
        const next = values.slice(Math.max(0, values.length - root.historyLimit + 1));
        next.push(value);
        return next;
    }

    function _updateDiskHistories(devices) {
        const nextReads = ({});
        const nextWrites = ({});
        for (let index = 0; index < devices.length; index += 1) {
            const disk = devices[index];
            const id = String(disk.device || "");
            if (id === "")
                continue;
            nextReads[id] = root._appendHistory(root.diskReadHistories[id] || [], disk.readBytesPerSecond);
            nextWrites[id] = root._appendHistory(root.diskWriteHistories[id] || [], disk.writeBytesPerSecond);
        }
        root.diskReadHistories = nextReads;
        root.diskWriteHistories = nextWrites;
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
        root.diskReadHistories = ({});
        root.diskWriteHistories = ({});
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
        case "disk":
            root.diskReadHistories = ({});
            root.diskWriteHistories = ({});
            break;
        }
    }

    function _applyConfiguredInterval() {
        root._clearMonitorHistories();
        root.sourceIntervalMs = 0;
        if (root.active && root._streamProcess.running)
            root._stopStream();
    }

    function _commitSnapshot(snapshot) {
        const requested = root.effectiveModules;
        snapshot = Object.assign({}, snapshot);
        const fields = {
            cpu: "cpu",
            memory: "memory",
            gpu: "gpus",
            disk: "disks",
            network: "network"
        };
        Object.keys(fields).forEach(function (module) {
            if (requested.indexOf(module) < 0)
                delete snapshot[fields[module]];
        });
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
        if (Array.isArray(snapshot.disks)) {
            root.disks = snapshot.disks.slice();
            root._updateDiskHistories(root.disks);
        }
        if (snapshot.network)
            root.network = snapshot.network;
        root.errors = snapshot.errors.filter(function (error) {
            return !error || !fields[error.module] || requested.indexOf(error.module) >= 0;
        }).slice(0, 32);

        const cpuUsage = snapshot.cpu ? snapshot.cpu.usagePercent : undefined;
        root.cpuHistory = root._appendHistory(root.cpuHistory, cpuUsage);

        root.memoryHistory = root._appendHistory(root.memoryHistory, snapshot.memory
                                                 ? snapshot.memory.usagePercent : undefined);
        const effectiveGpu = root._gpuById(snapshot.gpus || [], nextSelectedGpuId);
        if (root._gpuId(effectiveGpu) !== "") {
            root.gpuHistory = root._appendHistory(root.gpuHistory, effectiveGpu.utilizationPercent);
        }
        root.networkDownloadHistory = root._appendHistory(root.networkDownloadHistory, snapshot.network
                                                          ? snapshot.network.downloadBytesPerSecond :
                                                            undefined);
        root.networkUploadHistory = root._appendHistory(root.networkUploadHistory, snapshot.network
                                                        ? snapshot.network.uploadBytesPerSecond : undefined);

        root.sourceTimestampMs = snapshot.timestampMs;
        root.lastUpdatedMs = Date.now();
        root.sequence = snapshot.sequence;
        root.sourceIntervalMs = snapshot.intervalMs;
        root._hasData = true;
        root._timeoutRestartIssued = false;
        root.reconnectAttempt = 0;
        root._retryDelayMs = 1000;
        root.errorMessage = "";
        root.errorDetails = "";
        root.state = "ready";
    }

    function _consumeLine(line, process) {
        if (root._terminationPending || (process !== root._streamProcess && process
                                         !== root._replacementProcess))
            return;
        const text = String(line || "").trim();
        if (text.length === 0)
            return;
        if (text.indexOf("Unknown command") >= 0 || text.indexOf("Unknown subcommand") >= 0) {
            root.errorMessage = qsTr("keytop does not support the current system monitoring interface");
            root.errorDetails = text;
            root._terminateStream("invalid_json");
            return;
        }

        let snapshot;
        try {
            snapshot = JSON.parse(text);
        } catch (exception) {
            root.malformedLineCount += 1;
            process.malformedLines += 1;
            root.errorDetails = qsTr("Received a corrupt JSONL line");
            if (!root.hasData)
                root.errorMessage = qsTr("Could not parse keytop system monitor data");
            if (process.malformedLines >= 3 && root._streamProcess.running) {
                root.errorMessage = qsTr("keytop keeps producing invalid JSONL");
                root._terminateStream("invalid_json");
            }
            return;
        }

        const validationError = root._validateSnapshot(snapshot, process.modules);
        if (validationError === "schemaVersion") {
            root.schemaMismatchCount += 1;
            root._fatalError = true;
            root.errorMessage = qsTr("System monitoring data schema is incompatible");
            root.errorDetails = qsTr("Rebuild keytop (schema v") + root.supportedSchemaVersion + "）。";
            root.state = "error";
            root._terminateStream("schema_mismatch");
            return;
        }
        if (validationError !== "") {
            root.malformedLineCount += 1;
            process.malformedLines += 1;
            root.errorMessage = root.hasData ? root.errorMessage : qsTr(
                                                   "System monitor data returned by keytop is incomplete");
            root.errorDetails = validationError;
            if (process.malformedLines >= 3 && root._streamProcess.running) {
                root._terminateStream("invalid_json");
            }
            return;
        }

        process.malformedLines = 0;
        if (process === root._replacementProcess) {
            if (snapshot.timestampMs <= root._replacementTimestampMs)
                return;
            root._replacementTimestampMs = snapshot.timestampMs;
            root._replacementSnapshots += 1;
            // The first sample establishes CPU/disk/network delta baselines.
            // Never replace live values with that warm-up snapshot.
            if (root._replacementSnapshots < 2 || snapshot.timestampMs <= root.sourceTimestampMs)
                return;
            root._adoptReplacement();
        }
        root._commitSnapshot(snapshot);
    }

    function _consumeDiagnostic(line, process) {
        if (process !== root._streamProcess && process !== root._replacementProcess)
            return;
        const text = String(line || "").trim();
        if (text.length === 0)
            return;
        if (text.indexOf("Unknown command") >= 0 || text.indexOf("Unknown subcommand") >= 0) {
            root.errorMessage = qsTr("keytop does not support the current system monitoring interface");
            root.errorDetails = text;
            root._terminateStream("invalid_json");
            return;
        }

        const next = root.diagnostics.slice(Math.max(0, root.diagnostics.length - root.maximumDiagnosticLines
                                                     + 1));
        next.push(text.slice(0, 256));
        root.diagnostics = next;
        root.errorDetails = next.join("\n").slice(-root.maximumDiagnosticCharacters);
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
        const programs = [configured, "kitty", "foot", "alacritty", "wezterm", "konsole", "gnome-terminal"];
        for (let index = 0; index < programs.length; index += 1) {
            const program = programs[index];
            if (!program || seen[program])
                continue;
            seen[program] = true;
            candidates.push({
                                "program": program
                            });
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

        Qt.callLater(function () {
            if (generation === root._keyTopProbeGeneration && !keyTopProbe.running) {
                root._handleKeyTopProbe(generation, 127);
            }
        });
    }

    function _handleKeyTopProbe(generation, exitCode) {
        if (generation !== root._keyTopProbeGeneration || root._keyTopProbeHandledGeneration === generation)
            return;
        root._keyTopProbeHandledGeneration = generation;

        if (exitCode !== 0) {
            root.actionBusy = false;
            root.actionError = qsTr("keytop is unavailable; install the independent keytop command");
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
            root.actionError = qsTr("No usable terminal was found, so keytop could not be opened");
            return;
        }

        root._terminalCandidate = root._terminalCandidates[root._terminalCandidateIndex];
        const program = root._terminalCandidate.program;
        root._terminalProbeGeneration += 1;
        root._terminalProbeHandledGeneration = -1;
        const generation = root._terminalProbeGeneration;
        terminalProbe.command = program.indexOf("/") >= 0 ? ["test", "-x", program] : ["which", program];
        terminalProbe.running = true;

        Qt.callLater(function () {
            if (generation === root._terminalProbeGeneration && !terminalProbe.running) {
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
        if (generation !== root._terminalProbeGeneration || root._terminalProbeHandledGeneration
                === generation)
            return;
        root._terminalProbeHandledGeneration = generation;

        if (exitCode === 0 && root._terminalCandidate) {
            try {
                ApplicationService.launchCommand(root._terminalCommand(root._terminalCandidate.program));
                root.actionBusy = false;
                root.actionError = "";
            } catch (exception) {
                root.actionBusy = false;
                root.actionError = qsTr("Could not start terminal:") + exception;
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
            if (!root._streamProcess.running)
                return;

            const now = Date.now();
            if (!root.hasData) {
                const firstSnapshotAfter = Math.max(6000, root.configuredIntervalMs * 6);
                if (now - root._streamStartedAtMs > firstSnapshotAfter && !root._terminationPending) {
                    root.errorMessage = qsTr("The system monitor service did not return its first snapshot");
                    root.errorDetails = qsTr("Restarting the keytop data stream.");
                    root._terminateStream("first_snapshot_timeout");
                }
                return;
            }

            const age = now - root.lastUpdatedMs;
            const staleAfter = Math.max(4000, root.configuredIntervalMs * 3.5);
            const restartAfter = Math.max(10000, root.configuredIntervalMs * 8);
            if (age > staleAfter && root.state === "ready")
                root.state = "stale";
            if (age > restartAfter && root._streamProcess.running && !root._timeoutRestartIssued) {
                root._timeoutRestartIssued = true;
                root.errorMessage = qsTr("System monitor data has not updated for a long time");
                root.errorDetails = qsTr("Reconnecting to the keytop data stream.");
                root._terminateStream("data_timeout");
            }
        }
    }

    Timer {
        id: forceStopTimer

        interval: 2000
        repeat: false
        onTriggered: {
            const processId = Number(root._streamProcess.processId);
            if (root._streamProcess.running && root._startedGeneration === root._streamGeneration && isFinite(
                        processId) && processId > 0) {
                root._streamProcess.signal(9);
                return;
            }
            if (root._streamProcess.running && root._terminationPending && root._forceStopProbeCount < 8) {
                root._forceStopProbeCount += 1;
                forceStopTimer.interval = 250;
                forceStopTimer.restart();
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root._replacementProcess !== null
        onTriggered: {
            if (Date.now() - root._replacementProcess.startedAtMs > Math.max(6000, root.configuredIntervalMs
                                                                             * 6))
                root._terminateStream("first_snapshot_timeout");
        }
    }

    component MonitorStream: Process {
        id: collector

        property var modules: []
        property int generation: -1
        property bool didStart: false
        property int malformedLines: 0
        property double startedAtMs: 0
        property Timer terminationTimer: Timer {
            interval: 2000
            onTriggered: {
                if (collector.running)
                    collector.signal(9);
            }
        }

        function terminate() {
            if (!collector.running)
                return;
            collector.running = false;
            collector.terminationTimer.restart();
        }

        function stopped(reason, exitCode) {
            if (collector === root._streamProcess) {
                root._handleStreamStopped(collector.generation, reason, exitCode);
            } else if (collector === root._replacementProcess) {
                root._terminateStream(reason);
            } else {
                Qt.callLater(root._prepareReplacement);
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root._consumeLine(line, collector)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => root._consumeDiagnostic(line, collector)
        }

        onStarted: {
            collector.didStart = true;
            collector.startedAtMs = Date.now();
            if (collector === root._replacementProcess)
                return;
            if (collector !== root._streamProcess) {
                collector.terminate();
                return;
            }
            root._startedGeneration = collector.generation;
            root._streamStartedAtMs = collector.startedAtMs;
            if (root._terminationPending || !root.active) {
                root._terminationPending = true;
                root._forceStopProbeCount = 0;
                collector.running = false;
                forceStopTimer.interval = 2000;
                forceStopTimer.restart();
            }
        }
        onExited: (exitCode, exitStatus) => {
            collector.terminationTimer.stop();
            collector.stopped(root._forcedRestartReason || "unexpected_exit", exitCode);
        }
        onRunningChanged: {
            if (running)
                return;
            const generation = collector.generation;
            Qt.callLater(function () {
                if (generation !== collector.generation || collector.running)
                    return;
                collector.stopped(collector.didStart ? (root._forcedRestartReason || "unexpected_exit") :
                                                       "failed_to_start", -1);
            });
        }
    }

    MonitorStream {
        id: firstStream
    }
    MonitorStream {
        id: secondStream
    }

    Process {
        id: keyTopProbe

        onExited: (exitCode, exitStatus) => {
            root._handleKeyTopProbe(root._keyTopProbeGeneration, exitCode);
        }
        onRunningChanged: {
            if (running)
                return;
            const generation = root._keyTopProbeGeneration;
            Qt.callLater(function () {
                if (generation === root._keyTopProbeGeneration && !keyTopProbe.running) {
                    root._handleKeyTopProbe(generation, 127);
                }
            });
        }
    }

    Process {
        id: terminalProbe

        onExited: (exitCode, exitStatus) => {
            root._handleTerminalProbe(root._terminalProbeGeneration, exitCode);
        }
        onRunningChanged: {
            if (running)
                return;
            const generation = root._terminalProbeGeneration;
            Qt.callLater(function () {
                if (generation === root._terminalProbeGeneration && !terminalProbe.running) {
                    root._handleTerminalProbe(generation, 127);
                }
            });
        }
    }
}
