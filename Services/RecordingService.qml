pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property int schemaVersion: 1
    readonly property string commandName: Paths.stableKey
    property string backendState: "idle"
    property string transientState: ""
    readonly property string state: transientState !== "" ? transientState : backendState
    property string sessionId: ""
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
    property int lastExitCode: 0
    property double _nowMs: Date.now()
    readonly property bool isSelecting: state === "selecting"
    readonly property bool isStarting: state === "starting"
    readonly property bool isRecording: state === "recording"
    readonly property bool isFinalizing: state === "finalizing"
    readonly property bool isCompleted: state === "completed"
    readonly property bool isActive: isSelecting || isStarting || isRecording || isFinalizing
    readonly property bool isStopPending: stopProcess.running
    readonly property double elapsedMs: isRecording && startedAtMs > 0 ? Math.max(0, _nowMs - startedAtMs) : 0

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
                    "code": "unsupported_schema",
                    "message": qsTr("key 返回了不受支持的 JSON schema")
                };
                root.commandError(root.error.code, root.error.message);
                return false;
            }
            root.backendState = response.state || "idle";
            root.sessionId = response.sessionId || "";
            root.pid = response.pid || 0;
            root.recordingType = response.type || "video";
            root.target = response.target || {
                "type": "region",
                "geometry": null
            };
            root.startedAtMs = response.startedAtMs || 0;
            root.temporaryPath = response.temporaryPath || "";
            root.outputPath = response.outputPath || "";
            root.error = response.error || null;
            const command = response.command || fallbackCommand;
            if (command === "record.start")
                root.transientState = "";

            if (response.cancelled === true)
                root.selectionCancelled();

            if (root.error)
                root.commandError(root.error.code || "key_error", root.error.message || qsTr("key 命令执行失败"));

            if (command === "record.stop" && response.ok === true && root.backendState === "completed" && root.outputPath !== "")
                Quickshell.execDetached(["notify-send", "-a", "Clavis Shell", "-u", "low", root.recordingType === "gif" ? qsTr("GIF 已保存") : qsTr("录屏已保存"), qsTr("已保存到 %1").arg(root.outputPath)]);

            root.commandFinished(command, response.ok === true);
            return true;
        } catch (exception) {
            root.error = {
                "code": "invalid_key_json",
                "message": qsTr("无法解析 key 返回的 JSON: ") + exception
            };
            root.commandError(root.error.code, root.error.message);
            return false;
        }
    }

    function start(type, options) {
        if (startProcess.running || root.isActive)
            return false;

        const settings = options || {
        };
        root.error = null;
        root.transientState = "selecting";
        if (!RegionSelectionService.begin("record", {
            "type": type === "gif" ? "gif" : "video",
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

        const settings = options || {
        };
        const command = [root.commandName, "record", "start", "--type", settings.type === "gif" ? "gif" : "video", "--target", "region", "--geometry", geometry, "--audio", settings.audio || "none", "--fps", String(settings.fps || 60), "--json"];
        if (settings.output)
            command.splice(command.length - 1, 0, "--output", settings.output);

        root.error = null;
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
        if (stopProcess.running)
            return false;

        stopProcess.command = [root.commandName, "record", "stop", "--json"];
        stopProcess.running = true;
        return true;
    }

    function refresh() {
        if (statusProcess.running)
            return ;

        statusProcess.command = [root.commandName, "record", "status", "--json"];
        statusProcess.running = true;
    }

    Connections {
        function onSelectionAccepted(action, geometry, options) {
            if (action !== "record" || root.transientState !== "selecting")
                return ;

            if (!root.startSelected(geometry, options)) {
                root.transientState = "";
                root.error = {
                    "code": "record_start_unavailable",
                    "message": qsTr("无法启动录制命令")
                };
                root.commandError(root.error.code, root.error.message);
            }
        }

        function onSelectionCancelled(action) {
            if (action !== "record" || root.transientState !== "selecting")
                return ;

            root.transientState = "";
            root.selectionCancelled();
            root.commandFinished("record.start", false);
        }

        target: RegionSelectionService
    }

    Process {
        id: startProcess

        onExited: (exitCode) => {
            root.lastExitCode = exitCode;
            root.transientState = "";
            root.refresh();
        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "record.start")
        }

    }

    Process {
        id: stopProcess

        onExited: (exitCode) => {
            root.lastExitCode = exitCode;
            root.refresh();
        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "record.stop")
        }

    }

    Process {
        id: statusProcess

        onExited: (exitCode) => {
            root.lastExitCode = exitCode;
            if (exitCode !== 0 && !root.error) {
                root.error = {
                    "code": "key_unavailable",
                    "message": qsTr("无法通过 key 查询录制状态")
                };
                root.commandError(root.error.code, root.error.message);
            }
        }

        stdout: StdioCollector {
            onStreamFinished: root.applyResponse(this.text, "record.status")
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
