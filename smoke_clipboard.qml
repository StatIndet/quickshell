//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.Launcher

ShellRoot {
    id: smoke

    property bool passed: true
    property bool singleRestore:
        Quickshell.env("CLAVIS_SMOKE_SINGLE_RESTORE") === "1"
    property string phase: "load-first"
    property int phaseTicks: 0

    function verify(condition, message) {
        if (condition)
            return;
        smoke.passed = false;
        console.error("CLIPBOARD_SMOKE_ASSERT", message);
    }

    function key(key, modifiers) {
        const event = {
            key: key,
            modifiers: modifiers || Qt.NoModifier,
            accepted: false
        };
        spotlight.handleKey(event);
        return event;
    }

    LauncherWindow {
        id: spotlight
    }

    Component.onCompleted: {
        spotlight.query = String(
            Quickshell.env("CLAVIS_SMOKE_QUERY") || "");
        spotlight.openSpotlight("clipboard");
    }

    Timer {
        interval: 25
        repeat: true
        running: true

        onTriggered: {
            smoke.phaseTicks += 1;
            if (smoke.phaseTicks > 400) {
                smoke.verify(false, "clipboard smoke timed out in " + smoke.phase);
                stop();
                Qt.quit();
                return;
            }

            if (smoke.phase === "load-first") {
                if (spotlight.activeResults.length === 0)
                    return;
                smoke.verify(spotlight.clipboardCanRestore,
                             "fake clipboard can restore");
                spotlight.selectResult(0);
                smoke.key(Qt.Key_Return);
                smoke.verify(spotlight.clipboardActionState === "copying",
                             "Enter starts copying");
                smoke.phase = "wait-first-success";
            } else if (smoke.phase === "wait-first-success") {
                if (spotlight.clipboardActionState !== "copied")
                    return;
                smoke.verify(spotlight.clipboardActionEntryId
                                 === spotlight.selectedResultId,
                             "success feedback is bound to entry id");
                smoke.phase = "wait-close";
            } else if (smoke.phase === "wait-close") {
                if (spotlight.windowPhase !== "hidden")
                    return;
                if (smoke.singleRestore) {
                    console.log(smoke.passed
                        ? "CLIPBOARD_SMOKE_PASS"
                        : "CLIPBOARD_SMOKE_FAIL");
                    stop();
                    Qt.quit();
                    return;
                }
                spotlight.openSpotlight("clipboard");
                smoke.phase = "load-keep-open";
            } else if (smoke.phase === "load-keep-open") {
                if (spotlight.activeResults.length === 0
                        || spotlight.windowPhase !== "open")
                    return;
                spotlight.selectResult(0);
                smoke.key(Qt.Key_Return, Qt.ShiftModifier);
                smoke.verify(spotlight.clipboardActionState === "copying",
                             "Shift+Enter starts copying");
                smoke.verify(spotlight.clipboardActionKeepOpen,
                             "Shift+Enter carries keep-open intent");
                smoke.phase = "wait-keep-success";
            } else if (smoke.phase === "wait-keep-success") {
                if (spotlight.clipboardActionState !== "copied")
                    return;
                smoke.verify(spotlight.windowPhase === "open",
                             "keep-open success does not close Spotlight");
                smoke.phase = "wait-reset";
            } else if (smoke.phase === "wait-reset") {
                if (spotlight.clipboardActionState !== "idle")
                    return;
                smoke.verify(spotlight.windowPhase === "open",
                             "keep-open feedback resets in-place");
                // The pointer path calls this same coordinator with Ctrl=true.
                const pointerIndex = Math.min(
                    1, spotlight.activeResults.length - 1);
                spotlight.activateResult(pointerIndex, true);
                smoke.verify(spotlight.clipboardActionKeepOpen,
                             "Ctrl+click coordinator keeps Spotlight open");
                smoke.phase = "wait-pointer";
            } else if (smoke.phase === "wait-pointer") {
                if (spotlight.clipboardActionState !== "copied")
                    return;
                smoke.verify(spotlight.windowPhase === "open",
                             "pointer keep-open remains visible");
                console.log(smoke.passed
                    ? "CLIPBOARD_SMOKE_PASS"
                    : "CLIPBOARD_SMOKE_FAIL");
                stop();
                Qt.quit();
            }
        }
    }
}
