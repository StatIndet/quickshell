import QtQuick
import QtQuick.Controls
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
    color: Appearance.colors.colLayer0Base

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
            lock: root.lock
            context: root.context
            snapshotProvider: root.snapshotProvider
            screen: root.screen
        }
    }

    // Development escape hatch: deliberately bypasses authentication.
    // Keep outside the animated style so a broken animation cannot hide it.
    Button {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        z: 100
        text: "let me out"
        focusPolicy: Qt.NoFocus
        onClicked: root.context.emergencyUnlock()
    }
}
