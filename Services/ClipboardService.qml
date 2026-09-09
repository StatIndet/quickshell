pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property string commandName: Paths.stableKey
    property int historyLimit: 500
    property bool historyConfigLoaded: false
    property bool historyConfigBusy: false
    property var historyConfigError: null
    property string _configOutput: ""
    property bool _configExited: false
    property bool _configStdoutFinished: false
    property int _configExitCode: -1
    property bool loading: false
    property bool actionRunning: false
    property bool inspecting: false
    property bool available: false
    property bool canList: false
    property bool canRestore: false
    property bool watcherRunning: false
    property var dependencies: ({
                                    cliphist: false,
                                    wlCopy: false,
                                    wlPaste: false
                                })
    property var capabilities: ({
                                    inspect: false,
                                    preview: false,
                                    mimeRestore: false,
                                    mimeAwareStore: false
                                })
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
    signal cleared
    signal inspected(string id)
    signal inspectFailed(string id, string code, string message)
    signal actionFailed(string action, string id, string code, string message)

    function normalizedError(value, fallbackCode, fallbackMessage) {
        const code = value && typeof value === "object" ? String(value.code || fallbackCode) : fallbackCode;
        const localized = {
            cliphist_watcher_inactive: qsTr(
                                           "The cliphist watcher is not running; enable the service and copy content again"),
            cliphist_unavailable: qsTr("cliphist is missing; clipboard history cannot be read"),
            wl_copy_unavailable: qsTr("wl-copy is missing; clipboard contents cannot be restored"),
            clipboard_dependency_unavailable: qsTr(
                                                  "cliphist or wl-copy is missing; clipboard history is unavailable"),
            cliphist_decode_failed: qsTr("Unable to decode this entry from cliphist"),
            clipboard_inspect_failed: qsTr("Unable to inspect this clipboard entry"),
            clipboard_preview_failed: qsTr("Unable to generate a clipboard preview"),
            clipboard_payload_too_large: qsTr("This clipboard content exceeds the safe size limit"),
            clipboard_image_decode_failed: qsTr("Image data is damaged or too large"),
            clipboard_file_missing: qsTr("The file in the clipboard no longer exists"),
            clipboard_mime_unsupported: qsTr("This clipboard format cannot be restored reliably"),
            wl_copy_failed: qsTr("wl-copy failed to write the system clipboard"),
            invalid_clipboard_response: qsTr("The clipboard service returned invalid data"),
            clipboard_capability_missing: qsTr(
                                              "The current key does not provide the required clipboard capability"),
            clipboard_config_read_failed: qsTr("Unable to read clipboard settings"),
            clipboard_config_write_failed: qsTr("Unable to save clipboard settings"),
            invalid_clipboard_limit: qsTr("History limit must be from 50 to 750 in steps of 50"),
            clipboard_action_busy: qsTr("A clipboard operation is already running")
        };
        return {
            code: code,
            message: localized[code] || (value && typeof value === "object" ? String(value.message
                                                                                     || fallbackMessage) :
                                                                              fallbackMessage)
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

    function responseHasCurrentCapabilities(response) {
        const capabilities = response && response.capabilities;
        return capabilities && capabilities.inspect === true && capabilities.preview === true
                && capabilities.mimeRestore === true && capabilities.mimeAwareStore === true;
    }

    function responseIsCurrent(response, command) {
        return response && !Array.isArray(response) && response.schemaVersion === 1 && response.command === command
                && root.responseHasCurrentCapabilities(response);
    }

    function applyListResponse(text) {
        const response = root.parseResponse(text);
        if (!response) {
            root.available = false;
            root.canList = false;
            root.canRestore = false;
            root.watcherRunning = false;
            root.entries = [];
            root.error = root.normalizedError(null, "invalid_clipboard_response", qsTr(
                                                  "The clipboard service returned invalid data"));
            root.revision += 1;
            return;
        }
        if (!response || Array.isArray(response) || response.schemaVersion !== 1 || response.command
                !== "clipboard.list") {

            root.available = false;
            root.canList = false;
            root.canRestore = false;
            root.watcherRunning = false;
            root.entries = [];
            root.error = root.normalizedError(null, "invalid_clipboard_response", qsTr(
                                                  "The clipboard service returned invalid data"));
            root.revision += 1;
            return;
        }
        if (!root.responseIsCurrent(response, "clipboard.list")) {
            root.available = false;
            root.canList = false;
            root.canRestore = false;
            root.watcherRunning = response.watcherRunning === true;
            root.dependencies = response.dependencies || {
                cliphist: false,
                wlCopy: false,
                wlPaste: false
            };
            root.capabilities = response.capabilities || {
                inspect: false,
                preview: false,
                mimeRestore: false,
                mimeAwareStore: false
            };
            root.entries = [];
            root.error = root.normalizedError(null, "clipboard_capability_missing", qsTr(
                                                  "The current key does not support the required clipboard capabilities"));
            root.revision += 1;
            return;
        }

        root.available = response.available === true;
        root.canList = response.canList === true;
        root.canRestore = response.canRestore === true;
        root.watcherRunning = response.watcherRunning === true;
        root.dependencies = response.dependencies || {
            cliphist: false,
            wlCopy: false,
            wlPaste: false
        };
        root.capabilities = response.capabilities;
        const nextEntries = Array.isArray(response.entries) ? response.entries : [];
        root.entries = nextEntries;
        root.pruneDetails(nextEntries);
        root.error = response.ok === true ? null : root.normalizedError(response.error, "clipboard_unavailable",
                                                                        qsTr("Clipboard history is unavailable"));
        root.revision += 1;
    }

    function pruneDetails(entries) {
        const activeIds = ({});
        const source = Array.isArray(entries) ? entries : [];
        for (let index = 0; index < source.length; index += 1) {
            const id = String(source[index].id || "");
            if (id !== "")
                activeIds[id] = true;
        }

        const current = root.detailsById || ({});
        const next = ({});
        let changed = false;
        for (const id in current) {
            if (activeIds[id])
                next[id] = current[id];
            else
                changed = true;
        }
        if (!changed)
            return;
        root.detailsById = next;
        root.detailsRevision += 1;
    }

    function loadHistoryConfig() {
        return requestHistoryConfig(null);
    }

    function setHistoryLimit(value) {
        if (!root.historyConfigLoaded)
            return false;
        return requestHistoryConfig(value);
    }

    function requestHistoryConfig(value) {
        if (root.historyConfigBusy)
            return false;
        root.historyConfigBusy = true;
        root.historyConfigError = null;
        root._configOutput = "";
        root._configExited = false;
        root._configStdoutFinished = false;
        root._configExitCode = -1;
        const command = [root.commandName, "clipboard", "config", "--format", "json"];
        if (value !== null)
            command.push("--max-items", String(value));
        else
            root.historyConfigLoaded = false;
        configProcess.command = command;
        configProcess.running = true;
        return true;
    }

    function finalizeConfigIfReady() {
        if (!root._configExited || !root._configStdoutFinished)
            return;
        const response = root.parseResponse(root._configOutput);
        const valid = response && response.schemaVersion === 1 && response.command === "clipboard.config";
        const value = valid ? response.maxItems : null;
        if (valid && root._configExitCode === 0 && response.ok === true && response.error === null
                && typeof value === "number" && value >= 50 && value <= 750 && value % 50 === 0) {
            root.historyLimit = value;
            root.historyConfigLoaded = true;
        } else {
            root.historyConfigError = root.normalizedError(valid ? response.error : null,
                                                           "invalid_clipboard_response", qsTr(
                                                               "The clipboard service returned invalid data"));
        }
        root.historyConfigBusy = false;
    }

    function refresh(limit) {
        if (listProcess.running)
            return false;
        const safeLimit = Math.max(1, Math.min(750, Number(limit) || 100));
        root.loading = true;
        root._listOutput = "";
        root._listErrorOutput = "";
        root._listExited = false;
        root._listStdoutFinished = false;
        root._listExitCode = -1;
        listProcess.command = [root.commandName, "clipboard", "list", "--format", "json", "--limit", String(
                                   safeLimit)];
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
        const normalizedId = id === undefined || id === null ? "" : String(id);
        if (actionProcess.running || root.actionRunning) {
            const failure = root.normalizedError(null, "clipboard_action_busy", qsTr(
                                                     "A clipboard operation is already running"));
            root.actionFailed(action, normalizedId, failure.code, failure.message);
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
        root.lastActionStderr = String(root._actionErrorOutput || "").slice(0, 512);
        const response = root.parseResponse(root._actionOutput);
        if (root._actionExitCode !== 0 || !response || Array.isArray(response) || response.schemaVersion
                !== 1 || response.command !== "clipboard." + root._actionName || response.ok !== true) {
            const failure = root.normalizedError(response ? response.error : null, response ? "clipboard_action_failed" : "invalid_clipboard_response",
                                                 qsTr("Clipboard operation failed"));
            root.lastActionError = failure;
            root.actionFailed(root._actionName, root._actionId, failure.code, failure.message);
            return;
        }
        root.lastActionError = null;
        const responseId = String(response.id || root._actionId);
        if (root._actionName === "restore") {
            root.restored(responseId);
        } else if (root._actionName === "delete") {
            root.entries = (root.entries || []).filter(entry => String(entry.id || "") !== responseId);
            const nextDetails = Object.assign({}, root.detailsById);
            delete nextDetails[responseId];
            root.detailsById = nextDetails;
            root.detailsRevision += 1;
            root.deleted(responseId);
        } else if (root._actionName === "clear") {
            root.entries = [];
            root.detailsById = {};
            root.detailsRevision += 1;
            root.cleared();
        }
    }

    function detail(id) {
        return root.detailsById[String(id)] || null;
    }

    function inspect(id) {
        const normalizedId = String(id || "");
        if (normalizedId === "" || root.detailsById[normalizedId])
            return normalizedId !== "";
        if (root._inspectId === normalizedId || root._inspectQueue.indexOf(normalizedId) >= 0)
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
        const nextQueue = root._inspectQueue.filter(queuedId => String(queuedId) !== normalizedId);
        if (nextQueue.length === root._inspectQueue.length)
            return false;
        root._inspectQueue = nextQueue;
        root.inspecting = root._inspectId !== "" || root._inspectQueue.length > 0;
        return true;
    }

    function startNextInspect() {
        if (inspectProcess.running || root._inspectId !== "" || root._inspectQueue.length === 0)
            return;
        const nextQueue = root._inspectQueue.slice();
        root._inspectId = String(nextQueue.shift());
        root._inspectQueue = nextQueue;
        root._inspectOutput = "";
        root._inspectExited = false;
        root._inspectStdoutFinished = false;
        root._inspectExitCode = -1;
        root.inspecting = true;
        inspectProcess.command = [root.commandName, "clipboard", "inspect", root._inspectId, "--format",
                                  "json"];
        inspectProcess.running = true;
    }

    function finalizeInspectIfReady() {
        if (!root._inspectExited || !root._inspectStdoutFinished)
            return;
        const id = root._inspectId;
        const response = root.parseResponse(root._inspectOutput);
        if (root._inspectExitCode === 0 && response && !Array.isArray(response) && response.schemaVersion
                === 1 && response.command === "clipboard.inspect" && response.ok === true) {
            const stillListed = (root.entries || []).some(entry => String(entry.id || "") === id);
            if (stillListed) {
                const nextDetails = Object.assign({}, root.detailsById);
                nextDetails[id] = response;
                root.detailsById = nextDetails;
                root.detailsRevision += 1;
                root.inspected(id);
            }
        } else {
            const failure = root.normalizedError(response ? response.error : null, response ? "clipboard_inspect_failed" : "invalid_clipboard_response",
                                                 qsTr("Unable to inspect clipboard entry"));
            root.inspectFailed(id, failure.code, failure.message);
        }
        root._inspectId = "";
        root.inspecting = root._inspectQueue.length > 0;
        Qt.callLater(root.startNextInspect);
    }

    Process {
        id: configProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root._configOutput = this.text;
                root._configStdoutFinished = true;
                root.finalizeConfigIfReady();
            }
        }
        onExited: exitCode => {
            root._configExitCode = exitCode;
            root._configExited = true;
            root.finalizeConfigIfReady();
        }
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
