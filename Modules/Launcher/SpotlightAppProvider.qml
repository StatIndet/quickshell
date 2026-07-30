import QtQuick
import Quickshell

Item {
    id: root

    property string query: ""
    property var results: []
    property int limit: 50

    function normalized(value) {
        return String(value || "").trim().toLocaleLowerCase();
    }

    function isWordStart(text, query) {
        if (text.startsWith(query))
            return true;
        for (let index = 1; index < text.length; index += 1) {
            const previous = text.charAt(index - 1);
            if ((previous === " " || previous === "-" || previous === "_"
                    || previous === "." || previous === "/")
                    && text.indexOf(query, index) === index)
                return true;
        }
        return false;
    }

    function subsequencePenalty(text, query) {
        let queryIndex = 0;
        let firstIndex = -1;
        let lastIndex = -1;
        for (let index = 0; index < text.length && queryIndex < query.length;
                index += 1) {
            if (text.charAt(index) !== query.charAt(queryIndex))
                continue;
            if (firstIndex < 0)
                firstIndex = index;
            lastIndex = index;
            queryIndex += 1;
        }
        if (queryIndex !== query.length)
            return -1;
        return Math.max(0, lastIndex - firstIndex - query.length + 1);
    }

    function fieldScore(value, needle, weight) {
        const text = normalized(value);
        if (text === "" || needle === "")
            return needle === "" ? weight : -1;
        if (text === needle)
            return 5000 + weight;
        if (text.startsWith(needle))
            return 4000 + weight - Math.min(99, text.length - needle.length);
        if (isWordStart(text, needle))
            return 3000 + weight;
        const substringIndex = text.indexOf(needle);
        if (substringIndex >= 0)
            return 2000 + weight - Math.min(99, substringIndex);
        const penalty = subsequencePenalty(text, needle);
        return penalty >= 0 ? 1000 + weight - Math.min(99, penalty) : -1;
    }

    function appScore(app, needle) {
        if (needle === "")
            return 0;
        let best = -1;
        best = Math.max(best, fieldScore(app.name, needle, 80));
        best = Math.max(best, fieldScore(app.genericName, needle, 60));
        best = Math.max(
            best,
            fieldScore(Array.from(app.keywords || []).join(" "), needle, 40)
        );
        best = Math.max(best, fieldScore(app.id, needle, 20));
        return best;
    }

    function rebuild() {
        const needle = normalized(root.query);
        const source = DesktopEntries.applications.values || [];
        const next = [];
        for (let index = 0; index < source.length; index += 1) {
            const app = source[index];
            if (!app || app.noDisplay)
                continue;
            const score = appScore(app, needle);
            if (score < 0)
                continue;
            next.push({
                provider: "apps",
                id: String(app.id || app.name || index),
                title: String(app.name || app.id || ""),
                subtitle: String(app.genericName || app.comment || app.id || ""),
                icon: String(app.icon || ""),
                preview: "",
                score: score,
                actions: ["launch"],
                appObject: app
            });
        }
        next.sort((left, right) => {
            if (right.score !== left.score)
                return right.score - left.score;
            const byName = left.title.localeCompare(right.title);
            return byName !== 0 ? byName : left.id.localeCompare(right.id);
        });
        root.results = next.slice(0, root.limit);
    }

    function execute(index) {
        const result = root.results[index];
        if (!result || !result.appObject)
            return false;
        result.appObject.execute();
        return true;
    }

    onQueryChanged: rebuild()
    Component.onCompleted: rebuild()

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.rebuild();
        }
    }
}
