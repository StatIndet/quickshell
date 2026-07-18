pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int schemaVersion: 1
    property string commandName: "key"

    property string state: "idle"
    property string sessionId: ""
    property int pid: 0
    property string recordingType: "video"
    property var target: ({ type: "region", geometry: null })
    property double startedAtMs: 0
    property string temporaryPath: ""
    property string outputPath: ""
    property var error: null
    property int lastExitCode: 0
    property double _nowMs: Date.now()

    readonly property bool isSelecting: state === "selecting"
    readonly property bool isStarting: state === "starting"
    readonly property bool isRecording: state === "recording"
    readonly property bool isFinalizing: state === "finalizing"
    readonly property bool isCompleted: state === "completed"
    readonly property bool isActive: isSelecting || isStarting || isRecording || isFinalizing
    readonly property double elapsedMs: isRecording && startedAtMs > 0
        ? Math.max(0, _nowMs - startedAtMs)
        : 0

    signal commandFinished(string command, bool ok)
    signal selectionCancelled()
    signal commandError(string code, string message)

    function applyResponse(text, fallbackCommand) {
        const trimmed = text ? text.trim() : "";
        if (trimmed === "")
            return false;

        try {
            const response = JSON.parse(trimmed);
            if (response.schemaVersion !== root.schemaVersion) {
                root.error = {
                    code: "unsupported_schema",
                    message: "key 返回了不受支持的 JSON schema"
                };
                root.commandError(root.error.code, root.error.message);
                return false;
            }

            root.state = response.state || "idle";
            root.sessionId = response.sessionId || "";
            root.pid = response.pid || 0;
            root.recordingType = response.type || "video";
            root.target = response.target || { type: "region", geometry: null };
            root.startedAtMs = response.startedAtMs || 0;
            root.temporaryPath = response.temporaryPath || "";
            root.outputPath = response.outputPath || "";
            root.error = response.error || null;

            const command = response.command || fallbackCommand;
            if (response.cancelled === true)
                root.selectionCancelled();
            if (root.error)
                root.commandError(root.error.code || "key_error",
                                  root.error.message || "key 命令执行失败");
            root.commandFinished(command, response.ok === true);
            return true;
        } catch (exception) {
            root.error = {
                code: "invalid_key_json",
                message: "无法解析 key 返回的 JSON: " + exception
            };
            root.commandError(root.error.code, root.error.message);
            return false;
        }
    }

    function start(type, options) {
        if (startProcess.running || root.isActive)
            return false;

        const settings = options || {};
        const command = [
            root.commandName,
            "record",
            "start",
            "--type",
            type === "gif" ? "gif" : "video",
            "--target",
            "region",
            "--audio",
            settings.audio || "none",
            "--fps",
            String(settings.fps || 60),
            "--json"
        ];
        if (settings.output)
            command.splice(command.length - 1, 0, "--output", settings.output);

        root.error = null;
        startProcess.command = command;
        startProcess.running = true;
        return true;
    }

    function stop() {
        if (stopProcess.running)
            return false;
        stopProcess.command = [root.commandName, "record", "stop", "--json"];
        stopProcess.running = true;
        return true;
    }

    function refresh() {
        if (statusProcess.running)
            return;
        statusProcess.command = [root.commandName, "record", "status", "--json"];
        statusProcess.running = true;
    }

    Process {
        id: startProcess

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "record.start")
        }

        onExited: exitCode => {
            root.lastExitCode = exitCode;
            root.refresh();
        }
    }

    Process {
        id: stopProcess

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "record.stop")
        }

        onExited: exitCode => {
            root.lastExitCode = exitCode;
            root.refresh();
        }
    }

    Process {
        id: statusProcess

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "record.status")
        }

        onExited: exitCode => {
            root.lastExitCode = exitCode;
            if (exitCode !== 0 && !root.error) {
                root.error = {
                    code: "key_unavailable",
                    message: "无法通过 key 查询录制状态"
                };
                root.commandError(root.error.code, root.error.message);
            }
        }
    }

    Timer {
        interval: root.isActive ? 500 : 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 250
        repeat: true
        running: root.isRecording
        onTriggered: root._nowMs = Date.now()
    }
}
