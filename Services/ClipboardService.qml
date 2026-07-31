pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int requiredSchemaVersion: 2
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
    property bool loading: false
    property bool actionRunning: false
    property bool inspecting: false
    property bool available: false
    property bool canList: false
    property bool canRestore: false
    property bool watcherRunning: false
    property var dependencies: ({ cliphist: false, wlCopy: false })
    property var capabilities: ({ inspect: false, preview: false,
        mimeRestore: false })
    property var entries: []
    property var detailsById: ({})
    property var error: null
    property var lastActionError: null
    property int lastActionExitCode: -1
    property string lastActionStderr: ""
    property int revision: 0
    property int detailsRevision: 0

    property string _listOutput: ""
    property string _listErrorOutput: ""
    property bool _listExited: false
    property bool _listStdoutFinished: false
    property int _listExitCode: -1

    property string _actionOutput: ""
    property string _actionErrorOutput: ""
    property string _actionName: ""
    property string _actionId: ""
    property bool _actionExited: false
    property bool _actionStdoutFinished: false
    property int _actionExitCode: -1

    property var _inspectQueue: []
    property string _inspectId: ""
    property string _inspectOutput: ""
    property bool _inspectExited: false
    property bool _inspectStdoutFinished: false
    property int _inspectExitCode: -1

    signal restored(string id)
    signal deleted(string id)
    signal cleared()
    signal inspected(string id)
    signal inspectFailed(string id, string code, string message)
    signal actionFailed(string action, string id, string code, string message)

    function normalizedError(value, fallbackCode, fallbackMessage) {
        const code = value && typeof value === "object"
            ? String(value.code || fallbackCode) : fallbackCode;
        const localized = {
            cliphist_watcher_inactive:
                qsTr("cliphist 监听服务未运行；请启用服务后重新复制内容"),
            cliphist_unavailable:
                qsTr("缺少 cliphist，无法读取剪贴板历史"),
            wl_copy_unavailable:
                qsTr("缺少 wl-copy，无法恢复剪贴板内容"),
            clipboard_dependency_unavailable:
                qsTr("缺少 cliphist 或 wl-copy，剪贴板历史不可用"),
            cliphist_decode_failed:
                qsTr("无法从 cliphist 解码该条目"),
            clipboard_inspect_failed:
                qsTr("无法检查该剪贴板条目"),
            clipboard_preview_failed:
                qsTr("无法生成剪贴板预览"),
            clipboard_payload_too_large:
                qsTr("该剪贴板内容超过安全大小限制"),
            clipboard_image_decode_failed:
                qsTr("图片数据已损坏或尺寸过大"),
            clipboard_file_missing:
                qsTr("剪贴板中的文件已不存在"),
            clipboard_mime_unsupported:
                qsTr("无法可靠恢复该剪贴板格式"),
            wl_copy_failed:
                qsTr("wl-copy 写入系统剪贴板失败"),
            invalid_clipboard_response:
                qsTr("剪贴板服务返回了无效数据"),
            stale_key_cli:
                qsTr("当前 key CLI 版本过旧；请构建并安装仓库中的新版 key"),
            clipboard_action_busy:
                qsTr("已有剪贴板操作正在执行")
        };
        return {
            code: code,
            message: localized[code] || (
                value && typeof value === "object"
                    ? String(value.message || fallbackMessage)
                    : fallbackMessage)
        };
    }

    function parseResponse(text) {
        try {
            const parsed = JSON.parse(String(text || "").trim() || "{}");
            return parsed && typeof parsed === "object" ? parsed : null;
        } catch (parseError) {
            return null;
        }
    }

    function responseIsCurrent(response) {
        return response
            && Number(response.schemaVersion || 0)
                >= root.requiredSchemaVersion
            && response.capabilities
            && response.capabilities.inspect === true
            && response.capabilities.mimeRestore === true;
    }

    function applyListResponse(text) {
        const response = root.parseResponse(text);
        if (!response) {
            root.available = false;
            root.canList = false;
            root.canRestore = false;
            root.watcherRunning = false;
            root.entries = [];
            root.error = root.normalizedError(
                null, "invalid_clipboard_response",
                qsTr("剪贴板服务返回了无效数据"));
            root.revision += 1;
            return;
        }
        if (!root.responseIsCurrent(response)) {
            root.available = false;
            root.canList = false;
            root.canRestore = false;
            root.watcherRunning = response.watcherRunning === true;
            root.dependencies = response.dependencies || {
                cliphist: false, wlCopy: false
            };
            root.entries = [];
            root.error = root.normalizedError(
                null, "stale_key_cli",
                qsTr("当前 key CLI 不支持新版剪贴板协议"));
            root.revision += 1;
            return;
        }

        root.available = response.available === true;
        root.canList = response.canList === true;
        root.canRestore = response.canRestore === true;
        root.watcherRunning = response.watcherRunning === true;
        root.dependencies = response.dependencies || {
            cliphist: false, wlCopy: false
        };
        root.capabilities = response.capabilities;
        root.entries = Array.isArray(response.entries)
            ? response.entries : [];
        root.error = response.ok === true
            ? null
            : root.normalizedError(
                response.error,
                "clipboard_unavailable",
                qsTr("剪贴板历史不可用"));
        root.revision += 1;
    }

    function refresh(limit) {
        if (listProcess.running)
            return false;
        const safeLimit = Math.max(1, Math.min(500, Number(limit) || 100));
        root.loading = true;
        root._listOutput = "";
        root._listErrorOutput = "";
        root._listExited = false;
        root._listStdoutFinished = false;
        root._listExitCode = -1;
        listProcess.command = [
            root.commandName, "clipboard", "list",
            "--format", "json", "--limit", String(safeLimit)
        ];
        listProcess.running = true;
        return true;
    }

    function finalizeListIfReady() {
        if (!root._listExited || !root._listStdoutFinished)
            return;
        root.loading = false;
        root.applyListResponse(root._listOutput);
    }

    function runAction(action, id) {
        const normalizedId =
            id === undefined || id === null ? "" : String(id);
        if (actionProcess.running || root.actionRunning) {
            const failure = root.normalizedError(
                null, "clipboard_action_busy",
                qsTr("已有剪贴板操作正在执行"));
            root.actionFailed(action, normalizedId,
                              failure.code, failure.message);
            return false;
        }
        const command = [root.commandName, "clipboard", action];
        if (normalizedId !== "")
            command.push(normalizedId);
        command.push("--format", "json");
        root.actionRunning = true;
        root.lastActionError = null;
        root.lastActionExitCode = -1;
        root.lastActionStderr = "";
        root._actionName = action;
        root._actionId = normalizedId;
        root._actionOutput = "";
        root._actionErrorOutput = "";
        root._actionExited = false;
        root._actionStdoutFinished = false;
        root._actionExitCode = -1;
        actionProcess.command = command;
        actionProcess.running = true;
        return true;
    }

    function restore(id) {
        return root.runAction("restore", id);
    }

    function deleteEntry(id) {
        return root.runAction("delete", id);
    }

    function clear() {
        return root.runAction("clear");
    }

    function finalizeActionIfReady() {
        if (!root._actionExited || !root._actionStdoutFinished)
            return;
        root.actionRunning = false;
        root.lastActionExitCode = root._actionExitCode;
        root.lastActionStderr =
            String(root._actionErrorOutput || "").slice(0, 512);
        const response = root.parseResponse(root._actionOutput);
        if (root._actionExitCode !== 0
                || !response || response.ok !== true) {
            const failure = root.normalizedError(
                response ? response.error : null,
                response ? "clipboard_action_failed"
                         : "invalid_clipboard_response",
                qsTr("剪贴板操作失败"));
            root.lastActionError = failure;
            root.actionFailed(root._actionName, root._actionId,
                              failure.code, failure.message);
            return;
        }
        if (Number(response.schemaVersion || 0)
                < root.requiredSchemaVersion) {
            const failure = root.normalizedError(
                null, "stale_key_cli",
                qsTr("当前 key CLI 不支持新版剪贴板协议"));
            root.lastActionError = failure;
            root.actionFailed(root._actionName, root._actionId,
                              failure.code, failure.message);
            return;
        }

        root.lastActionError = null;
        const responseId = String(response.id || root._actionId);
        if (root._actionName === "restore") {
            root.restored(responseId);
        } else if (root._actionName === "delete") {
            const nextDetails = Object.assign({}, root.detailsById);
            delete nextDetails[responseId];
            root.detailsById = nextDetails;
            root.detailsRevision += 1;
            root.deleted(responseId);
            root.refresh();
        } else if (root._actionName === "clear") {
            root.detailsById = {};
            root.detailsRevision += 1;
            root.cleared();
            root.refresh();
        }
    }

    function detail(id) {
        return root.detailsById[String(id)] || null;
    }

    function inspect(id) {
        const normalizedId = String(id || "");
        if (normalizedId === "" || root.detailsById[normalizedId])
            return normalizedId !== "";
        if (root._inspectId === normalizedId
                || root._inspectQueue.indexOf(normalizedId) >= 0)
            return true;
        const nextQueue = root._inspectQueue.slice();
        nextQueue.push(normalizedId);
        root._inspectQueue = nextQueue;
        root.startNextInspect();
        return true;
    }

    function cancelInspect(id) {
        const normalizedId = String(id || "");
        if (normalizedId === "" || normalizedId === root._inspectId)
            return false;
        const nextQueue = root._inspectQueue.filter(
            queuedId => String(queuedId) !== normalizedId);
        if (nextQueue.length === root._inspectQueue.length)
            return false;
        root._inspectQueue = nextQueue;
        root.inspecting = root._inspectId !== ""
            || root._inspectQueue.length > 0;
        return true;
    }

    function startNextInspect() {
        if (inspectProcess.running || root._inspectId !== ""
                || root._inspectQueue.length === 0)
            return;
        const nextQueue = root._inspectQueue.slice();
        root._inspectId = String(nextQueue.shift());
        root._inspectQueue = nextQueue;
        root._inspectOutput = "";
        root._inspectExited = false;
        root._inspectStdoutFinished = false;
        root._inspectExitCode = -1;
        root.inspecting = true;
        inspectProcess.command = [
            root.commandName, "clipboard", "inspect",
            root._inspectId, "--format", "json"
        ];
        inspectProcess.running = true;
    }

    function finalizeInspectIfReady() {
        if (!root._inspectExited || !root._inspectStdoutFinished)
            return;
        const id = root._inspectId;
        const response = root.parseResponse(root._inspectOutput);
        if (root._inspectExitCode === 0 && response
                && response.ok === true
                && Number(response.schemaVersion || 0)
                    >= root.requiredSchemaVersion) {
            const nextDetails = Object.assign({}, root.detailsById);
            nextDetails[id] = response;
            root.detailsById = nextDetails;
            root.detailsRevision += 1;
            root.inspected(id);
        } else {
            const failure = root.normalizedError(
                response ? response.error : null,
                response ? "clipboard_inspect_failed"
                         : "invalid_clipboard_response",
                qsTr("无法检查剪贴板条目"));
            root.inspectFailed(id, failure.code, failure.message);
        }
        root._inspectId = "";
        root.inspecting = root._inspectQueue.length > 0;
        Qt.callLater(root.startNextInspect);
    }

    Process {
        id: listProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root._listOutput = this.text;
                root._listStdoutFinished = true;
                root.finalizeListIfReady();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root._listErrorOutput = this.text
        }
        onExited: exitCode => {
            root._listExitCode = exitCode;
            root._listExited = true;
            root.finalizeListIfReady();
        }
    }

    Process {
        id: actionProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root._actionOutput = this.text;
                root._actionStdoutFinished = true;
                root.finalizeActionIfReady();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root._actionErrorOutput = this.text
        }
        onExited: exitCode => {
            root._actionExitCode = exitCode;
            root._actionExited = true;
            root.finalizeActionIfReady();
        }
    }

    Process {
        id: inspectProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root._inspectOutput = this.text;
                root._inspectStdoutFinished = true;
                root.finalizeInspectIfReady();
            }
        }
        onExited: exitCode => {
            root._inspectExitCode = exitCode;
            root._inspectExited = true;
            root.finalizeInspectIfReady();
        }
    }
}
