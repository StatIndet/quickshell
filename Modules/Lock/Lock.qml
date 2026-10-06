import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Common
import qs.Services

Scope {
    id: root

    readonly property bool active: sessionLocked || capturePending
    readonly property bool secure: sessionLock.secure
    property bool sessionLocked: false
    property bool capturePending: false
    property int activeCaptureRequestId: 0
    property string sessionStyle: "default"

    Binding {
        target: WindowPreviewService
        property: "suspended"
        value: root.active
    }

    signal unlocked
    signal secured

    function syncSessionLock() {
        // Quickshell 0.3.1 can omit lockStateChanged after unlocking. Sample
        // the native state after our operations, not only its notifications.
        sessionLocked = sessionLock.locked;
    }
    Component.onCompleted: Qt.callLater(root.syncSessionLock)

    function open() {
        if (sessionLock.locked || capturePending)
            return "ALREADY_LOCKED";

        sessionStyle = PersonalizationConfig.lockScreenStyle;
        internalContext.authRevealed = false;
        internalContext.currentText = "";
        internalContext.unlockInProgress = false;
        internalContext.showFailure = false;
        capturePending = true;
        activeCaptureRequestId = preLockCapture.capture();
        return "LOCKED";
    }

    function isLocked() {
        return sessionLock.locked || capturePending;
    }

    function finishCapture(captureRequestId) {
        if (!capturePending || captureRequestId !== activeCaptureRequestId)
            return;

        sessionLock.locked = true;
        root.syncSessionLock();
        capturePending = false;
    }

    onActiveChanged: {
        SystemIdentityService.setUptimeConsumer("lock-screen", root.active);
        SystemMonitorService.setConsumerModules("lock-screen", root.active ? ["cpu", "memory", "disk"] : []);
    }
    Component.onDestruction: {
        preLockCapture.cancel();
        preLockCapture.clear();
        SystemIdentityService.setUptimeConsumer("lock-screen", false);
        SystemMonitorService.clearConsumer("lock-screen");
    }

    PreLockCapture {
        id: preLockCapture

        onCompleted: captureRequestId => {
            return root.finishCapture(captureRequestId);
        }
    }

    Scope {
        id: internalContext

        property bool authRevealed: false
        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false

        signal unlockFailed

        function tryUnlock() {
            if (currentText === "" || unlockInProgress)
                return;

            internalContext.unlockInProgress = true;
            pam.start();
        }

        function finishUnlock() {
            if (!sessionLock.locked)
                return;
            sessionLock.locked = false;
            root.syncSessionLock();
            root.unlocked();
            Qt.callLater(preLockCapture.clear);
        }

        PamContext {
            id: pam

            configDirectory: Paths.shellDir + "/Modules/Lock/pam"
            config: "password.conf"
            onPamMessage: {
                if (this.responseRequired)
                    this.respond(internalContext.currentText);
            }
            onCompleted: result => {
                if (result == PamResult.Success) {
                    internalContext.currentText = "";
                    internalContext.showFailure = false;
                    sessionLock.unlock();
                } else {
                    internalContext.currentText = "";
                    internalContext.showFailure = true;
                    internalContext.unlockFailed();
                }
                internalContext.unlockInProgress = false;
            }
        }
    }

    WlSessionLock {
        id: sessionLock

        signal unlock

        onLockStateChanged: root.syncSessionLock()
        onSecureStateChanged: {
            // The secure notification may arrive before the native manager
            // clears its lock object. Re-read after that call has returned.
            Qt.callLater(root.syncSessionLock);
            if (secure)
                root.secured();
        }

        LockSurface {
            lock: sessionLock
            context: internalContext
            snapshotProvider: preLockCapture
            style: root.sessionStyle
        }
    }
}
