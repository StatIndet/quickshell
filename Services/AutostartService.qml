pragma Singleton

import QtCore
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property string configHome: root.localPath(StandardPaths.writableLocation(
                                                            StandardPaths.ConfigLocation))
    readonly property string autostartDir: root.configHome + "/autostart"

    property var entries: []
    property bool initialized: false
    property bool initializationFailed: false
    property bool operationBusy: false
    property string operationName: ""
    property string operationPath: ""
    property var operationContext: null
    property string lastError: ""
    property string lastMessage: ""

    readonly property bool initializing: initProcess.running
    readonly property bool listing: root.initialized && folderModel.status !== FolderListModel.Ready
    readonly property bool busy: root.initializing || root.operationBusy
    readonly property bool ready: root.initialized && folderModel.status === FolderListModel.Ready &&
                                  !root.operationBusy

    signal operationFinished(bool success, string operation)

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

    function clearStatus() {
        root.lastError = "";
        root.lastMessage = "";
    }

    function initialize() {
        if (root.operationBusy || initProcess.running)
            return false;

        root.clearStatus();
        root.initialized = false;
        root.initializationFailed = false;
        root.entries = [];
        folderModel.folder = "";
        initProcess.running = true;
        return true;
    }

    function refresh() {
        if (!root.initialized || root.busy)
            return false;

        // FolderListModel watches the directory. Rebinding it also gives the
        // refresh action a deterministic way to recover after an external
        // directory replacement.
        root.entries = [];
        folderModel.folder = "";
        folderModel.folder = Paths.fileUrl(root.autostartDir);
        return true;
    }

    function normalizeFolderPath(value) {
        return root.localPath(value).replace(/\/+$/, "") || "/";
    }

    function pathForModel(index) {
        if (index < 0 || index >= folderModel.count)
            return "";
        return root.normalizeFolderPath(folderModel.get(index, "filePath"));
    }

    function isUserEntryPath(value) {
        const path = root.normalizeFolderPath(value);
        const directory = root.normalizeFolderPath(root.autostartDir);
        if (!path || path === directory || !path.startsWith(directory + "/"))
            return false;
        const fileName = path.substring(directory.length + 1);
        return fileName !== "" && fileName !== "." && fileName !== ".." && fileName.indexOf("/") < 0
                && fileName.endsWith(".desktop");
    }

    function entryExists(path) {
        const normalized = root.normalizeFolderPath(path);
        if (root.entries.some(entry => root.normalizeFolderPath(entry.filePath) === normalized))
            return true;
        for (let index = 0; index < folderModel.count; ++index) {
            if (root.pathForModel(index) === normalized)
                return true;
        }
        return false;
    }

    function entryForPath(path) {
        const normalized = root.normalizeFolderPath(path);
        return root.entries.find(entry => root.normalizeFolderPath(entry.filePath) === normalized) || null;
    }

    function desktopId(application) {
        const raw = String(application ? application.id || "" : "").trim();
        if (raw === "" || raw.indexOf("/") >= 0 || raw.indexOf("\\") >= 0 || raw.indexOf("..") >= 0 ||
                /[\u0000-\u001f\u007f]/.test(raw))
            return "";

        let id = raw;
        while (id.toLowerCase().endsWith(".desktop"))
            id = id.substring(0, id.length - ".desktop".length);
        id = id.replace(/[^A-Za-z0-9_.-]+/g, "-").replace(/^[.-]+|[.-]+$/g, "");
        return id === "" ? "" : id + ".desktop";
    }

    function safeField(value, field, required) {
        const text = String(value || "");
        if (text.indexOf("\u0000") >= 0 || text.indexOf("\n") >= 0 || text.indexOf("\r") >= 0)
            throw new Error(qsTr("%1 contains invalid newline characters").arg(field));
        if (required && text.trim() === "")
            throw new Error(qsTr("%1 cannot be empty").arg(field));
        return text;
    }

    function applicationCommand(application) {
        if (!application)
            return "";
        return String(application.execString || application.exec || "").trim();
    }

    function applicationIcon(application) {
        return String(application ? application.icon || "" : "").trim();
    }

    function renderApplication(application) {
        const name = root.safeField(application ? application.name || application.id : "", qsTr(
                                        "Application name"), true);
        const command = root.safeField(root.applicationCommand(application), "Exec", true);
        const icon = root.safeField(root.applicationIcon(application), "Icon", false);
        return "[Desktop Entry]\n" + "Type=Application\n" + "Name=" + name + "\n" + "Exec=" + command + "\n"
                + "Icon=" + icon + "\n" + "Hidden=false\n";
    }

    function beginWrite(operationName, path, content, context) {
        if (!root.isUserEntryPath(path)) {
            root.lastError = qsTr("Refusing to modify files outside the user autostart directory");
            return false;
        }
        if (root.operationBusy || !root.initialized) {
            root.lastError = qsTr("The user autostart directory is not ready");
            return false;
        }

        root.clearStatus();
        root.operationName = operationName;
        root.operationPath = root.normalizeFolderPath(path);
        root.operationContext = context || null;
        root.operationBusy = true;
        try {
            writerFileView.path = root.operationPath;
            writerFileView.setText(content);
        } catch (error) {
            root.finishWrite(false, String(error));
        }
        return true;
    }

    function finishWrite(success, errorMessage) {
        const operationName = root.operationName;
        const operationPath = root.operationPath;
        const context = root.operationContext;
        root.operationBusy = false;

        if (success) {
            if (operationName === "add") {
                if (context && context.content)
                    root.addOrUpdateEntry(root.parseDesktopFile(context.content, operationPath));
                root.lastMessage = qsTr("Application added to autostart");
            } else if (operationName === "toggle") {
                root.lastMessage = qsTr("Autostart status updated");
            }
            root.lastError = "";
        } else {
            if (operationName === "toggle" && context)
                root.updateEntry(operationPath, {
                                     "hidden": context.previousHidden,
                                     "content": context.previousContent
                                 });
            root.lastError = errorMessage || qsTr("Failed to write the autostart file");
        }

        root.operationFinished(success, operationName);
        root.operationName = "";
        root.operationPath = "";
        root.operationContext = null;
    }

    function addApplication(application) {
        if (!root.ready) {
            root.lastError = qsTr("The user autostart directory is loading; please wait");
            return false;
        }

        const fileName = root.desktopId(application);
        if (fileName === "") {
            root.lastError = qsTr("The selected application has no valid Desktop Entry ID");
            return false;
        }
        const path = root.autostartDir + "/" + fileName;
        if (root.entryExists(path)) {
            root.lastError = qsTr("This application is already added to autostart");
            return false;
        }

        let content = "";
        try {
            content = root.renderApplication(application);
        } catch (error) {
            root.lastError = String(error);
            return false;
        }
        return root.beginWrite("add", path, content, {
                                   "content": content
                               });
    }

    function hiddenValue(text) {
        return String(text || "").trim().toLowerCase() === "true";
    }

    function rewriteHidden(content, hidden) {
        const lines = String(content || "").split("\n");
        const value = "Hidden=" + (hidden ? "true" : "false");
        let inDesktopEntry = false;
        let sectionFound = false;
        let hiddenFound = false;
        let sectionIndex = -1;

        for (let index = 0; index < lines.length; ++index) {
            const line = lines[index].endsWith("\r") ? lines[index].substring(0, lines[index].length - 1) :
                                                       lines[index];
            if (line.trim() === "[Desktop Entry]") {
                inDesktopEntry = true;
                sectionFound = true;
                sectionIndex = index;
                continue;
            }
            if (inDesktopEntry && /^\s*\[[^]]+\]\s*$/.test(line)) {
                inDesktopEntry = false;
                continue;
            }
            if (inDesktopEntry && /^\s*Hidden\s*=/.test(line)) {
                const carriageReturn = lines[index].endsWith("\r") ? "\r" : "";
                const indentation = line.match(/^\s*/)[0];
                lines[index] = indentation + value + carriageReturn;
                hiddenFound = true;
            }
        }

        if (!sectionFound)
            throw new Error(qsTr("File is missing the [Desktop Entry] section"));
        if (!hiddenFound) {
            const usesCarriageReturn = lines.some(line => line.endsWith("\r"));
            lines.splice(sectionIndex + 1, 0, value + (usesCarriageReturn ? "\r" : ""));
        }
        return lines.join("\n");
    }

    function setEnabled(entry, enabled) {
        const path = String(entry ? entry.filePath || "" : "");
        if (!root.ready || !root.isUserEntryPath(path) || !entry || !entry.content) {
            root.lastError = qsTr("This user autostart entry cannot be modified");
            return false;
        }

        let content = "";
        try {
            content = root.rewriteHidden(entry.content, !enabled);
        } catch (error) {
            root.lastError = String(error);
            return false;
        }
        root.updateEntry(path, {
                             "hidden": !enabled,
                             "content": content
                         });
        return root.beginWrite("toggle", path, content, {
                                   "previousHidden": entry.hidden,
                                   "previousContent": entry.content
                               });
    }

    function remove(entry) {
        const path = root.normalizeFolderPath(entry ? entry.filePath || "" : "");
        if (!root.ready || !root.isUserEntryPath(path)) {
            root.lastError = qsTr("Refusing to delete files outside the user autostart directory");
            return false;
        }
        if (root.operationBusy)
            return false;

        root.clearStatus();
        root.operationName = "delete";
        root.operationPath = path;
        root.operationContext = null;
        root.operationBusy = true;
        const process = removeFileComponent.createObject(root, {
                                                             "targetPath": path,
                                                             "running": true
                                                         });
        if (!process) {
            root.finishDelete(false, qsTr("Could not start the delete operation"));
            return false;
        }
        return true;
    }

    function finishDelete(success, errorMessage) {
        const path = root.operationPath;
        root.operationBusy = false;
        if (success) {
            root.removeEntryByPath(path);
            root.lastMessage = qsTr("Autostart entry deleted");
            root.lastError = "";
        } else {
            root.lastError = errorMessage || qsTr("Failed to delete the autostart entry");
        }
        root.operationFinished(success, "delete");
        root.operationName = "";
        root.operationPath = "";
        root.operationContext = null;
    }

    function lookupDesktopIcon(fileName, exec) {
        const desktopId = String(fileName || "").replace(/\.desktop$/, "");
        const application = ApplicationService.findById(desktopId);
        if (application && application.icon)
            return application.icon;
        const desktopEntry = DesktopEntries.heuristicLookup(desktopId);
        if (desktopEntry && desktopEntry.icon)
            return desktopEntry.icon;

        const command = String(exec || "").trim().split(/\s+/)[0];
        const commandName = command.substring(command.lastIndexOf("/") + 1);
        if (commandName) {
            const applications = ApplicationService.applications || [];
            for (const candidate of applications) {
                const candidateCommand = root.applicationCommand(candidate).split(/\s+/)[0];
                if (candidateCommand.substring(candidateCommand.lastIndexOf("/") + 1) === commandName)
                    return candidate.icon || "";
            }
        }
        return "";
    }

    function invalidEntry(filePath, error) {
        const path = root.normalizeFolderPath(filePath);
        const fileName = path.substring(path.lastIndexOf("/") + 1);
        return {
            "id": fileName,
            "name": fileName.replace(/\.desktop$/, "") || qsTr("Invalid startup entry"),
            "exec": "",
            "icon": "",
            "hidden": false,
            "fileName": fileName,
            "filePath": path,
            "content": "",
            "valid": false,
            "error": String(error || qsTr("Could not read Desktop Entry"))
        };
    }

    function parseDesktopFile(content, filePath) {
        const path = root.normalizeFolderPath(filePath);
        const fileName = path.substring(path.lastIndexOf("/") + 1);
        const values = ({});
        let inDesktopEntry = false;
        let sectionFound = false;
        const lines = String(content || "").split("\n");

        for (let index = 0; index < lines.length; ++index) {
            const line = lines[index].endsWith("\r") ? lines[index].substring(0, lines[index].length - 1) :
                                                       lines[index];
            const trimmed = line.trim();
            if (trimmed === "[Desktop Entry]") {
                inDesktopEntry = true;
                sectionFound = true;
                continue;
            }
            if (inDesktopEntry && /^\s*\[[^]]+\]\s*$/.test(line)) {
                inDesktopEntry = false;
                continue;
            }
            if (!inDesktopEntry || trimmed === "" || trimmed.startsWith("#"))
                continue;
            const separator = line.indexOf("=");
            if (separator <= 0)
                continue;
            const key = line.substring(0, separator).trim();
            values[key] = line.substring(separator + 1);
        }

        if (!sectionFound)
            return root.invalidEntry(path, qsTr("File is missing the [Desktop Entry] section"));

        const name = String(values.Name || "").trim() || fileName.replace(/\.desktop$/, "");
        const command = String(values.Exec || "");
        const valid = command.trim() !== "";
        return {
            "id": fileName,
            "name": name || qsTr("Invalid startup entry"),
            "exec": command,
            "icon": String(values.Icon || "").trim() || root.lookupDesktopIcon(fileName, command),
            "hidden": root.hiddenValue(values.Hidden),
            "fileName": fileName,
            "filePath": path,
            "content": String(content || ""),
            "valid": valid,
            "error": valid ? "" : qsTr("Desktop Entry is missing the Exec field")
        };
    }

    function updateEntry(path, changes) {
        const normalized = root.normalizeFolderPath(path);
        const next = root.entries.slice();
        const index = next.findIndex(entry => root.normalizeFolderPath(entry.filePath) === normalized);
        if (index < 0)
            return;
        next[index] = Object.assign({}, next[index], changes);
        root.entries = next;
    }

    function addOrUpdateEntry(entry) {
        if (!entry || !root.isUserEntryPath(entry.filePath))
            return;
        const next = root.entries.slice();
        const index = next.findIndex(item => root.normalizeFolderPath(item.filePath) === root.normalizeFolderPath(
                                                 entry.filePath));
        if (index >= 0)
            next[index] = entry;
        else
            next.push(entry);
        next.sort((left, right) => String(left.name).localeCompare(String(right.name), undefined, {
                                                                       sensitivity: "base"
                                                                   }));
        root.entries = next;
    }

    function removeEntryByPath(path) {
        const normalized = root.normalizeFolderPath(path);
        root.entries = root.entries.filter(entry => root.normalizeFolderPath(entry.filePath) !== normalized);
    }

    function syncEntriesToFolder() {
        const validPaths = new Set();
        for (let index = 0; index < folderModel.count; ++index)
            validPaths.add(root.pathForModel(index));
        root.entries = root.entries.filter(entry => validPaths.has(root.normalizeFolderPath(entry.filePath)));
    }

    Process {
        id: initProcess

        command: ["mkdir", "-p", root.autostartDir]
        stderr: StdioCollector {
            id: initError
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.initialized = false;
                root.initializationFailed = true;
                root.lastError = initError.text.trim() || qsTr(
                            "Could not create the user autostart directory");
                folderModel.folder = "";
                return;
            }

            root.initialized = true;
            root.initializationFailed = false;
            root.lastError = "";
            root.lastMessage = "";
            folderModel.folder = Paths.fileUrl(root.autostartDir);
        }
    }

    FileView {
        id: writerFileView

        blockLoading: true
        atomicWrites: true
        watchChanges: false
        printErrors: false

        onSaved: root.finishWrite(true, "")
        onSaveFailed: error => root.finishWrite(false, FileViewError.toString(error))
    }

    FolderListModel {
        id: folderModel

        nameFilters: ["*.desktop"]
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        showHidden: false
        sortCaseSensitive: false
        sortField: FolderListModel.Name
        folder: ""

        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root.syncEntriesToFolder();
        }

        onCountChanged: {
            fileReaderRepeater.model = count;
            root.syncEntriesToFolder();
        }
    }

    Repeater {
        id: fileReaderRepeater
        model: 0

        Item {
            required property int index

            readonly property string filePath: root.pathForModel(index)

            FileView {
                id: fileView

                path: filePath ? Paths.fileUrl(filePath) : ""
                watchChanges: true
                printErrors: false

                onLoaded: root.addOrUpdateEntry(root.parseDesktopFile(fileView.text(), filePath))
                onFileChanged: reload()
                onLoadFailed: error => root.addOrUpdateEntry(root.invalidEntry(filePath,
                                                                               FileViewError.toString(error)))
            }
        }
    }

    Component {
        id: removeFileComponent

        Process {
            property string targetPath: ""

            command: ["rm", "--", targetPath]
            stderr: StdioCollector {
                id: deleteError
            }

            onExited: exitCode => {
                root.finishDelete(exitCode === 0, deleteError.text.trim() || qsTr(
                                      "Could not delete the user autostart entry"));
                destroy();
            }
        }
    }
}
