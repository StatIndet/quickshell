//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.Launcher

ShellRoot {
    id: smoke

    property bool passed: true
    property int ticks: 0
    property string expectedId: ""

    function verify(condition, message) {
        if (condition)
            return;
        smoke.passed = false;
        console.error("CLIPBOARD_FAILURE_SMOKE_ASSERT", message);
    }

    LauncherWindow {
        id: spotlight
    }

    Component.onCompleted: spotlight.openSpotlight("clipboard")

    Timer {
        interval: 25
        repeat: true
        running: true

        onTriggered: {
            smoke.ticks += 1;
            if (smoke.ticks > 200) {
                smoke.verify(false, "clipboard failure smoke timed out");
                stop();
                Qt.quit();
                return;
            }
            if (smoke.expectedId === "") {
                if (spotlight.activeResults.length === 0)
                    return;
                spotlight.selectResult(0);
                smoke.expectedId = spotlight.selectedResultId;
                spotlight.activateSelected(false);
                return;
            }
            if (spotlight.clipboardActionState !== "error")
                return;
            smoke.verify(spotlight.windowPhase !== "closing"
                             && spotlight.windowPhase !== "hidden",
                         "restore failure keeps Spotlight visible");
            smoke.verify(spotlight.selectedResultId === smoke.expectedId,
                         "restore failure preserves selection");
            smoke.verify(spotlight.clipboardActionEntryId === smoke.expectedId,
                         "restore failure is bound to entry id");
            smoke.verify(spotlight.clipboardActionError !== "",
                         "restore failure exposes a message");
            console.log(smoke.passed
                ? "CLIPBOARD_FAILURE_SMOKE_PASS"
                : "CLIPBOARD_FAILURE_SMOKE_FAIL");
            stop();
            Qt.quit();
        }
    }
}
