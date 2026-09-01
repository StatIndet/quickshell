pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property var entries: []

    function registerPopup(window, item) {
        if (!window || !item)
            return ;

        const next = root.entries.filter((entry) => {
            return entry.window !== window;
        });
        next.push({
            "window": window,
            "item": item
        });
        root.entries = next;
    }

    function unregisterPopup(window, item) {
        root.entries = root.entries.filter((entry) => {
            return entry.window !== window || entry.item !== item;
        });
    }

    function itemForWindow(window) {
        for (let index = 0; index < root.entries.length; index += 1) {
            if (root.entries[index].window === window)
                return root.entries[index].item;

        }
        return null;
    }

}
