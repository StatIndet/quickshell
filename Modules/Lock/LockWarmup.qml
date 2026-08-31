import QtQuick
import Quickshell
import Quickshell.Wayland

Loader {
    asynchronous: true
    active: Quickshell.screens.length > 0
    onLoaded: active = false

    // Initialize screencopy before session lock; LockSurface captures the real background.
    sourceComponent: ScreencopyView {
        captureSource: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

}
