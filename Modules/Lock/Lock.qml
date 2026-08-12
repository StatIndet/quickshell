import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Common
import qs.Services

Scope {
    id: root

    signal unlocked()

    property bool lockPending: false
    property int lockGeneration: 0

    function open() {
        if (sessionLock.locked || lockPending)
            return "ALREADY_LOCKED";

        internalContext.currentText = "";
        internalContext.unlockInProgress = false;
        internalContext.showFailure = false;
        lockPending = true;
        lockGeneration = LockSnapshot.request(Quickshell.screens.length);
        lockSnapshotTimeout.restart();

        if (LockSnapshot.ready)
            commitLock(lockGeneration);

        return "LOCKED";
    }

    function isLocked() {
        return sessionLock.secure;
    }

    function commitLock(snapshotGeneration) {
        if (!lockPending || snapshotGeneration !== lockGeneration)
            return;

        lockPending = false;
        lockSnapshotTimeout.stop();
        sessionLock.locked = true;
    }

    Connections {
        target: LockSnapshot

        function onPrepared(snapshotGeneration) {
            root.commitLock(snapshotGeneration);
        }
    }

    Timer {
        id: lockSnapshotTimeout
        interval: 180
        repeat: false
        onTriggered: root.commitLock(root.lockGeneration)
    }

    Scope {
        id: internalContext

        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false

        signal unlockFailed()

        function tryUnlock() {
            if (currentText === "" || unlockInProgress)
                return;

            internalContext.unlockInProgress = true;
            pam.start();
        }

        function finishUnlock() {
            sessionLock.locked = false;
            root.unlocked();
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

        signal unlock()

        LockSurface {
            lock: sessionLock
            context: internalContext
        }
    }
}
