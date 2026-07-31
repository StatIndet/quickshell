import QtQuick
import qs.Services

Item {
    id: root

    property string query: ""
    property var results: []
    readonly property bool loading: ClipboardService.loading
    readonly property bool available: ClipboardService.canList
        && (ClipboardService.watcherRunning
            || ClipboardService.entries.length > 0)
    readonly property bool canRestore: ClipboardService.canRestore
    readonly property bool actionRunning: ClipboardService.actionRunning
    readonly property var error: ClipboardService.error

    signal restored(string id)
    signal restoreFailed(string id, string code, string message)

    function mergedEntry(entry) {
        const id = String(entry.id || "");
        return ClipboardService.detail(id) || entry;
    }

    function rebuild() {
        // Establish a dependency on the details revision even though detail()
        // reads from a JS object by key.
        const ignoredRevision = ClipboardService.detailsRevision;
        const needle = String(root.query || "").trim().toLocaleLowerCase();
        const source = ClipboardService.entries || [];
        const next = [];
        for (let index = 0; index < source.length; index += 1) {
            const entry = root.mergedEntry(source[index]);
            const rawPreview = String(entry.preview || "");
            const searchText = String(entry.searchText || rawPreview);
            const title = String(entry.title || rawPreview
                                 || qsTr("空内容"));
            const subtitle = String(entry.subtitle || "");
            const fileNames = Array.isArray(entry.files)
                ? entry.files.map(file => String(file.name || "")).join(" ")
                : "";
            const searchable = [
                title, subtitle, searchText, fileNames,
                String(entry.mimeType || "")
            ].join("\n").toLocaleLowerCase();
            if (needle !== "" && searchable.indexOf(needle) < 0)
                continue;

            next.push({
                provider: "clipboard",
                id: String(entry.id || ""),
                payloadKind: String(entry.payloadKind || "binary"),
                textSubtype: entry.textSubtype === null
                    || entry.textSubtype === undefined
                    ? "" : String(entry.textSubtype),
                title: title,
                subtitle: subtitle,
                icon: String(entry.icon || "data_object"),
                preview: rawPreview,
                previewUrl: String(entry.previewUrl || ""),
                mimeType: String(entry.mimeType || ""),
                byteSize: Number(entry.byteSize || 0),
                width: Number(entry.width || 0),
                height: Number(entry.height || 0),
                fileCount: Number(entry.fileCount || 0),
                files: Array.isArray(entry.files) ? entry.files : [],
                fileOperation: entry.fileOperation || "",
                restorable: entry.restorable !== false,
                score: needle === "" ? source.length - index
                    : (searchable.startsWith(needle) ? 2 : 1),
                actions: ["restore", "delete"]
            });
        }
        root.results = next;
    }

    function refresh() {
        ClipboardService.refresh(100);
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
            const failure = ClipboardService.normalizedError(
                null,
                ClipboardService.dependencies.wlCopy
                    ? "cliphist_unavailable" : "wl_copy_unavailable",
                qsTr("剪贴板恢复不可用"));
            root.restoreFailed(result.id, failure.code, failure.message);
            return false;
        }
        if (result.restorable === false) {
            root.restoreFailed(
                result.id, "clipboard_mime_unsupported",
                qsTr("该格式无法可靠恢复"));
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
            root.rebuild();
        }

        function onRestored(id) {
            root.restored(String(id));
        }

        function onActionFailed(action, id, code, message) {
            if (action === "restore")
                root.restoreFailed(String(id), String(code), String(message));
        }
    }
}
