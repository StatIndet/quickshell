pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri
import qs.Common
import "../Common/functions/DisplayConfiguration.js" as Config

Singleton {
    id: root

    property var live: Niri.outputSnapshot()
    property var draft: []
    property var baseline: []
    property string revision: ""
    property string selection: ""
    property string error: ""
    property string token: ""
    property string phase: "idle"
    property int remaining: 0
    property bool identify: false
    // Keep ambiguous identities connector-bound for the current editing session.
    property var identityCollisions: []
    property string previousCombination: ""
    property string operationKind: ""
    property string commandPending: ""
    readonly property bool busy: token !== "" || operation.running
    readonly property bool confirming: phase === "confirming" && commandPending === "" && operationKind
                                       !== "keep"
    readonly property bool dirty: Config.canonical(Config.patches(draft)) !== Config.canonical(Config.patches(
                                                                                                   baseline))
    readonly property var selected: draft.find(r => r.key === selection) || null
    readonly property string validation: {
        const reason = Config.validation(draft);
        return reason === "last-output" ? qsTr("At least one connected display must remain enabled") : reason
                                          === "overlap" ? qsTr("Display rectangles overlap") : reason
                                                          === "mode" ? qsTr(
                                                                           "Select an available display mode") :
                                                                       "";
    }

    function refresh() {
        Niri.refreshOutputs();
        NiriConfigService.refresh();
    }
    function reload(clearError) {
        if (busy)
            return;
        baseline = Config.rows(live, NiriConfigService.outputs, identityCollisions);
        draft = Config.clone(baseline);
        revision = NiriConfigService.revision;
        if (!draft.some(r => r.key === selection))
            selection = draft.length ? draft[0].key : "";
        if (clearError !== false)
            error = "";
    }
    function edit(key, field, value) {
        if (busy)
            return;
        draft = draft.map(row => {
            if (row.key !== key || !row.editable)
                return row;
            const next = Config.clone(row);
            if (value === null)
                delete next.settings[field];
            else
                next.settings[field] = value;
            return next;
        });
    }
    function forget(key) {
        if (busy)
            return;
        draft = draft.map(row => row.key === key && !row.connected ? Object.assign({}, row, {
                                                                                       deleted: true
                                                                                   }) : row);
    }
    function apply() {
        if (busy || !dirty || validation || !NiriConfigService.ready("outputs"))
            return;
        error = "";
        phase = "validating";
        invoke({
                   operation: "start",
                   revision: revision,
                   main: NiriConfigService.snapshot.main,
                   outputs: Config.changes(draft, baseline)
               });
    }
    function invoke(request) {
        if (operation.running)
            return;
        operationKind = request.operation;
        operation.command = ["python3", Paths.systemScriptsDir + "/display_preview.py", JSON.stringify(
                                 request)];
        operation.running = true;
    }
    function keep() {
        if (confirming) {
            phase = "saving";
            commandPending = "keep";
            poll();
        }
    }
    function revert() {
        if (token) {
            commandPending = "revert";
            poll();
        }
    }
    function poll() {
        if (!token || operation.running)
            return;
        const command = commandPending || "status";
        commandPending = "";
        invoke({
                   operation: command,
                   token: token
               });
    }
    function identifyDisplays() {
        identify = true;
        identifyTimer.restart();
    }
    function recordCollisions(outputs) {
        const duplicates = outputs.filter(o => outputs.filter(other => Config.identity(other) === Config.identity(
                                                                           o)).length > 1).map(
                  Config.identity);
        const merged = identityCollisions.concat(duplicates).filter((id, index, all) => all.indexOf(id)
                                                                                        === index);
        if (JSON.stringify(merged) !== JSON.stringify(identityCollisions)) {
            identityCollisions = merged;
        }
    }
    Connections {
        target: Niri
        function onOutputsChanged() {
            const next = Niri.outputSnapshot();
            root.recordCollisions(next);
            const combination = Config.combination(next, root.identityCollisions);
            const changed = root.previousCombination !== "" && combination !== root.previousCombination;
            root.previousCombination = combination;
            root.live = next;
            if (changed && root.dirty && !root.busy) {
                root.draft = root.draft.map(row => {
                    const output = next.find(o => Config.stableKey(o, next, root.identityCollisions)
                                                  === row.key);
                    return Object.assign({}, row, {
                                             connected: !!output,
                                             live: output || null
                                         });
                });
                root.error = qsTr("Connected displays changed. Reload before applying.");
            }
            if (!root.busy && !root.dirty)
                root.reload(false);
        }
    }
    Connections {
        target: NiriConfigService
        function onSnapshotChanged() {
            if (!root.busy && !root.dirty)
                root.reload(false);
            else if (!root.busy && root.revision !== NiriConfigService.revision)
                root.error = qsTr("Configuration changed externally. Reload before applying.");
        }
    }
    Timer {
        id: identifyTimer
        interval: 3500
        onTriggered: root.identify = false
    }
    Timer {
        interval: 400
        running: root.token !== ""
        repeat: true
        onTriggered: root.poll()
    }
    Process {
        id: operation
        stdout: StdioCollector {
            id: response
        }
        stderr: StdioCollector {
            id: diagnostic
        }
        onExited: code => {
            try {
                const result = JSON.parse(response.text);
                if (result.schemaVersion !== 1)
                    throw new Error("Unsupported preview response");
                if (code !== 0)
                    throw new Error(result.error || diagnostic.text);
                if (root.operationKind === "cleanup")
                    Qt.callLater(function () {
                        root.reload(false);
                    });
                if (result.token)
                    root.token = result.token;
                if (result.phase)
                    root.phase = result.phase;
                root.remaining = result.remaining || 0;
                if (result.phase === "kept" || result.phase === "reverted") {
                    const old = root.token;
                    root.token = "";
                    root.phase = "idle";
                    root.commandPending = "";
                    if (result.phase === "kept")
                        root.baseline = Config.clone(root.draft);
                    else
                        root.draft = Config.clone(root.baseline);
                    root.error = result.error || "";
                    if (result.restoreErrors && result.restoreErrors.length)
                        root.error += "\n" + result.restoreErrors.join("\n");
                    root.refresh();
                    Qt.callLater(function () {
                        root.invoke({
                                        operation: "cleanup",
                                        token: old
                                    });
                    });
                }
            } catch (e) {
                root.error = String(e);
                if (!root.token)
                    root.phase = "idle";
            }
        }
    }
    Component.onCompleted: {
        recordCollisions(live);
        previousCombination = Config.combination(live, identityCollisions);
        refresh();
    }
}
