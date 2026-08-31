import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Common
import qs.Services

Scope {
    id: root

    readonly property bool active: sessionLock.locked || capturePending
    readonly property bool secure: sessionLock.secure
    property bool capturePending: false
    property int activeCaptureRequestId: 0

    signal unlocked()
    signal secured()

    function open() {
        if (sessionLock.locked || capturePending)
            return "ALREADY_LOCKED";

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
            return ;

        sessionLock.locked = true;
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

        onCompleted: (captureRequestId) => {
            return root.finishCapture(captureRequestId);
        }
    }

    Scope {
        id: internalContext

        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false

        signal unlockFailed()

        function tryUnlock() {
            if (currentText === "" || unlockInProgress)
                return ;

            internalContext.unlockInProgress = true;
            pam.start();
        }

        function finishUnlock() {
            sessionLock.locked = false;
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
            onCompleted: (result) => {
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

        signal unlock()

        onSecureStateChanged: {
            if (secure)
                root.secured();

        }

        LockSurface {
            lock: sessionLock
            context: internalContext
            snapshotProvider: preLockCapture
        }

    }

}
