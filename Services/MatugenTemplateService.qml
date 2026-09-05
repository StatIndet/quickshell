pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    property var templates: []
    readonly property var builtinTemplates: templates.filter(t => t.origin === "builtin")
    readonly property var userTemplates: templates.filter(t => t.origin === "user")
    property bool ready: false
    property string error: ""
    property string operationError: ""
    readonly property bool busy: mutation.running || pendingOperation !== null
    property var pendingOperation: null
    property bool refreshPending: false
    property string operation: ""
    property string operationId: ""
    readonly property string script: Paths.scriptPath("theme", "manage_matugen_templates.sh")

    signal validated(bool valid)
    signal added(string templateId)
    signal removed(string templateId)

    function templateById(templateId) {
        return root.templates.find(t => t.id === templateId) || null;
    }
    function containsId(templateId) {
        return root.templateById(templateId) !== null;
    }
    function refresh() {
        if (listing.running || mutation.running) {
            root.refreshPending = true;
            return;
        }
        root.refreshPending = false;
        listing.running = true;
    }
    function runOperation(name, args) {
        if (root.busy)
            return false;
        root.operationError = "";
        if (listing.running) {
            root.pendingOperation = {name: name, args: args};
            return true;
        }
        root.operation = name;
        root.operationId = args[0];
        mutation.command = ["bash", root.script, name, ...args];
        mutation.running = true;
        return true;
    }
    function validate(templateId, source, output, hook) {
        return root.runOperation("validate", [templateId, source, output, hook]);
    }
    function add(templateId, source, output, hook) {
        return root.runOperation("add", [templateId, source, output, hook]);
    }
    function remove(templateId) {
        return root.runOperation("remove", [templateId]);
    }
    function openLocation(template) {
        const path = template.inputPath;
        Qt.openUrlExternally("file://" + path.substring(0, path.lastIndexOf("/")).split("/").map(
                                 encodeURIComponent).join("/"));
    }

    Connections {
        target: PersonalizationConfig
        function onSettingsLoaded() {
            if (root.ready)
                PersonalizationConfig.discoverMatugenTemplates(root.templates);
        }
    }

    Component.onCompleted: root.refresh()

    FileView {
        path: Paths.userMatugenDir + "/config.toml"
        watchChanges: true
        printErrors: false
        onFileChanged: refreshDebounce.restart()
    }
    Timer {
        id: refreshDebounce
        interval: 150
        onTriggered: root.refresh()
    }
    // Also discovers a previously absent config and missing/restored inputs.
    // No writable registry directory is created for watching.
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
    Process {
        id: listing
        command: ["bash", root.script, "list"]
        stdout: StdioCollector {
            id: listOutput
        }
        stderr: StdioCollector {
            id: listError
        }
        onExited: exitCode => {
            try {
                if (exitCode !== 0)
                    throw new Error(listError.text.trim() || qsTr("无法读取模板"));
                const result = JSON.parse(listOutput.text);
                if (result.schemaVersion !== 1 || !Array.isArray(result.templates))
                    throw new Error(qsTr("无效的模板数据"));
                const next = result.templates.filter(t => t.id !== "quickshell");
                if (JSON.stringify(next) !== JSON.stringify(root.templates))
                    root.templates = next;
                root.error = result.errors.join("\n");
                root.ready = true;
                PersonalizationConfig.discoverMatugenTemplates(root.templates);
            } catch (e) {
                root.error = String(e);
            }
            if (root.pendingOperation) {
                const pending = root.pendingOperation;
                root.pendingOperation = null;
                root.runOperation(pending.name, pending.args);
            } else if (root.refreshPending) {
                Qt.callLater(root.refresh);
            }
        }
    }
    Process {
        id: mutation
        stdout: StdioCollector {
            id: mutationOutput
        }
        stderr: StdioCollector {
            id: mutationError
        }
        onExited: exitCode => {
            let ok = false;
            try {
                const result = JSON.parse(mutationOutput.text);
                if (result.schemaVersion !== 1)
                    throw new Error(qsTr("无效的模板数据"));
                ok = exitCode === 0 && result.ok === true;
                root.operationError = ok ? "" : result.error || qsTr("模板操作失败");
            } catch (e) {
                root.operationError = mutationError.text.trim() || String(e);
            }
            if (root.operation === "validate") {
                root.validated(ok);
            } else if (ok && root.operation === "add") {
                // Existing saved choices are respected, including a restored ID.
                root.added(root.operationId);
            } else if (ok && root.operation === "remove") {
                root.templates = root.templates.filter(t => t.origin !== "user" || t.id !== root.operationId);
                if (!root.containsId(root.operationId))
                    PersonalizationConfig.removeMatugenTemplate(root.operationId);
                root.removed(root.operationId);
            }
            root.refresh();
        }
    }
}
