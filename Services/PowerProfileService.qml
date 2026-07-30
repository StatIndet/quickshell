pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string internalOutput:
        Quickshell.env("CLAVIS_INTERNAL_OUTPUT") || "eDP-1"
    readonly property string powerSaverMode:
        Quickshell.env("CLAVIS_POWER_SAVER_MODE")
            || "2880x1800@60.000"
    readonly property string normalMode:
        Quickshell.env("CLAVIS_NORMAL_MODE")
            || "2880x1800@120.000"

    property string profile: "balanced"
    property bool available: false
    property bool busy: false
    property string lastError: ""

    function validProfile(value) {
        return value === "power-saver"
            || value === "balanced"
            || value === "performance";
    }

    function refresh() {
        if (!profileReader.running)
            profileReader.running = true;
    }

    function setProfile(value) {
        if (!root.validProfile(value) || root.busy)
            return;

        root.busy = true;
        root.lastError = "";
        profileWriter.command = ["powerprofilesctl", "set", value];
        profileWriter.running = true;
    }

    function applyRefreshRate() {
        if (!root.available || !root.validProfile(root.profile))
            return;

        refreshRateWriter.command = [
            "niri", "msg", "output", root.internalOutput, "mode",
            root.profile === "power-saver"
                ? root.powerSaverMode
                : root.normalMode
        ];
        refreshRateWriter.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: profileReader

        command: ["powerprofilesctl", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim();
                if (!root.validProfile(value))
                    return;

                const changed = root.profile !== value;
                root.profile = value;
                root.available = true;
                root.lastError = "";
                if (changed || !refreshRateWriter.running)
                    root.applyRefreshRate();
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.available = false;
                root.lastError = qsTr("电源模式服务不可用");
            }
        }
    }

    Process {
        id: profileWriter

        onExited: exitCode => {
            root.busy = false;
            if (exitCode === 0)
                root.refresh();
            else
                root.lastError = qsTr("切换电源模式失败");
        }
    }

    Process {
        id: refreshRateWriter

        onExited: exitCode => {
            if (exitCode !== 0)
                root.lastError = qsTr("刷新率切换失败");
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
