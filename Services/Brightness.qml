pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real brightnessValue: 0.5

    function setBrightness(val, allowZero) {
        let safeVal = Math.max(allowZero ? 0.0 : 0.01, Math.min(1.0, val));
        let pct = Math.round(safeVal * 100);
        Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
        root.brightnessValue = safeVal;
        debounceTimer.start();
    }

    Process {
        id: brightnessPoller
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}'"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let data = line.trim();
                if (data === "") return;
                let b = parseInt(data);
                if (!isNaN(b)) root.brightnessValue = b / 100.0;
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: brightnessPoller.running = true
    }

    Timer {
        id: debounceTimer
        interval: 300
        running: false
        repeat: false
        onTriggered: brightnessPoller.running = true
    }
}
