pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string stateRoot: {
        const xdgStateHome = Quickshell.env("XDG_STATE_HOME");
        return xdgStateHome && xdgStateHome.length > 0
            ? xdgStateHome
            : Paths.homeDir + "/.local/state";
    }
    readonly property string stateDir: stateRoot + "/quickshell"
    readonly property string filePath: stateDir + "/clavis-info-drawer.json"

    property bool storeReady: false
    property bool ready: false
    property bool pendingSave: false

    property bool collapsed: false
    property int selectedTab: 0

    property bool pomodoroRunning: false
    property bool pomodoroBreak: false
    property int pomodoroCycle: 0
    property real pomodoroStart: 0
    property int pomodoroSecondsLeft: 1500

    property bool stopwatchRunning: false
    property real stopwatchStart: 0
    property int stopwatchElapsed: 0
    property var stopwatchLaps: []

    function clampTab(value) {
        const numberValue = Number(value);
        return Number.isFinite(numberValue)
            ? Math.max(0, Math.min(2, Math.floor(numberValue)))
            : 0;
    }

    function normalizedLaps(value) {
        if (!Array.isArray(value))
            return [];

        return value
            .map(lap => Math.max(0, Math.floor(Number(lap) || 0)))
            .filter(lap => Number.isFinite(lap));
    }

    function setCollapsed(value) {
        if (root.collapsed === value)
            return;

        root.collapsed = value;
        root.scheduleSave();
    }

    function setSelectedTab(value) {
        const normalized = root.clampTab(value);
        if (root.selectedTab === normalized)
            return;

        root.selectedTab = normalized;
        root.scheduleSave();
    }

    function scheduleSave() {
        root.pendingSave = true;
        if (!root.ready || !root.storeReady)
            return;
        saveTimer.restart();
    }

    function flushSave() {
        root.pendingSave = true;
        if (!root.ready || !root.storeReady)
            return;

        saveTimer.stop();
        root.save();
    }

    function save() {
        if (!root.storeReady || !root.ready)
            return;

        stateFile.setText(JSON.stringify({
            "drawer": {
                "collapsed": root.collapsed,
                "selectedTab": root.selectedTab
            },
            "pomodoro": {
                "running": root.pomodoroRunning,
                "isBreak": root.pomodoroBreak,
                "cycle": root.pomodoroCycle,
                "start": root.pomodoroStart,
                "secondsLeft": root.pomodoroSecondsLeft
            },
            "stopwatch": {
                "running": root.stopwatchRunning,
                "start": root.stopwatchStart,
                "elapsed": root.stopwatchElapsed,
                "laps": root.stopwatchLaps
            }
        }, null, 2));
        root.pendingSave = false;
    }

    function loadState(text) {
        const parsed = JSON.parse(text && text.trim().length > 0 ? text : "{}");
        const drawer = parsed.drawer || {};
        const pomodoro = parsed.pomodoro || {};
        const stopwatch = parsed.stopwatch || {};

        root.collapsed = typeof drawer.collapsed === "boolean" ? drawer.collapsed : false;
        root.selectedTab = root.clampTab(drawer.selectedTab);

        root.pomodoroRunning = pomodoro.running === true;
        root.pomodoroBreak = pomodoro.isBreak === true;
        const loadedPomodoroCycle = Number(pomodoro.cycle);
        const loadedPomodoroStart = Number(pomodoro.start);
        const loadedPomodoroSecondsLeft = Number(pomodoro.secondsLeft);
        root.pomodoroCycle = Number.isFinite(loadedPomodoroCycle)
            ? Math.max(0, Math.floor(loadedPomodoroCycle)) % 4
            : 0;
        root.pomodoroStart = Number.isFinite(loadedPomodoroStart)
            ? Math.max(0, Math.floor(loadedPomodoroStart))
            : 0;
        root.pomodoroSecondsLeft = Number.isFinite(loadedPomodoroSecondsLeft)
            ? Math.max(0, Math.floor(loadedPomodoroSecondsLeft))
            : 1500;

        const loadedStopwatchStart = Number(stopwatch.start);
        const loadedStopwatchElapsed = Number(stopwatch.elapsed);
        const validStopwatchStart = Number.isFinite(loadedStopwatchStart) && loadedStopwatchStart > 0;
        root.stopwatchRunning = stopwatch.running === true && validStopwatchStart;
        root.stopwatchStart = validStopwatchStart ? Math.floor(loadedStopwatchStart) : 0;
        root.stopwatchElapsed = Number.isFinite(loadedStopwatchElapsed)
            ? Math.max(0, Math.floor(loadedStopwatchElapsed))
            : 0;
        root.stopwatchLaps = root.normalizedLaps(stopwatch.laps);
    }

    Process {
        id: ensureStateDir

        command: ["mkdir", "-p", root.stateDir]
        running: true

        onExited: {
            root.storeReady = true;
            stateFile.reload();
        }
    }

    FileView {
        id: stateFile

        path: root.filePath
        blockLoading: true
        blockWrites: true
        atomicWrites: true

        onLoaded: {
            try {
                root.loadState(stateFile.text());
            } catch (error) {
                console.log("InfoDrawerState failed to load:", error);
            }

            root.ready = true;
            root.scheduleSave();
        }

        onLoadFailed: error => {
            if (!root.storeReady)
                return;

            if (error !== FileViewError.FileNotFound)
                console.log("InfoDrawerState failed to open:", error);

            root.ready = true;
            root.scheduleSave();
        }
    }

    Timer {
        id: saveTimer

        interval: 100
        repeat: false
        onTriggered: root.save()
    }
}
