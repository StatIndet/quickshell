import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property string query: ""
    property var results: []
    readonly property bool loading: ClipboardService.loading
    readonly property bool available: ClipboardService.canList && (ClipboardService.watcherRunning
                                                                   || ClipboardService.entries.length > 0)
    readonly property bool canRestore: ClipboardService.canRestore
    readonly property bool actionRunning: ClipboardService.actionRunning
    readonly property var error: ClipboardService.error
    readonly property var resultModel: clipboardModel

    signal restored(string id)
    signal restoreFailed(string id, string code, string message)
    signal deleteFailed(string id, string code, string message)

    ListModel {
        id: clipboardModel
    }

    function mergedEntry(entry) {
        const id = String(entry.id || "");
        const detail = ClipboardService.detail(id);
        return detail ? Object.assign({}, entry, detail) : entry;
    }

    function textSummary(value) {
        const lines = String(value || "").replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n").map(line
                                                                                                      => line.replace(
                                                                                                             /\t/g, " ").trim(
                                                                                                             )).filter(
                  line => line !== "");
        return lines;
    }

    function humanReadableSize(value) {
        const bytes = Number(value);
        if (!isFinite(bytes) || bytes <= 0)
            return "";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let amount = bytes;
        let unit = 0;
        while (amount >= 1024 && unit < units.length - 1) {
            amount /= 1024;
            unit += 1;
        }
        const digits = unit === 0 || amount >= 100 ? 0 : amount >= 10 ? 1 : 2;
        return amount.toFixed(digits) + " " + units[unit];
    }

    function compactParentPath(value) {
        let path = String(value || "").trim();
        const home = String(Paths.homeDir || "").replace(/\/+$/, "");
        if (home !== "" && (path === home || path.indexOf(home + "/") === 0))
            path = "~" + path.slice(home.length);
        return path;
    }

    function fileExtension(file) {
        const name = String(file && file.name || "");
        const separator = name.lastIndexOf(".");
        return separator > 0 ? name.slice(separator + 1).toLowerCase() : "";
    }

    function friendlyFileType(file) {
        const category = String(file && file.category || "file").toLowerCase();
        if (category === "folder")
            return qsTr("Folder");

        if (category === "code") {
            const codeTypes = {
                c: "C",
                h: "C/C++",
                cc: "C++",
                cpp: "C++",
                cxx: "C++",
                hpp: "C++",
                rs: "Rust",
                py: "Python",
                js: "JavaScript",
                jsx: "JavaScript",
                ts: "TypeScript",
                tsx: "TypeScript",
                lua: "Lua",
                qml: "QML",
                java: "Java",
                kt: "Kotlin",
                kts: "Kotlin",
                go: "Go",
                rb: "Ruby",
                php: "PHP",
                sh: "Shell",
                bash: "Bash",
                zsh: "Zsh",
                fish: "Fish"
            };
            const extension = root.fileExtension(file);
            return codeTypes[extension] || qsTr("Code");
        }

        if (category === "pdf")
            return "PDF";
        const extension = root.fileExtension(file);
        if (extension !== "")
            return extension.toUpperCase();
        const mime = String(file && file.mimeType || "");
        const slash = mime.indexOf("/");
        if (slash >= 0) {
            const subtype = mime.slice(slash + 1).split(";", 1)[0].toUpperCase();
            if (subtype !== "")
                return subtype;
        }
        return qsTr("File");
    }

    function singleFileSubtitle(file) {
        const parts = [];
        const category = String(file && file.category || "file").toLowerCase();
        parts.push(root.friendlyFileType(file));
        if (category !== "folder") {
            const size = root.humanReadableSize(file && file.byteSize);
            if (size !== "")
                parts.push(size);
        }
        const parent = root.compactParentPath(file && file.parent);
        if (parent !== "")
            parts.push(parent);
        return parts.join(" · ");
    }

    function displayTitle(entry, rawPreview) {
        const kind = String(entry.payloadKind || "binary");
        if (kind === "file" || kind === "file-list") {
            const files = Array.isArray(entry.files) ? entry.files : [];
            if (files.length > 1)
                return qsTr("%n file(s)", "clipboard file count", files.length);
            if (files.length === 1 && String(files[0].name || "") !== "")
                return String(files[0].name);
            return qsTr("File");
        }
        if (kind === "image")
            return qsTr("Clipboard image");
        if (kind === "binary")
            return qsTr("Binary clipboard content");

        const lines = root.textSummary(rawPreview);
        if (lines.length > 0)
            return lines[0].slice(0, 240);
        if (String(entry.textSubtype || "") === "html")
            return qsTr("HTML content");
        return qsTr("Empty text");
    }

    function displaySubtitle(entry, rawPreview) {
        const kind = String(entry.payloadKind || "binary");
        if (kind === "file" || kind === "file-list") {
            const files = Array.isArray(entry.files) ? entry.files : [];
            if (files.length > 1)
                return files.slice(0, 3).map(file => String(file.name || "")).filter(name => name !== "").join(
                            "、");
            if (files.length === 1)
                return root.singleFileSubtitle(files[0]);
            return qsTr("File");
        }
        if (kind === "image") {
            const mime = String(entry.mimeType || "");
            const format = mime.indexOf("/") >= 0 ? mime.split("/", 2)[1].toUpperCase() : "IMAGE";
            const details = [format];
            const width = Number(entry.width || 0);
            const height = Number(entry.height || 0);
            const byteSize = Number(entry.byteSize || 0);
            if (width > 0 && height > 0)
                details.push(width + "×" + height);
            if (byteSize > 0)
                details.push(byteSize + " B");
            return details.join(" · ");
        }
        if (kind === "binary") {
            const byteSize = Number(entry.byteSize || 0);
            return qsTr("Unknown binary content") + (byteSize > 0 ? " · " + byteSize + " B" : "");
        }

        const lines = root.textSummary(rawPreview);
        if (lines.length > 1)
            return (lines[1] + (lines.length > 2 ? "…" : "")).slice(0, 300);
        if (String(entry.textSubtype || "") === "html")
            return lines.length > 0 ? qsTr("HTML content") : qsTr("No safe text to display");
        return qsTr("Text");
    }

    function replaceModel(next) {
        let sameOrder = clipboardModel.count === next.length;
        for (let index = 0; sameOrder && index < next.length; index += 1)
            sameOrder = clipboardModel.get(index).clipboardEntryId === String(next[index].id || "");
        if (sameOrder)
            return;
        clipboardModel.clear();
        for (let index = 0; index < next.length; index += 1)
            clipboardModel.append({
                                      clipboardEntryId: String(next[index].id || "")
                                  });
    }

    function resultForEntry(entry, index, sourceLength, needle) {
        const rawPreview = String(entry.preview || "");
        const searchText = String(entry.searchText || rawPreview);
        const title = root.displayTitle(entry, rawPreview);
        const subtitle = root.displaySubtitle(entry, rawPreview);
        const fileNames = Array.isArray(entry.files) ? entry.files.map(file => String(file.name || "")).join(
                                                           " ") : "";
        const searchable = [title, subtitle, searchText, fileNames, String(entry.mimeType || "")].join("\n").toLocaleLowerCase(
                  );
        if (needle !== "" && searchable.indexOf(needle) < 0)
            return null;

        return {
            provider: "clipboard",
            id: String(entry.id || ""),
            payloadKind: String(entry.payloadKind || "binary"),
            // Old schema-v2 CLI builds may still emit "code". Text
            // content now uses one consistent plain-text presentation.
            textSubtype: String(entry.textSubtype || "") === "code" ? "plain" : String(entry.textSubtype || ""),
            title: title,
            subtitle: subtitle,
            multiline: entry.multiline === true,
            lineCount: Number(entry.lineCount || 0),
            icon: String(entry.icon || "data_object"),
            preview: rawPreview,
            previewUrl: String(entry.previewUrl || ""),
            mimeType: String(entry.mimeType || ""),
            byteSize: Number(entry.byteSize || 0),
            width: Number(entry.width || 0),
            height: Number(entry.height || 0),
            fileCount: Number(entry.fileCount || 0),
            files: Array.isArray(entry.files) ? entry.files : [],
            fileOperation: entry.fileOperation || entry.operation || "",
            restorable: entry.restorable !== false,
            score: needle === "" ? sourceLength - index : (searchable.startsWith(needle) ? 2 : 1),
            actions: ["restore", "delete"]
        };
    }

    function rebuild() {
        const needle = String(root.query || "").trim().toLocaleLowerCase();
        const source = ClipboardService.entries || [];
        const next = [];
        for (let index = 0; index < source.length; index += 1) {
            const entry = root.mergedEntry(source[index]);
            const result = root.resultForEntry(entry, index, source.length, needle);
            if (result)
                next.push(result);
        }
        root.results = next;
        root.replaceModel(next);
    }

    function updateResult(id) {
        if (String(root.query || "").trim() !== "")
            return false;
        const normalizedId = String(id || "");
        const source = ClipboardService.entries || [];
        const sourceIndex = source.findIndex(entry => String(entry.id || "") === normalizedId);
        const resultIndex = root.results.findIndex(entry => String(entry.id || "") === normalizedId);
        if (sourceIndex < 0 || resultIndex < 0)
            return false;

        const entry = root.mergedEntry(source[sourceIndex]);
        const result = root.resultForEntry(entry, sourceIndex, source.length, "");

        if (!result)
            return false;
        const next = root.results.slice();
        next[resultIndex] = result;
        root.results = next;
        return true;
    }

    function removeResult(id) {
        const normalizedId = String(id || "");
        const index = root.results.findIndex(entry => String(entry.id || "") === normalizedId);
        if (index < 0)
            return false;
        clipboardModel.remove(index);
        const next = root.results.slice();
        next.splice(index, 1);
        root.results = next;
        return true;
    }

    function clearResults() {
        clipboardModel.clear();
        root.results = [];
    }

    function refresh() {
        ClipboardService.refresh(750);
    }

    function requestDetails(id) {
        return ClipboardService.inspect(id);
    }

    function releaseDetails(id) {
        return ClipboardService.cancelInspect(id);
    }

    function inspectSearchCandidates() {
        if (String(root.query || "").trim() === "")
            return;
        const source = ClipboardService.entries || [];
        // Inspection is serialized by ClipboardService, so a query never
        // starts an unbounded number of decoder processes concurrently.
        for (let index = 0; index < source.length; index += 1)
            ClipboardService.inspect(String(source[index].id || ""));
    }

    function execute(index) {
        const result = root.results[index];
        if (!result)
            return false;
        if (!root.canRestore) {
            const failure = ClipboardService.normalizedError(null, ClipboardService.dependencies.wlCopy
                                                             ? "cliphist_unavailable" : "wl_copy_unavailable",
                                                             qsTr("Clipboard restore is unavailable"));
            root.restoreFailed(result.id, failure.code, failure.message);
            return false;
        }
        if (result.restorable === false) {
            root.restoreFailed(result.id, "clipboard_mime_unsupported", qsTr(
                                   "This format cannot be restored reliably"));
            return false;
        }
        return ClipboardService.restore(result.id);
    }

    function deleteEntry(index) {
        const result = root.results[index];
        return !!result && ClipboardService.deleteEntry(result.id);
    }

    function clear() {
        return ClipboardService.clear();
    }

    onQueryChanged: {
        root.rebuild();
        root.inspectSearchCandidates();
    }

    Connections {
        target: ClipboardService

        function onRevisionChanged() {
            root.rebuild();
            root.inspectSearchCandidates();
        }

        function onDetailsRevisionChanged() {
            if (String(root.query || "").trim() !== "")
                root.rebuild();
        }

        function onInspected(id) {
            root.updateResult(String(id));
        }

        function onRestored(id) {
            root.restored(String(id));
        }

        function onDeleted(id) {
            root.removeResult(String(id));
        }

        function onCleared() {
            root.clearResults();
        }

        function onActionFailed(action, id, code, message) {
            if (action === "restore")
                root.restoreFailed(String(id), String(code), String(message));
            else if (action === "delete")
                root.deleteFailed(String(id), String(code), String(message));
        }
    }
}
