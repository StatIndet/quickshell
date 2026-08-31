import QtQuick
import Quickshell
import Quickshell.Wayland

Loader {
    id: root

    property bool warmed: false

    function finishWarmup() {
        if (warmed || !item || !item.hasContent)
            return ;

        warmed = true;
        active = false;
    }

    asynchronous: true
    active: Quickshell.screens.length > 0
    onLoaded: finishWarmup()

    Connections {
        function onHasContentChanged() {
            root.finishWarmup();
        }

        function onStopped() {
            if (!root.warmed) {
                console.warn("Lock screencopy warmup stopped before producing a frame");
                root.active = false;
            }
        }

        target: root.item
        ignoreUnknownSignals: true
    }

    // Initialize screencopy before session lock; PreLockCapture obtains the lock frame.
    sourceComponent: ScreencopyView {
        captureSource: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

}
