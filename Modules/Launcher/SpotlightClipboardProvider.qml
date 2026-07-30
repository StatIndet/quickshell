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
    readonly property var error: ClipboardService.error

    signal restored()

    function rebuild() {
        const needle = String(root.query || "").trim().toLocaleLowerCase();
        const source = ClipboardService.entries || [];
        const next = [];
        for (let index = 0; index < source.length; index += 1) {
            const entry = source[index];
            const type = String(entry.type || "text");
            const rawPreview = String(entry.preview || "");
            const searchable = rawPreview.toLocaleLowerCase();
            if (needle !== "" && searchable.indexOf(needle) < 0)
                continue;

            let title = rawPreview;
            let subtitle = qsTr("文本");
            let icon = "content_paste";
            if (type === "image") {
                title = qsTr("图片剪贴板");
                subtitle = qsTr("%1 · %2×%3")
                    .arg(String(entry.format || "").toUpperCase())
                    .arg(entry.width || 0)
                    .arg(entry.height || 0);
                icon = "image";
            } else if (type === "binary") {
                title = qsTr("二进制剪贴板");
                subtitle = qsTr("可恢复的二进制内容");
                icon = "data_object";
            }

            next.push({
                provider: "clipboard",
                id: String(entry.id || ""),
                title: title || qsTr("空文本"),
                subtitle: subtitle,
                icon: icon,
                preview: rawPreview,
                score: needle === "" ? source.length - index
                    : (searchable.startsWith(needle) ? 2 : 1),
                actions: ["restore", "delete"],
                type: type
            });
        }
        root.results = next;
    }

    function refresh() {
        ClipboardService.refresh(100);
    }

    function execute(index) {
        const result = root.results[index];
        return !!result && root.canRestore
            && ClipboardService.restore(result.id);
    }

    function deleteEntry(index) {
        const result = root.results[index];
        return !!result && ClipboardService.deleteEntry(result.id);
    }

    function clear() {
        return ClipboardService.clear();
    }

    onQueryChanged: rebuild()

    Connections {
        target: ClipboardService

        function onRevisionChanged() {
            root.rebuild();
        }

        function onRestored() {
            root.restored();
        }
    }
}
