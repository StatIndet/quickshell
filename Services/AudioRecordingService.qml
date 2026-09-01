pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property int schemaVersion: 1
    readonly property string commandName: Paths.stableKey
    property string state: "idle"
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
            return ;

        const code = errorObject.code || "audio_recording_error";
        const message = errorObject.message || qsTr("录音命令执行失败");
        const key = code + "\u001f" + message + "\u001f" + root.sessionId;
        if (key === root._lastErrorKey)
            return ;

        root._lastErrorKey = key;
        root.commandError(code, message);
        Quickshell.execDetached(["notify-send", "-a", "Clavis Shell", "-u", "critical", qsTr("录音失败"), message]);
    }

    function applyResponse(text, fallbackCommand) {
        const trimmed = text ? text.trim() : "";
        if (trimmed === "")
            return false;

        try {
            const response = JSON.parse(trimmed);
            if (response.schemaVersion !== root.schemaVersion) {
                root.error = {
                    "code": "unsupported_schema",
                    "message": qsTr("key audio 返回了不受支持的 JSON schema")
                };
                root.notifyError(root.error);
                return false;
            }
            const command = response.command || fallbackCommand;
            if (command === "audio.status" && startProcess.running)
                return false;

            if (command === "audio.status" && stopProcess.running && response.state === "recording")
                return false;

            const incomingUpdatedAtMs = response.updatedAtMs || 0;
            if (incomingUpdatedAtMs > 0 && root.updatedAtMs > 0 && incomingUpdatedAtMs < root.updatedAtMs)
                return false;

            root.state = response.state || "idle";
            root.sessionId = response.sessionId || "";
            root.pid = response.pid || 0;
            const source = response.source || {
            };
            root.sourceType = source.type || root.sourceType || "mic";
            root.sourceName = source.name || "";
            root.sourceNodeName = source.nodeName || "";
            root.sourceDescription = source.description || "";
            root.captureSink = source.captureSink === true;
            root.startedAtMs = response.startedAtMs || 0;
            root.completedAtMs = response.completedAtMs || 0;
            root.updatedAtMs = incomingUpdatedAtMs;
            root.temporaryPath = response.temporaryPath || "";
            root.outputPath = response.outputPath || "";
            root.error = response.error || null;
            if (root.error)
                root.notifyError(root.error);
            else
                root._lastErrorKey = "";
            if (command === "audio.stop" && response.ok === true && root.outputPath !== "")
                Quickshell.execDetached(["notify-send", "-a", "Clavis Shell", "-u", "low", root.sourceType === "system" ? qsTr("系统音频已保存") : qsTr("麦克风录音已保存"), qsTr("已保存到 %1").arg(root.outputPath)]);

            root.commandFinished(command, response.ok === true);
            return true;
        } catch (exception) {
            root.error = {
                "code": "invalid_key_json",
                "message": qsTr("无法解析 key audio 返回的 JSON: ") + exception
            };
            root.notifyError(root.error);
            return false;
        }
    }

    function start(source, options) {
        if (startProcess.running || stopProcess.running || root.isActive)
            return false;

        const settings = options || {
        };
        root.sourceType = source === "system" ? "system" : "mic";
        root.state = "starting";
        root.startedAtMs = 0;
        root.completedAtMs = 0;
        root.updatedAtMs = 0;
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

        root.state = "stopping";
        stopProcess.command = [root.commandName, "audio", "stop", "--json"];
        stopProcess.running = true;
        return true;
    }

    function refresh() {
        if (statusProcess.running || startProcess.running)
            return ;

        statusProcess.command = [root.commandName, "audio", "status", "--json"];
        statusProcess.running = true;
    }

    Process {
        id: startProcess

        onExited: (exitCode) => {
            root.lastExitCode = exitCode;
            if (exitCode !== 0)
                root.refresh();

        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "audio.start")
        }

        stderr: SplitParser {
            onRead: (data) => {
                return console.warn("[key audio start]", data.trim());
            }
        }

    }

    Process {
        id: stopProcess

        onExited: (exitCode) => {
            root.lastExitCode = exitCode;
            root.refresh();
        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "audio.stop")
        }

        stderr: SplitParser {
            onRead: (data) => {
                return console.warn("[key audio stop]", data.trim());
            }
        }

    }

    Process {
        id: statusProcess

        onExited: (exitCode) => {
            root.lastExitCode = exitCode;
            if (exitCode !== 0 && !root.error) {
                root.error = {
                    "code": "key_unavailable",
                    "message": qsTr("无法通过 key 查询录音状态")
                };
                root.notifyError(root.error);
            }
        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "audio.status")
        }

        stderr: SplitParser {
            onRead: (data) => {
                return console.warn("[key audio status]", data.trim());
            }
        }

    }

    Timer {
        interval: root.isActive ? 400 : 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 50
        repeat: true
        running: root.isActive
        onTriggered: root._nowMs = Date.now()
    }

}
