pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool visible: false
    property var targetScreen: null

    function open(screen) {
        if (!root.visible)
            root.targetScreen = screen || Quickshell.screens[0] || null;
        root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    function toggle() {
        if (root.visible)
            root.close();
        else
            root.open();
    }
}
