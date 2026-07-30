import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property string query: ""
    property var results: []

    function rebuild() {
        const needle = String(root.query || "").trim().toLocaleLowerCase();
        const current = WallpaperService.currentWallpaper
            || WallpaperService.wallpaperForScreen("");
        const source = WallpaperService.wallpapers || [];
        const next = [];
        for (let index = 0; index < source.length; index += 1) {
            const path = String(source[index] || "");
            if (path === "")
                continue;
            const title = WallpaperService.basename(path);
            if (needle !== ""
                    && title.toLocaleLowerCase().indexOf(needle) < 0)
                continue;
            next.push({
                provider: "wallpapers",
                id: path,
                title: title,
                subtitle: WallpaperService.parentFolder(path),
                icon: "",
                preview: Paths.fileUrl(path),
                score: needle === "" ? 0
                    : (title.toLocaleLowerCase().startsWith(needle) ? 2 : 1),
                actions: ["apply"],
                current: path === current,
                path: path
            });
        }
        next.sort((left, right) => {
            if (right.score !== left.score)
                return right.score - left.score;
            return left.title.localeCompare(right.title);
        });
        root.results = next;
    }

    function execute(index) {
        const result = root.results[index];
        if (!result || WallpaperService.busy)
            return false;
        return WallpaperService.setWallpaper(result.path);
    }

    onQueryChanged: rebuild()
    Component.onCompleted: {
        if (WallpaperService.wallpapers.length === 0
                && !WallpaperService.scanning)
            WallpaperService.scan();
        rebuild();
    }

    Connections {
        target: WallpaperService

        function onWallpapersChanged() {
            root.rebuild();
        }

        function onCurrentWallpaperChanged() {
            root.rebuild();
        }

        function onRevisionChanged() {
            root.rebuild();
        }
    }
}
