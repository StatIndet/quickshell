pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../Common/RecordingState.js" as RecordingState

Singleton {
    id: root

    readonly property int schemaVersion: 1
    readonly property string commandName: Paths.stableKey
    property string backendState: "idle"
    property string transientState: ""
    readonly property string state: transientState || backendState
    property string sessionId: ""
    property int pid: 0
    property string sourceType: "mic"
    property string sourceName: ""
    property string sourceNodeName: ""
    property string sourceDescription: ""
    property bool captureSink: false
    property double startedAtMs: 0
    property double completedAtMs: 0
    property double updatedAtMs: 0
    property string temporaryPath: ""
    property string outputPath: ""
    property var error: null
    property var operationError: null
    property string _lastSavedKey: ""
    property int _reconnectAttempts: 0
    readonly property bool backendActive: RecordingState.isActive(backendState)
    property int lastExitCode: 0
    property double _nowMs: Date.now()
    property string _lastErrorKey: ""
    readonly property bool isStarting: state === "starting"
    readonly property bool isRecording: state === "recording"
    readonly property bool isStopping: state === "stopping"
    readonly property bool isFinalizing: state === "finalizing"
    readonly property bool isError: state === "error"
    readonly property bool isActive: isStarting || isRecording || isStopping || isFinalizing
    readonly property bool isStopPending: stopProcess.running || isStopping || isFinalizing
    readonly property double elapsedMs: startedAtMs > 0 && isActive ? Math.max(0, _nowMs - startedAtMs) : 0

    signal commandFinished(string command, bool ok)
    signal commandError(string code, string message)

    function notifyError(errorObject) {
        if (!errorObject)
            return;

        const code = errorObject.code || "audio_recording_error";
        const message = errorObject.message || qsTr("Recording command failed");
        const key = code + "\u001f" + message + "\u001f" + root.sessionId;
        if (key === root._lastErrorKey)
            return;

        root._lastErrorKey = key;
        root.commandError(code, message);
        Quickshell.execDetached(["notify-send", "-a", "Clavis Shell", "-u", "critical", qsTr(
                                     "Recording failed"), message]);
    }

    function reportOperation(errorObject) {
        root.operationError = errorObject;
        if (errorObject)
            root.commandError(errorObject.code, errorObject.message);
    }

    function applyResponse(text, expectedCommand) {
        if (!text || !text.trim())
            return false;
        let response;
        try {
            response = JSON.parse(text);
        } catch (exception) {
            root.reportOperation({
                                     "code": "invalid_key_json",
                                     "message": String(exception)
                                 });
            return false;
        }
        if (!response || typeof response !== "object" || response.schemaVersion !== root.schemaVersion
                || response.command !== expectedCommand || typeof response.ok !== "boolean") {
            root.reportOperation({
                                     "code": "invalid_key_response",
                                     "message": qsTr("Recording command failed")
                                 });
            return false;
        }
        const watching = expectedCommand === "audio.watch";
        const snapshot = expectedCommand === "audio.status" || (watching && response.event === "snapshot");
        if (watching && response.event !== "snapshot" && response.event !== "changed") {
            root.reportOperation(response.error);
            return false;
        }
        if (!watching) {
            if (expectedCommand !== "audio.status")
                root.transientState = "";
            root.commandFinished(expectedCommand, response.ok);
        }
        if (!RecordingState.valid(response)) {
            // Initialization can race a CLI operation; watch waits for its lock once.
            if (expectedCommand === "audio.status" && response.error && response.error.code
                    === "recording_busy")
                watchProcess.running = true;
            root.reportOperation(response.error || {
                                     "code": "invalid_key_state",
                                     "message": qsTr("Recording command failed")
                                 });
            return false;
        }
        if (response.updatedAtMs < root.updatedAtMs || (response.updatedAtMs === root.updatedAtMs
                                                        && response.sessionId !== root.sessionId))
            return false;
        const newer = response.updatedAtMs > root.updatedAtMs;
        if (newer || root.updatedAtMs === 0) {
            root.backendState = response.state;
            root.sessionId = response.sessionId;
            root.updatedAtMs = response.updatedAtMs;
            root.pid = response.pid;
            root.startedAtMs = response.startedAtMs;
            root.temporaryPath = response.temporaryPath;
            root.outputPath = response.outputPath;
            root.error = response.state === "error" ? response.error : null;
            const source = response.source || {};
            root.sourceType = source.type || root.sourceType;
            root.sourceName = source.name || "";
            root.sourceNodeName = source.nodeName || "";
            root.sourceDescription = source.description || "";
            root.captureSink = source.captureSink === true;
            root.completedAtMs = response.completedAtMs;
            if (!snapshot && newer && root.backendState === "error" && root.error)
                root.notifyError(root.error);
        }
        if (!response.ok && response.state !== "error")
            root.reportOperation(response.error);
        else
            root.operationError = null;
        const savedKey = response.sessionId + ":" + response.updatedAtMs;
        if (!snapshot && (newer || expectedCommand === "audio.stop") && response.ok && response.state === "completed"
                && response.outputPath && root._lastSavedKey !== savedKey) {
            root._lastSavedKey = savedKey;
            NotificationManager.fileSaved(root.sourceType === "system" ? qsTr("System audio recording saved") :
                                                                         qsTr("Microphone recording saved"),
                                          response.outputPath);
        }
        if (root.backendActive && !watchProcess.running && !reconnect.running) {
            root._reconnectAttempts = 0;
            watchProcess.running = true;
        }
        return true;
    }

    function start(source, options) {
        if (startProcess.running || stopProcess.running || root.isActive)
            return false;

        const settings = options || {};
        root.sourceType = source === "system" ? "system" : "mic";
        root.transientState = "starting";
        root.startedAtMs = 0;
        root.completedAtMs = 0;
        root.error = null;
        root._lastErrorKey = "";
        const command = [root.commandName, "audio", "start", "--source", root.sourceType, "--json"];
        if (settings.output)
            command.splice(command.length - 1, 0, "--output", settings.output);

        startProcess.command = command;
        startProcess.running = true;
        return true;
    }

    function stop() {
        if (stopProcess.running || !root.isRecording)
            return false;

        root.transientState = "stopping";
        stopProcess.command = [root.commandName, "audio", "stop", "--json"];
        stopProcess.running = true;
        return true;
    }

    Process {
        id: startProcess

        onExited: exitCode => {
            root.lastExitCode = exitCode;
            if (exitCode !== 0 && !root.operationError && !root.error)
                root.reportOperation({
                                         "code": "key_unavailable",
                                         "message": qsTr("Recording command failed")
                                     });
            root.transientState = "";
        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "audio.start")
        }

        stderr: SplitParser {
            onRead: data => {
                return console.warn("[key audio start]", data.trim());
            }
        }
    }

    Process {
        id: stopProcess

        onExited: exitCode => {
            root.lastExitCode = exitCode;
            if (exitCode !== 0 && !root.operationError && !root.error)
                root.reportOperation({
                                         "code": "key_unavailable",
                                         "message": qsTr("Recording command failed")
                                     });
            root.transientState = "";
        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "audio.stop")
        }

        stderr: SplitParser {
            onRead: data => {
                return console.warn("[key audio stop]", data.trim());
            }
        }
    }

    Component.onCompleted: initialStatus.running = true

    Process {
        id: initialStatus
        command: [root.commandName, "audio", "status", "--json"]
        onExited: exitCode => {
            if (exitCode !== 0 && !root.operationError && !root.error)
                root.reportOperation({
                                         "code": "key_unavailable",
                                         "message": qsTr("Could not query recording status through key")
                                     });
        }
        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "audio.status")
        }
    }

    Process {
        id: watchProcess
        command: [root.commandName, "audio", "watch", "--format", "jsonl"]
        stdout: SplitParser {
            onRead: data => root.applyResponse(data, "audio.watch")
        }
        onExited: exitCode => {
            if (root.backendActive && root._reconnectAttempts < 3) {
                root._reconnectAttempts++;
                reconnect.start();
            }
        }
    }

    Timer {
        id: reconnect
        interval: 1000 * root._reconnectAttempts
        onTriggered: {
            if (root.backendActive)
                watchProcess.running = true;
        }
    }

    Timer {
        interval: 50
        repeat: true
        running: root.isActive
        onTriggered: root._nowMs = Date.now()
    }
}
