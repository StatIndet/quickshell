pragma Singleton

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property string configHome: root.localPath(StandardPaths.writableLocation(
                                                            StandardPaths.ConfigLocation))
    readonly property string terminalFilePath: root.configHome + "/xdg-terminals.list"

    readonly property var roleDefinitions: [({
                                                 "id": "browser",
                                                 "title": qsTr("Web browser"),
                                                 "description": qsTr("Opens web pages and HTTP links"),
                                                 "icon": "language",
                                                 "group": "internet",
                                                 "category": "WebBrowser",
                                                 "primaryMime": "x-scheme-handler/https",
                                                 "mimes": ["x-scheme-handler/https", "x-scheme-handler/http",
                                                     "text/html", "application/xhtml+xml"]
                                             }), ({
                                                      "id": "mail",
                                                      "title": qsTr("Email"),
                                                      "description": qsTr("Handles email links"),
                                                      "icon": "mail",
                                                      "group": "internet",
                                                      "category": "",
                                                      "primaryMime": "x-scheme-handler/mailto",
                                                      "mimes": ["x-scheme-handler/mailto"]
                                                  }), ({
                                                           "id": "file-manager",
                                                           "title": qsTr("File manager"),
                                                           "description": qsTr(
                                                                              "Opens folders and directories"),
                                                           "icon": "folder",
                                                           "group": "utilities",
                                                           "category": "FileManager",
                                                           "primaryMime": "inode/directory",
                                                           "mimes": ["inode/directory",
                                                               "x-scheme-handler/file"]
                                                       }), ({
                                                                "id": "terminal",
                                                                "title": qsTr("Terminal"),
                                                                "description": qsTr(
                                                                                   "System default terminal emulator"),
                                                                "icon": "terminal",
                                                                "group": "utilities",
                                                                "category": "TerminalEmulator",
                                                                "primaryMime": "",
                                                                "mimes": []
                                                            }), ({
                                                                     "id": "text-editor",
                                                                     "title": qsTr("Text editor"),
                                                                     "description": qsTr(
                                                                                        "Opens plain-text files"),
                                                                     "icon": "edit_note",
                                                                     "group": "documents",
                                                                     "category": "",
                                                                     "primaryMime": "text/plain",
                                                                     "mimes": ["text/plain", "text/markdown",
                                                                         "application/json"]
                                                                 }), ({
                                                                          "id": "pdf-reader",
                                                                          "title": qsTr("PDF reader"),
                                                                          "description": qsTr(
                                                                                             "Opens PDF documents"),
                                                                          "icon": "picture_as_pdf",
                                                                          "group": "documents",
                                                                          "category": "",
                                                                          "primaryMime": "application/pdf",
                                                                          "mimes": ["application/pdf"]
                                                                      }), ({
                                                                               "id": "image-viewer",
                                                                               "title": qsTr("Image viewer"),
                                                                               "description": qsTr(
                                                                                                  "Opens common image files"),
                                                                               "icon": "image",
                                                                               "group": "multimedia",
                                                                               "category": "",
                                                                               "primaryMime": "image/png",
                                                                               "mimes": ["image/png",
                                                                                   "image/jpeg", "image/webp",
                                                                                   "image/gif", "image/avif",
                                                                                   "image/bmp", "image/tiff",
                                                                                   "image/svg+xml"]
                                                                           }), ({
                                                                                    "id": "video-player",
                                                                                    "title": qsTr(
                                                                                                 "Video player"),
                                                                                    "description": qsTr(
                                                                                                       "Plays video files"),
                                                                                    "icon": "smart_display",
                                                                                    "group": "multimedia",
                                                                                    "category": "",
                                                                                    "primaryMime": "video/mp4",
                                                                                    "mimes": ["video/mp4",
                                                                                        "video/x-matroska",
                                                                                        "video/webm",
                                                                                        "video/mpeg",
                                                                                        "video/quicktime",
                                                                                        "video/x-msvideo"]
                                                                                }), ({
                                                                                         "id": "music-player",
                                                                                         "title": qsTr(
                                                                                                      "Music player"),
                                                                                         "description": qsTr(
                                                                                                            "Plays audio files"),
                                                                                         "icon": "music_note",
                                                                                         "group": "multimedia",
                                                                                         "category": "",
                                                                                         "primaryMime":
                                                                                         "audio/mpeg",
                                                                                         "mimes": ["audio/mpeg",
                                                                                             "audio/flac",
                                                                                             "audio/x-flac",
                                                                                             "audio/ogg",
                                                                                             "audio/wav",
                                                                                             "audio/x-wav",
                                                                                             "audio/aac",
                                                                                             "audio/mp4",
                                                                                             "audio/webm"]
                                                                                     })]

    property bool loading: false
    property bool operationBusy: false
    readonly property bool busy: root.operationBusy
    property string lastError: ""
    property string lastMessage: ""
    property bool xdgMimeAvailable: true
    property bool gioAvailable: true
    property var roleStates: ({})

    property var _refreshQueue: []
    property var _refreshRoleTasks: ({})
    property int _refreshPending: 0
    property int _refreshGeneration: 0
    property var _activeCommand: null

    property string _operationRoleId: ""
    property string _operationDesktopId: ""
    property int _operationMimeIndex: 0
    property var _operationFailures: []
    property bool _terminalRefreshPending: false
    property bool _terminalFileReady: false
    property string _terminalFileContent: ""
    property string _pendingTerminalId: ""
    property bool _terminalWriting: false
    property bool _terminalVerifying: false

    signal operationFinished(bool success, string roleId)

    function localPath(value) {
        let path = String(value || "");
        if (path.startsWith("file://"))
            path = path.substring("file://".length);
        try {
            return decodeURIComponent(path);
        } catch (error) {
            return path;
        }
    }

    function emptyState(definition) {
        return {
            "currentId": "",
            "candidates": [],
            "loading": false,
            "busy": false,
            "error": "",
            "icon": definition ? definition.icon : "apps"
        };
    }

    function stateFor(roleId) {
        return root.roleStates[String(roleId)] || root.emptyState(null);
    }

    function definitionFor(roleId) {
        const value = String(roleId || "");
        return root.roleDefinitions.find(definition => definition.id === value) || null;
    }

    function setRoleState(roleId, changes) {
        const next = Object.assign({}, root.roleStates);
        next[String(roleId)] = Object.assign({}, root.stateFor(roleId), changes || {});
        root.roleStates = next;
    }

    function reportError(message) {
        const value = String(message || "").trim();
        if (value !== "" && root.lastError === "")
            root.lastError = value;
    }

    function normalizeDesktopId(identifier) {
        let value = String(identifier || "").trim();
        if (value === "" || value.indexOf("/") >= 0 || value.indexOf("\\") >= 0 || value.indexOf("..") >= 0 ||
                /[\u0000-\u001f\u007f\s]/.test(value))
            return "";

        while (value.toLowerCase().endsWith(".desktop"))
            value = value.substring(0, value.length - ".desktop".length);
        if (value === "" || !/^[A-Za-z0-9][A-Za-z0-9_.+-]*$/.test(value))
            return "";
        return value + ".desktop";
    }

    function applicationForId(desktopId) {
        const normalized = root.normalizeDesktopId(desktopId);
        if (normalized === "")
            return null;

        const application = ApplicationService.findById(normalized);
        if (application)
            return application;

        const withoutSuffix = normalized.substring(0, normalized.length - ".desktop".length);
        return DesktopEntries.heuristicLookup(normalized) || DesktopEntries.heuristicLookup(withoutSuffix);
    }

    function applicationId(application) {
        if (!application)
            return "";
        return root.normalizeDesktopId(application.id || application.desktopId || application.desktopFileId
                                       || "");
    }

    function applicationOption(desktopId) {
        const normalized = root.normalizeDesktopId(desktopId);
        if (normalized === "")
            return null;

        const application = root.applicationForId(normalized);
        const label = application && String(application.name || "").trim() !== "" ? String(application.name) :
                                                                                    normalized;
        const icon = application && application.icon ? ApplicationService.iconSource(application.icon) : "";
        const description = application ? String(application.comment || application.genericName || "") : "";
        return {
            "label": label,
            "value": normalized,
            "icon": icon,
            "description": description,
            "available": !!application
        };
    }

    function uniqueOptions(desktopIds) {
        const seen = new Set();
        const result = [];
        for (const desktopId of desktopIds || []) {
            const normalized = root.normalizeDesktopId(desktopId);
            if (normalized === "" || seen.has(normalized))
                continue;
            seen.add(normalized);
            const option = root.applicationOption(normalized);
            if (option)
                result.push(option);
        }
        result.sort((left, right) => String(left.label).localeCompare(String(right.label), undefined, {
                                                                          sensitivity: "base"
                                                                      }));
        return result;
    }

    function withCurrentOption(options, currentId) {
        const normalized = root.normalizeDesktopId(currentId);
        if (normalized === "")
            return options || [];
        const current = (options || []).some(option => option.value === normalized);
        if (current)
            return options;
        return root.uniqueOptions((options || []).map(option => option.value).concat([normalized]));
    }

    function applicationsForCategory(category) {
        const result = [];
        const seen = new Set();
        for (const application of ApplicationService.getVisibleApplications() || []) {
            const categories = String(application && application.categories || "").split(/[;,]/).map(value
                                                                                                     => value.trim(
                                                                                                            ));
            if (!categories.includes(category))
                continue;
            const id = root.applicationId(application);
            if (id === "" || seen.has(id))
                continue;
            seen.add(id);
            result.push(id);
        }
        return root.uniqueOptions(result);
    }

    function parseGioApplications(output) {
        const ids = [];
        for (const line of String(output || "").split("\n")) {
            const match = line.trim().match(/([A-Za-z0-9][A-Za-z0-9_.+-]*\.desktop)(?:\s|$)/);
            if (match)
                ids.push(match[1]);
        }
        return ids;
    }

    function terminalDefault(content) {
        for (const rawLine of String(content || "").split("\n")) {
            const line = rawLine.replace(/\r$/, "").trim();
            if (line === "" || line.startsWith("#") || line.startsWith("+") || line.startsWith("-"))
                continue;
            const baseId = line.split(":", 1)[0];
            const normalized = root.normalizeDesktopId(baseId);
            if (normalized !== "")
                return normalized;
        }
        return "";
    }

    function updateTerminalState(content) {
        const currentId = root.terminalDefault(content);
        let options = root.applicationsForCategory("TerminalEmulator");
        options = root.withCurrentOption(options, currentId);
        root.setRoleState("terminal", {
                              "currentId": currentId,
                              "candidates": options,
                              "loading": false
                          });
    }

    function syncCategoryCandidates() {
        for (const definition of root.roleDefinitions) {
            if (definition.category === "")
                continue;
            const state = root.stateFor(definition.id);
            const options = root.applicationsForCategory(definition.category);
            if (options.length === 0)
                continue;
            root.setRoleState(definition.id, {
                                  "candidates": root.withCurrentOption(options, state.currentId)
                              });
        }
    }

    function terminalLineId(rawLine) {
        const line = String(rawLine || "").replace(/\r$/, "").trim();
        if (line === "" || line.startsWith("#") || line.startsWith("+") || line.startsWith("-"))
            return "";
        return root.normalizeDesktopId(line.split(":", 1)[0]);
    }

    function rewriteTerminalList(content, selectedId) {
        const normalizedSelected = root.normalizeDesktopId(selectedId);
        if (normalizedSelected === "")
            throw new Error(qsTr("Invalid terminal Desktop Entry ID"));

        const lines = String(content || "").split("\n");
        const result = [];
        let firstTerminalIndex = -1;
        for (const rawLine of lines) {
            const id = root.terminalLineId(rawLine);
            if (id !== "") {
                if (firstTerminalIndex < 0)
                    firstTerminalIndex = result.length;
                if (id === normalizedSelected)
                    continue;
            }
            result.push(rawLine);
        }

        const selectedLine = normalizedSelected;
        if (firstTerminalIndex < 0)
            result.push(selectedLine);
        else
            result.splice(firstTerminalIndex, 0, selectedLine);

        let rewritten = result.join("\n");
        if (!rewritten.endsWith("\n"))
            rewritten += "\n";
        return rewritten;
    }

    function addRefreshTask(request) {
        root._refreshPending += 1;
        const counts = Object.assign({}, root._refreshRoleTasks);
        counts[request.roleId] = Number(counts[request.roleId] || 0) + 1;
        root._refreshRoleTasks = counts;
        root._refreshQueue = root._refreshQueue.concat([request]);
    }

    function finishRefreshTask(roleId) {
        if (root._refreshPending <= 0)
            return;
        root._refreshPending -= 1;
        const counts = Object.assign({}, root._refreshRoleTasks);
        counts[roleId] = Math.max(0, Number(counts[roleId] || 0) - 1);
        root._refreshRoleTasks = counts;
        if (counts[roleId] === 0)
            root.setRoleState(roleId, {
                                  "loading": false
                              });
        root.startNextRefreshTask();
        if (root._refreshPending === 0 && root._refreshQueue.length === 0 && !root._activeCommand) {
            root.loading = false;
        }
    }

    function startNextRefreshTask() {
        if (root._activeCommand || root._refreshQueue.length === 0)
            return;
        const queue = root._refreshQueue.slice();
        const request = queue.shift();
        root._refreshQueue = queue;
        root.runCommand(request);
    }

    function refresh() {
        if (root.loading || root.operationBusy)
            return false;

        ApplicationService.refresh();
        root.lastError = "";
        root.lastMessage = "";
        root.xdgMimeAvailable = true;
        root.gioAvailable = true;
        root._refreshGeneration += 1;
        root._refreshQueue = [];
        root._refreshRoleTasks = ({});
        root._refreshPending = 0;
        root._terminalRefreshPending = true;
        root.loading = true;

        const states = ({});
        for (const definition of root.roleDefinitions) {
            const state = root.emptyState(definition);
            state.loading = true;
            if (definition.category !== "")
                state.candidates = root.applicationsForCategory(definition.category);
            states[definition.id] = state;
        }
        root.roleStates = states;

        for (const definition of root.roleDefinitions) {
            if (definition.id === "terminal")
                continue;

            root.addRefreshTask({
                                    "kind": "refresh-query",
                                    "roleId": definition.id,
                                    "generation": root._refreshGeneration,
                                    "argv": ["xdg-mime", "query", "default", definition.primaryMime]
                                });

            if (definition.category === "" || root.stateFor(definition.id).candidates.length === 0) {
                root.addRefreshTask({
                                        "kind": "refresh-gio",
                                        "roleId": definition.id,
                                        "generation": root._refreshGeneration,
                                        "argv": ["env", "LC_ALL=C", "gio", "mime", definition.primaryMime]
                                    });
            }
        }

        root._refreshPending += 1;
        root._refreshRoleTasks.terminal = 1;
        root._refreshRoleTasks = Object.assign({}, root._refreshRoleTasks);
        terminalWatcher.reload();
        root.startNextRefreshTask();
        return true;
    }

    function runCommand(request) {
        if (root._activeCommand)
            return false;
        root._activeCommand = request;
        const process = commandProcessComponent.createObject(root, {
                                                                 "request": request
                                                             });
        if (!process) {
            root._activeCommand = null;
            root.handleProcessExit(request, 1, "", qsTr("Could not start the system command"));
            return false;
        }
        process.command = request.argv;
        process.running = true;
        return true;
    }

    function handleRefreshQuery(request, exitCode, stdout, stderr) {
        if (exitCode === 0) {
            const currentId = root.normalizeDesktopId(String(stdout || "").trim());
            const state = root.stateFor(request.roleId);
            root.setRoleState(request.roleId, {
                                  "currentId": currentId,
                                  "candidates": root.withCurrentOption(state.candidates, currentId)
                              });
        } else {
            const message = String(stderr || "").trim() || qsTr(
                      "Could not query system default applications");
            if (exitCode === 127) {
                root.xdgMimeAvailable = false;
                root.reportError(qsTr("xdg-utils is missing; default applications cannot be managed"));
            } else {
                root.reportError(message);
            }
            root.setRoleState(request.roleId, {
                                  "error": message
                              });
        }
        root.finishRefreshTask(request.roleId);
    }

    function handleRefreshGio(request, exitCode, stdout, stderr) {
        const state = root.stateFor(request.roleId);
        const definition = root.definitionFor(request.roleId);
        if (definition && definition.category !== "") {
            const categoryOptions = root.applicationsForCategory(definition.category);
            if (categoryOptions.length > 0) {
                root.setRoleState(request.roleId, {
                                      "candidates": root.withCurrentOption(categoryOptions, state.currentId),
                                      "error": ""
                                  });
                root.finishRefreshTask(request.roleId);
                return;
            }
        }
        if (exitCode === 0) {
            let options = root.uniqueOptions(root.parseGioApplications(stdout));
            options = root.withCurrentOption(options, state.currentId);
            root.setRoleState(request.roleId, {
                                  "candidates": options,
                                  "error": ""
                              });
        } else {
            root.gioAvailable = false;
            const message = qsTr("Could not read the application candidate list");
            root.reportError(message);
            root.setRoleState(request.roleId, {
                                  "candidates": root.withCurrentOption([], state.currentId),
                                  "error": String(stderr || "").trim() || message
                              });
        }
        root.finishRefreshTask(request.roleId);
    }

    function handleMimeOperation(exitCode, stderr) {
        const definition = root.definitionFor(root._operationRoleId);
        if (!definition)
            return;
        if (exitCode !== 0)
            root._operationFailures = root._operationFailures.concat(
                        [definition.mimes[root._operationMimeIndex]]);
        root._operationMimeIndex += 1;
        if (root._operationMimeIndex < definition.mimes.length) {
            root.runCommand({
                                "kind": "set-mime",
                                "roleId": definition.id,
                                "mime": definition.mimes[root._operationMimeIndex],
                                "argv": ["xdg-mime", "default", root._operationDesktopId,
                                    definition.mimes[root._operationMimeIndex]]
                            });
            return;
        }

        root.runCommand({
                            "kind": "verify-mime",
                            "roleId": definition.id,
                            "argv": ["xdg-mime", "query", "default", definition.primaryMime]
                        });
    }

    function finishMimeOperation(success, message) {
        const roleId = root._operationRoleId;
        root.operationBusy = false;
        root.setRoleState(roleId, {
                              "busy": false
                          });
        root.lastError = success ? "" : String(message || qsTr("Failed to set default applications"));
        root.lastMessage = success ? qsTr("Default applications updated") : "";
        root._operationRoleId = "";
        root._operationDesktopId = "";
        root._operationMimeIndex = 0;
        root._operationFailures = [];
        root.operationFinished(success, roleId);
    }

    function setRole(roleId, desktopId) {
        if (root.operationBusy || root.loading)
            return false;
        const definition = root.definitionFor(roleId);
        const normalized = root.normalizeDesktopId(desktopId);
        if (!definition || normalized === "") {
            root.lastError = qsTr("Cannot set an unknown default application");
            return false;
        }
        const state = root.stateFor(roleId);
        if (!(state.candidates || []).some(option => option.value === normalized)) {
            root.lastError = qsTr("The selected application is not a system-provided candidate");
            return false;
        }

        root.lastError = "";
        root.lastMessage = "";
        root.operationBusy = true;
        root.setRoleState(roleId, {
                              "busy": true
                          });

        if (definition.id === "terminal") {
            root._operationRoleId = definition.id;
            root._operationDesktopId = normalized;
            root.ensureTerminalConfigDirectory();
            return true;
        }

        root._operationRoleId = definition.id;
        root._operationDesktopId = normalized;
        root._operationMimeIndex = 0;
        root._operationFailures = [];
        root.runCommand({
                            "kind": "set-mime",
                            "roleId": definition.id,
                            "mime": definition.mimes[0],
                            "argv": ["xdg-mime", "default", normalized, definition.mimes[0]]
                        });
        return true;
    }

    function ensureTerminalConfigDirectory() {
        root.runCommand({
                            "kind": "mkdir-terminal",
                            "roleId": "terminal",
                            "argv": ["mkdir", "-p", root.configHome]
                        });
    }

    function beginTerminalWrite() {
        const selectedId = root._operationDesktopId;
        let content = root._terminalFileContent;
        try {
            content = root.rewriteTerminalList(content, selectedId);
        } catch (error) {
            root.finishTerminalOperation(false, String(error));
            return;
        }
        root._terminalWriting = true;
        terminalFile.setText(content);
    }

    function finishTerminalOperation(success, message) {
        const roleId = "terminal";
        root.operationBusy = false;
        root.setRoleState(roleId, {
                              "busy": false
                          });
        root.lastError = success ? "" : String(message || qsTr("Failed to set the default terminal"));
        root.lastMessage = success ? qsTr("Default terminal updated") : "";
        root._operationRoleId = "";
        root._operationDesktopId = "";
        root._pendingTerminalId = "";
        root._terminalWriting = false;
        root._terminalVerifying = false;
        root.operationFinished(success, roleId);
    }

    function handleProcessExit(request, exitCode, stdout, stderr) {
        if (!request)
            return;
        if (request.kind === "refresh-query") {
            root.handleRefreshQuery(request, exitCode, stdout, stderr);
        } else if (request.kind === "refresh-gio") {
            root.handleRefreshGio(request, exitCode, stdout, stderr);
        } else if (request.kind === "set-mime") {
            root.handleMimeOperation(exitCode, stderr);
        } else if (request.kind === "verify-mime") {
            const actualId = root.normalizeDesktopId(String(stdout || "").trim());
            const failures = root._operationFailures.slice();
            if (exitCode !== 0)
                failures.push(root.definitionFor(request.roleId).primaryMime);
            if (actualId !== root._operationDesktopId)
                failures.push(root.definitionFor(request.roleId).primaryMime);
            root._operationFailures = failures;
            root.setRoleState(request.roleId, {
                                  "currentId": actualId,
                                  "candidates": root.withCurrentOption(root.stateFor(
                                                                           request.roleId).candidates,
                                                                       actualId)
                              });
            if (failures.length > 0) {
                const uniqueFailures = [];
                for (const failure of failures) {
                    if (uniqueFailures.indexOf(failure) < 0)
                        uniqueFailures.push(failure);
                }
                root.finishMimeOperation(false, qsTr("Could not set: %1").arg(uniqueFailures.join(", ")));
            } else {
                root.finishMimeOperation(true, "");
            }
        } else if (request.kind === "mkdir-terminal") {
            if (exitCode !== 0) {
                root.finishTerminalOperation(false, String(stderr || "").trim() || qsTr(
                                                 "Could not create the XDG configuration directory"));
            } else if (root._terminalFileReady) {
                root.beginTerminalWrite();
            } else {
                root._pendingTerminalId = root._operationDesktopId;
                terminalWatcher.reload();
            }
        }
    }

    function handleTerminalLoaded(content) {
        root._terminalFileContent = String(content || "");
        root._terminalFileReady = true;
        root.updateTerminalState(root._terminalFileContent);

        if (root._terminalRefreshPending) {
            root._terminalRefreshPending = false;
            root.finishRefreshTask("terminal");
        }

        if (root._pendingTerminalId !== "") {
            root._pendingTerminalId = "";
            root.beginTerminalWrite();
        } else if (root._terminalVerifying) {
            const actualId = root.terminalDefault(root._terminalFileContent);
            if (actualId === root._operationDesktopId)
                root.finishTerminalOperation(true, "");
            else
                root.finishTerminalOperation(false, qsTr(
                                                 "The system did not accept the new default terminal"));
        }
    }

    function handleTerminalLoadFailed(error) {
        root._terminalFileContent = "";
        root._terminalFileReady = true;
        root.updateTerminalState("");

        if (root._terminalRefreshPending) {
            root._terminalRefreshPending = false;
            root.finishRefreshTask("terminal");
        }

        if (root._pendingTerminalId !== "") {
            root._pendingTerminalId = "";
            root.beginTerminalWrite();
        } else if (root._terminalVerifying) {
            root.finishTerminalOperation(false, FileViewError.toString(error));
        }
    }

    FileView {
        id: terminalFile

        path: root.terminalFilePath
        watchChanges: false
        blockLoading: true
        atomicWrites: true
        printErrors: false

        onSaved: {
            if (!root._terminalWriting)
                return;
            root._terminalWriting = false;
            root._terminalVerifying = true;
            terminalWatcher.reload();
        }

        onSaveFailed: error => {
            if (root._terminalWriting || root._terminalVerifying)
                root.finishTerminalOperation(false, FileViewError.toString(error));
        }
    }

    FileView {
        id: terminalWatcher

        path: root.terminalFilePath
        watchChanges: true
        blockLoading: true
        printErrors: false

        onLoaded: root.handleTerminalLoaded(terminalWatcher.text())

        onFileChanged: terminalWatcher.reload()

        onLoadFailed: error => root.handleTerminalLoadFailed(error)
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            ApplicationService.refresh();
            root.syncCategoryCandidates();
        }
    }

    Component {
        id: commandProcessComponent

        Process {
            required property var request

            stdout: StdioCollector {
                id: output
            }
            stderr: StdioCollector {
                id: errorOutput
            }

            onExited: exitCode => {
                const currentRequest = request;
                const stdoutText = output.text;
                const stderrText = errorOutput.text;
                root._activeCommand = null;
                root.handleProcessExit(currentRequest, exitCode, stdoutText, stderrText);
                destroy();
            }
        }
    }
}
