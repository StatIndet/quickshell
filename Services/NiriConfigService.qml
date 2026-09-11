pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import Clavis.Runtime

Singleton {
    id: root

    readonly property string sessionDesktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env(
                                                  "XDG_SESSION_DESKTOP") || "").toLowerCase()
    readonly property bool supported: sessionDesktop.indexOf("niri") !== -1 || (Quickshell.env("NIRI_SOCKET")
                                                                                || "") !== ""
    property var snapshot: ({
                                fragments: {},
                                files: [],
                                bindings: []
                            })
    property var actionCatalog: []
    property bool catalogChecked: false
    property var pendingUpdates: ({})
    property string error: ""
    property string readError: ""
    property string errorFeature: ""
    readonly property string operationMessage: error === "" ? "" : qsTr("Unable to save changes")
    readonly property var diagnostics: snapshot.diagnostics || ({})
    readonly property string configurationMessage: readError !== "" ? qsTr("Unable to check configuration") :
                                                                      diagnostics.invalid ? qsTr(
                                                                                                "Configuration is invalid") :
                                                                                            diagnostics.writable
                                                                                            === false ? qsTr(
                                                                                                            "Configuration is not writable") :
                                                                                                        ""

    function clearEditError() {
        if (errorFeature === "binds" || errorFeature === "") {
            error = "";
            errorFeature = "";
        }
    }

    property string activeFeature: ""
    property bool refreshPending: false
    readonly property bool busy: operation.running
    readonly property string revision: snapshot.revision || ""
    readonly property var bindings: snapshot.bindings || []
    readonly property var outputs: snapshot.outputs || []
    signal saved

    function state(feature) {
        if (!supported)
            return "unsupported";
        return snapshot.fragments && snapshot.fragments[feature] ? snapshot.fragments[feature].state :
                                                                   "loading";
    }

    function ready(feature) {
        return state(feature) === "ready";
    }

    function refresh() {
        if (operation.running) {
            refreshPending = true;
            return;
        }
        invoke({
                   operation: "status"
               });
    }

    function options(feature) {
        if (feature === "effects")
            return {
                xray: PersonalizationConfig.shellBlurXray
            };
        if (feature === "cursor")
            return {
                theme: ThemeService.effectiveCursorTheme(),
                size: PersonalizationConfig.cursorSize,
                hideTyping: PersonalizationConfig.cursorHideWhenTyping,
                hideAfter: PersonalizationConfig.cursorHideAfterInactiveMs
            };
        return {};
    }

    function setup(feature) {
        invoke(Object.assign(options(feature), {
                                 operation: "setup",
                                 feature: feature
                             }));
    }

    function update(feature) {
        if (!ready(feature))
            return;
        if (busy) {
            pendingUpdates = Object.assign({}, pendingUpdates, {
                                               [feature]: true
                                           });
            return;
        }
        invoke(Object.assign(options(feature), {
                                 operation: "update",
                                 feature: feature
                             }));
    }

    function save(request) {
        invoke(Object.assign({}, request, {
                                 feature: "binds"
                             }));
    }

    function invoke(request) {
        if (!supported || operation.running)
            return;
        activeFeature = request.feature || "";
        operation.writing = request.operation !== "status" && request.operation !== "catalog";
        operation.command = ["python3", Paths.systemScriptsDir + "/niri_config.py", JSON.stringify(request)];
        operation.running = true;
    }

    Component.onCompleted: refresh()
    onSupportedChanged: refresh()

    Process {
        id: operation
        property bool writing: false
        stdout: StdioCollector {
            id: result
        }
        stderr: StdioCollector {
            id: diagnostic
        }
        onExited: code => {
            let response = {};
            try {
                response = JSON.parse(result.text);
                if (response.schemaVersion !== 1)
                    throw new Error("Unsupported configuration response");
                if (writing) {
                    if (code !== 0) {
                        root.error = response.error || qsTr("Unable to save changes");
                        root.errorFeature = root.activeFeature;
                    } else if (root.errorFeature === root.activeFeature) {
                        root.error = "";
                        root.errorFeature = "";
                    }
                }
                if (response.fragments)
                    root.readError = response.error || "";
                if (response.catalog) {
                    root.actionCatalog = response.catalog;
                    root.catalogChecked = true;
                }
                if (response.fragments) {
                    if (response.error) {
                        root.snapshot = Object.assign({}, root.snapshot, {
                                                          files: response.files,
                                                          fragments: response.fragments
                                                      });
                    } else {
                        root.snapshot = response;
                    }
                }
                if (code === 0 && writing)
                    root.saved();
            } catch (e) {
                if (writing) {
                    root.error = diagnostic.text.trim() || String(e);
                    root.errorFeature = root.activeFeature;
                } else {
                    root.readError = diagnostic.text.trim() || String(e);
                }
            }
            root.activeFeature = "";
            const pending = Object.keys(root.pendingUpdates);
            if (pending.length > 0) {
                root.pendingUpdates = {};
                Qt.callLater(function () {
                    pending.forEach(feature => root.update(feature));
                });
            } else if (!root.catalogChecked && code === 0 && !response.catalog) {
                Qt.callLater(function () {
                    root.invoke({
                                    operation: "catalog"
                                });
                });
            } else if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    FileView {
        id: actionCatalogFile
        path: Paths.systemScriptsDir + "/niri-actions.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const previous = {};
                root.actionCatalog.forEach(entry => previous[entry.id] = entry);
                root.actionCatalog = JSON.parse(text()).map(entry => Object.assign({}, entry, {
                                                                                       supported:
                                                                                       entry.category
                                                                                       === "clavis" || !!(
                                                                                           previous[entry.id]
                                                                                           && previous[entry.id].supported)
                                                                                   }));
                root.catalogChecked = false;
                Qt.callLater(root.refresh);
            } catch (e) {
                root.error = String(e);
            }
        }
    }

    ConfigFileWatch {
        paths: root.snapshot.files || []
        onChanged: Qt.callLater(root.refresh)
    }
}
