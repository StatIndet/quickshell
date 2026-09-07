import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    property var context: null
    property var snapshotProvider: null
    // Freeze the selection for this lock session.
    property string style: "default"
    color: root.style === "caelestia" ? Appearance.colors.colLayer0Base : "#15191D"

    Loader {
        anchors.fill: parent
        sourceComponent: root.style === "caelestia" ? caelestia : defaultStyle
    }

    Component {
        id: caelestia
        CaelestiaLock {
            lock: root.lock
            context: root.context
            snapshotProvider: root.snapshotProvider
            screen: root.screen
        }
    }

    Component {
        id: defaultStyle
        DefaultLock {
            snapshotProvider: root.snapshotProvider
            lock: root.lock
            context: root.context
            screen: root.screen
        }
    }
}
