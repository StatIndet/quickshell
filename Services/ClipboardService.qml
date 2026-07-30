pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

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
    property bool available: false
    property bool canList: false
    property bool canRestore: false
    property bool watcherRunning: false
    property var dependencies: ({ cliphist: false, wlCopy: false })
    property var entries: []
    property var error: null
    property int revision: 0
    property string _listOutput: ""
    property string _actionOutput: ""
    property string _actionName: ""
    property string _actionId: ""

    signal restored(string id)
    signal deleted(string id)
    signal cleared()
    signal actionFailed(string action, string code, string message)

    function normalizedError(value, fallbackCode, fallbackMessage) {
        const code = value && typeof value === "object"
            ? String(value.code || fallbackCode) : fallbackCode;
        if (code === "cliphist_watcher_inactive") {
            return {
                code: code,
                message: qsTr(
                    "cliphist 监听服务未运行；请启用 cliphist.service 后重新复制内容")
            };
        }
        if (code === "cliphist_unavailable") {
            return {
                code: code,
                message: qsTr("缺少 cliphist，无法读取剪贴板历史")
            };
        }
        if (code === "clipboard_dependency_unavailable") {
            return {
                code: code,
                message: qsTr("缺少 cliphist 或 wl-copy，剪贴板历史不可用")
            };
        }
        return {
            code: code,
            message: value && typeof value === "object"
                ? String(value.message || fallbackMessage)
                : fallbackMessage
        };
    }

    function applyListResponse(text) {
        let response = null;
        try {
            response = JSON.parse(String(text || "").trim() || "{}");
        } catch (parseError) {
            response = null;
        }

        if (!response) {
            root.available = false;
            root.canList = false;
            root.canRestore = false;
            root.watcherRunning = false;
            root.entries = [];
            root.error = {
                code: "invalid_clipboard_response",
                message: qsTr("剪贴板服务返回了无效数据")
            };
            root.revision += 1;
            return;
        }

        root.available = response.available === true;
        root.canList = response.canList === true;
        root.canRestore = response.canRestore === true;
        root.watcherRunning = response.watcherRunning === true;
        root.dependencies = response.dependencies || {
            cliphist: false,
            wlCopy: false
        };
        root.entries = Array.isArray(response.entries)
            ? response.entries : [];
        root.error = response.ok === true
            ? null
            : root.normalizedError(
                response.error,
                "clipboard_unavailable",
                qsTr("剪贴板历史不可用")
            );
        root.revision += 1;
    }

    function refresh(limit) {
        if (listProcess.running)
            return false;
        const safeLimit = Math.max(1, Math.min(500, Number(limit) || 100));
        root.loading = true;
        root._listOutput = "";
        listProcess.command = [
            root.commandName,
            "clipboard",
            "list",
            "--format",
            "json",
            "--limit",
            String(safeLimit)
        ];
        listProcess.running = true;
        return true;
    }

    function runAction(action, id) {
        if (actionProcess.running)
            return false;
        const command = [
            root.commandName,
            "clipboard",
            action
        ];
        if (id !== undefined && id !== null && String(id) !== "")
            command.push(String(id));
        command.push("--format", "json");
        root.actionRunning = true;
        root._actionName = action;
        root._actionId = id === undefined || id === null ? "" : String(id);
        root._actionOutput = "";
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

    Process {
        id: listProcess

        stdout: StdioCollector {
            onStreamFinished: root._listOutput = this.text
        }

        onExited: {
            root.loading = false;
            root.applyListResponse(root._listOutput);
        }
    }

    Process {
        id: actionProcess

        stdout: StdioCollector {
            onStreamFinished: root._actionOutput = this.text
        }

        onExited: exitCode => {
            root.actionRunning = false;
            let response = null;
            try {
                response = JSON.parse(
                    String(root._actionOutput || "").trim() || "{}"
                );
            } catch (parseError) {
                response = null;
            }

            if (exitCode !== 0 || !response || response.ok !== true) {
                const failure = root.normalizedError(
                    response ? response.error : null,
                    "clipboard_action_failed",
                    qsTr("剪贴板操作失败")
                );
                root.error = failure;
                root.actionFailed(
                    root._actionName,
                    failure.code,
                    failure.message
                );
                return;
            }

            root.error = null;
            if (root._actionName === "restore") {
                root.restored(root._actionId);
            } else if (root._actionName === "delete") {
                root.deleted(root._actionId);
                root.refresh();
            } else if (root._actionName === "clear") {
                root.cleared();
                root.refresh();
            }
        }
    }
}
