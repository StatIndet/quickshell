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
    readonly property string state: transientState !== "" ? transientState : backendState
    property string sessionId: ""
    property double updatedAtMs: 0
    property int pid: 0
    property string recordingType: "video"
    property var target: ({
                              "type": "region",
                              "geometry": null
                          })
    property double startedAtMs: 0
    property string temporaryPath: ""
    property string outputPath: ""
    property var error: null
    property var operationError: null
    property string _lastSavedKey: ""
    property int _reconnectAttempts: 0
    readonly property bool backendActive: RecordingState.isActive(backendState)
    property int lastExitCode: 0
    property double _nowMs: Date.now()
    readonly property bool isSelecting: state === "selecting"
    readonly property bool isStarting: state === "starting"
    readonly property bool isRecording: state === "recording"
    readonly property bool isFinalizing: state === "finalizing"
    readonly property bool isCompleted: state === "completed"
    readonly property bool isActive: isSelecting || isStarting || isRecording || state === "paused" || state
                                     === "stopping" || isFinalizing
    readonly property bool isStopPending: stopProcess.running || state === "stopping" || isFinalizing
    readonly property double elapsedMs: (isRecording || state === "paused") && startedAtMs > 0 ? Math.max(0,
                                                                                                          _nowMs - startedAtMs) :
                                                                                                 0

    signal commandFinished(string command, bool ok)
    signal selectionCancelled
    signal commandError(string code, string message)

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
                                     "message": qsTr("key command failed")
                                 });
            return false;
        }
        const watching = expectedCommand === "record.watch";
        const snapshot = expectedCommand === "record.status" || (watching && response.event === "snapshot");
        if (watching && response.event !== "snapshot" && response.event !== "changed") {
            root.reportOperation(response.error);
            return false;
        }
        if (!watching) {
            if (expectedCommand !== "record.status")
                root.transientState = "";
            root.commandFinished(expectedCommand, response.ok);
        }
        if (response.cancelled === true)
            root.selectionCancelled();
        if (!RecordingState.valid(response)) {
            // Initialization can race a CLI operation; watch waits for its lock once.
            if (expectedCommand === "record.status" && response.error && response.error.code
                    === "recording_busy")
                watchProcess.running = true;
            root.reportOperation(response.error || {
                                     "code": "invalid_key_state",
                                     "message": qsTr("key command failed")
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
            if (response.type === "gif" || response.type === "video")
                root.recordingType = response.type;
            root.target = response.target || root.target;
            if (!snapshot && newer && root.backendState === "error" && root.error)
                root.commandError(root.error.code, root.error.message);
        }
        if (!response.ok && response.state !== "error")
            root.reportOperation(response.error);
        else
            root.operationError = null;
        const savedKey = response.sessionId + ":" + response.updatedAtMs;
        if (!snapshot && (newer || expectedCommand === "record.stop") && response.ok && response.state === "completed"
                && response.outputPath && root._lastSavedKey !== savedKey) {
            root._lastSavedKey = savedKey;
            NotificationManager.fileSaved(root.recordingType === "gif" ? qsTr("GIF saved") : qsTr(
                                                                             "Screen recording saved"),
                                          response.outputPath);
        }
        if (root.backendActive && !watchProcess.running && !reconnect.running) {
            root._reconnectAttempts = 0;
            watchProcess.running = true;
        }
        return true;
    }

    function start(type, options) {
        if (startProcess.running || root.isActive)
            return false;

        const settings = options || {};
        const requestedType = type === "gif" ? "gif" : "video";
        root.error = null;
        root.recordingType = requestedType;
        root.transientState = "selecting";
        if (!RegionSelectionService.begin("record", {
                                              "type": requestedType,
                                              "audio": settings.audio || "none",
                                              "fps": settings.fps || 60,
                                              "output": settings.output || ""
                                          })) {
            root.transientState = "";
            return false;
        }
        return true;
    }

    function startSelected(geometry, options) {
        if (!geometry || startProcess.running)
            return false;

        const settings = options || {};
        const requestedType = settings.type === "gif" ? "gif" : "video";
        const command = [root.commandName, "record", "start", "--type", requestedType, "--target", "region", "--geometry",
                         geometry, "--audio", settings.audio || "none", "--fps", String(settings.fps || 60),
                         "--json"];
        if (settings.output)
            command.splice(command.length - 1, 0, "--output", settings.output);

        root.error = null;
        root.recordingType = requestedType;
        root.transientState = "starting";
        root.target = {
            "type": "region",
            "geometry": geometry
        };
        startProcess.command = command;
        startProcess.running = true;
        return true;
    }

    function stop() {
        if (root.isStopPending || !(root.isRecording || root.state === "paused"))
            return false;

        stopProcess.command = [root.commandName, "record", "stop", "--json"];
        stopProcess.running = true;
        return true;
    }

    Connections {
        function onSelectionAccepted(action, geometry, options) {
            if (action !== "record" || root.transientState !== "selecting")
                return;

            if (!root.startSelected(geometry, options)) {
                root.transientState = "";
                root.error = {
                    "code": "record_start_unavailable",
                    "message": qsTr("Could not start the recording command")
                };
                root.commandError(root.error.code, root.error.message);
            }
        }

        function onSelectionCancelled(action) {
            if (action !== "record" || root.transientState !== "selecting")
                return;

            root.transientState = "";
            root.selectionCancelled();
            root.commandFinished("record.start", false);
        }

        target: RegionSelectionService
    }

    Process {
        id: startProcess

        onExited: exitCode => {
            root.lastExitCode = exitCode;
            if (exitCode !== 0 && !root.operationError && !root.error)
                root.reportOperation({
                                         "code": "key_unavailable",
                                         "message": qsTr("key command failed")
                                     });
            root.transientState = "";
            root.transientState = "";
        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "record.start")
        }
    }

    Process {
        id: stopProcess

        onExited: exitCode => {
            root.lastExitCode = exitCode;
            if (exitCode !== 0 && !root.operationError && !root.error)
                root.reportOperation({
                                         "code": "key_unavailable",
                                         "message": qsTr("key command failed")
                                     });
            root.transientState = "";
        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "record.stop")
        }
    }

    Component.onCompleted: initialStatus.running = true

    Process {
        id: initialStatus
        command: [root.commandName, "record", "status", "--json"]
        onExited: exitCode => {
            if (exitCode !== 0 && !root.operationError && !root.error)
                root.reportOperation({
                                         "code": "key_unavailable",
                                         "message": qsTr("Could not query recording status through key")
                                     });
        }
        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "record.status")
        }
    }

    Process {
        id: watchProcess
        command: [root.commandName, "record", "watch", "--format", "jsonl"]
        stdout: SplitParser {
            onRead: data => root.applyResponse(data, "record.watch")
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
        interval: 250
        repeat: true
        running: root.isRecording
        onTriggered: root._nowMs = Date.now()
    }
}
