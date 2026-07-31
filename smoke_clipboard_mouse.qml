//@ pragma UseQApplication

import QtQuick
import QtTest
import Quickshell
import qs.Modules.Launcher

ShellRoot {
    id: smoke

    property bool passed: true
    property int ticks: 0
    property string phase: "load"

    function verify(condition, message) {
        if (condition)
            return;
        smoke.passed = false;
        console.error("CLIPBOARD_MOUSE_SMOKE_ASSERT", message);
    }

    LauncherWindow {
        id: spotlight
    }

    TestCase {
        id: pointer
        name: "SpotlightClipboardPointer"
        when: false
    }

    Component.onCompleted: spotlight.openSpotlight("clipboard")

    Timer {
        interval: 25
        repeat: true
        running: true

        onTriggered: {
            smoke.ticks += 1;
            if (smoke.ticks > 240) {
                smoke.verify(false, "clipboard mouse smoke timed out");
                stop();
                Qt.quit();
                return;
            }
            if (smoke.phase === "load") {
                if (spotlight.activeResults.length === 0)
                    return;
                const area = spotlight.clipboardActivationAreaAt(0);
                if (!area)
                    return;
                pointer.mouseClick(
                    area, area.width / 2, area.height / 2,
                    Qt.LeftButton, Qt.NoModifier);
                smoke.verify(
                    spotlight.clipboardActionState === "copying",
                    "left click reaches the clipboard delegate");
                smoke.phase = "success";
            } else if (smoke.phase === "success") {
                if (spotlight.clipboardActionState !== "copied")
                    return;
                smoke.verify(
                    spotlight.clipboardActionEntryId
                        === spotlight.selectedResultId,
                    "pointer success is bound to the selected id");
                smoke.phase = "wait-close";
            } else if (smoke.phase === "wait-close") {
                if (spotlight.windowPhase !== "hidden")
                    return;
                spotlight.openSpotlight("clipboard");
                smoke.phase = "load-control";
            } else if (smoke.phase === "load-control") {
                if (spotlight.windowPhase !== "open"
                        || spotlight.activeResults.length === 0)
                    return;
                const target = Math.min(
                    1, spotlight.activeResults.length - 1);
                const area = spotlight.clipboardActivationAreaAt(target);
                if (!area)
                    return;
                pointer.mouseClick(
                    area, area.width / 2, area.height / 2,
                    Qt.LeftButton, Qt.ControlModifier);
                smoke.verify(
                    spotlight.clipboardActionState === "copying"
                        && spotlight.clipboardActionKeepOpen,
                    "Ctrl+left click carries keep-open intent");
                smoke.phase = "control-success";
            } else if (smoke.phase === "control-success") {
                if (spotlight.clipboardActionState !== "copied")
                    return;
                smoke.verify(
                    spotlight.windowPhase === "open",
                    "Ctrl+left click keeps Spotlight open");
                console.log(smoke.passed
                    ? "CLIPBOARD_MOUSE_SMOKE_PASS"
                    : "CLIPBOARD_MOUSE_SMOKE_FAIL");
                stop();
                Qt.quit();
            }
        }
    }
}
