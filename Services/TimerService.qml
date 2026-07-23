pragma Singleton

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    readonly property int focusTime: 25 * 60
    readonly property int breakTime: 5 * 60
    readonly property int longBreakTime: 15 * 60
    readonly property int cyclesBeforeLongBreak: 4
    readonly property int pomodoroSequenceDuration: focusTime * cyclesBeforeLongBreak
        + breakTime * (cyclesBeforeLongBreak - 1)
        + longBreakTime

    readonly property bool pomodoroRunning: InfoDrawerState.pomodoroRunning
    readonly property bool pomodoroBreak: InfoDrawerState.pomodoroBreak
    readonly property int pomodoroCycle: InfoDrawerState.pomodoroCycle
    readonly property bool pomodoroLongBreak: pomodoroBreak
        && pomodoroCycle + 1 === cyclesBeforeLongBreak
    readonly property int pomodoroLapDuration: pomodoroLongBreak
        ? longBreakTime
        : pomodoroBreak
            ? breakTime
            : focusTime
    property int pomodoroSecondsLeft: focusTime

    readonly property bool stopwatchRunning: InfoDrawerState.stopwatchRunning
    property int stopwatchTime: 0
    readonly property var stopwatchLaps: InfoDrawerState.stopwatchLaps

    function currentSeconds() {
        return Math.floor(Date.now() / 1000);
    }

    function currentCentiseconds() {
        return Math.floor(Date.now() / 10);
    }

    function normalizedPomodoroCycle(value) {
        const numberValue = Number(value);
        if (!Number.isFinite(numberValue))
            return 0;
        return Math.max(0, Math.floor(numberValue)) % root.cyclesBeforeLongBreak;
    }

    function pomodoroDurationFor(isBreak, cycle) {
        if (!isBreak)
            return root.focusTime;
        return root.normalizedPomodoroCycle(cycle) + 1 === root.cyclesBeforeLongBreak
            ? root.longBreakTime
            : root.breakTime;
    }

    function syncFromStore() {
        if (!InfoDrawerState.ready)
            return;

        const normalizedCycle = root.normalizedPomodoroCycle(InfoDrawerState.pomodoroCycle);
        const cycleCorrected = normalizedCycle !== InfoDrawerState.pomodoroCycle;
        const storedSecondsLeft = Number(InfoDrawerState.pomodoroSecondsLeft);
        InfoDrawerState.pomodoroCycle = normalizedCycle;
        root.pomodoroSecondsLeft = Math.max(
            0,
            Math.min(
                root.pomodoroLapDuration,
                Number.isFinite(storedSecondsLeft)
                    ? storedSecondsLeft
                    : root.pomodoroLapDuration
            )
        );

        if (root.pomodoroRunning)
            root.refreshPomodoro();
        else if (cycleCorrected || root.pomodoroSecondsLeft !== storedSecondsLeft)
            root.persistPomodoro();

        root.stopwatchTime = Math.max(0, InfoDrawerState.stopwatchElapsed);
        if (root.stopwatchRunning)
            root.refreshStopwatch();
    }

    function persistPomodoro() {
        InfoDrawerState.pomodoroSecondsLeft = root.pomodoroSecondsLeft;
        InfoDrawerState.flushSave();
    }

    function playSystemSound(soundName) {
        const soundRoot = "/usr/share/sounds/freedesktop/stereo/";
        Quickshell.execDetached([
            "ffplay",
            "-nodisp",
            "-autoexit",
            soundRoot + soundName + ".oga"
        ]);
        Quickshell.execDetached([
            "ffplay",
            "-nodisp",
            "-autoexit",
            soundRoot + soundName + ".ogg"
        ]);
    }

    function notifyPomodoroStage() {
        let message = "";
        if (root.pomodoroLongBreak)
            message = `🌿 Long break: ${Math.floor(root.longBreakTime / 60)} minutes`;
        else if (root.pomodoroBreak)
            message = `☕ Break: ${Math.floor(root.breakTime / 60)} minutes`;
        else
            message = `🔴 Focus: ${Math.floor(root.focusTime / 60)} minutes`;

        Quickshell.execDetached(["notify-send", "Pomodoro", message, "-a", "Clavis"]);
        if (PersonalizationConfig.pomodoroSoundEnabled)
            root.playSystemSound("alarm-clock-elapsed");
    }

    function refreshPomodoro() {
        if (!root.pomodoroRunning)
            return;

        const now = root.currentSeconds();
        let phaseStart = Number(InfoDrawerState.pomodoroStart);
        let isBreak = InfoDrawerState.pomodoroBreak;
        let cycle = root.normalizedPomodoroCycle(InfoDrawerState.pomodoroCycle);
        let stateCorrected = cycle !== InfoDrawerState.pomodoroCycle;
        let transitioned = false;

        if (!Number.isFinite(phaseStart) || phaseStart <= 0 || phaseStart > now) {
            phaseStart = now;
            stateCorrected = true;
        }

        let duration = root.pomodoroDurationFor(isBreak, cycle);
        while (now >= phaseStart + duration) {
            phaseStart += duration;
            if (isBreak)
                cycle = (cycle + 1) % root.cyclesBeforeLongBreak;
            isBreak = !isBreak;
            transitioned = true;
            duration = root.pomodoroDurationFor(isBreak, cycle);

            if (!isBreak && cycle === 0) {
                const fullSequences = Math.floor((now - phaseStart) / root.pomodoroSequenceDuration);
                if (fullSequences > 0)
                    phaseStart += fullSequences * root.pomodoroSequenceDuration;
            }
        }

        InfoDrawerState.pomodoroBreak = isBreak;
        InfoDrawerState.pomodoroCycle = cycle;
        InfoDrawerState.pomodoroStart = phaseStart;
        root.pomodoroSecondsLeft = Math.max(0, duration - (now - phaseStart));

        if (transitioned || stateCorrected)
            root.persistPomodoro();
        if (transitioned)
            root.notifyPomodoroStage();
    }

    function togglePomodoro() {
        if (root.pomodoroRunning) {
            root.refreshPomodoro();
            InfoDrawerState.pomodoroRunning = false;
            root.persistPomodoro();
            return;
        }

        const remaining = Math.max(0, Math.min(root.pomodoroLapDuration, root.pomodoroSecondsLeft));
        InfoDrawerState.pomodoroStart = root.currentSeconds() - (root.pomodoroLapDuration - remaining);
        InfoDrawerState.pomodoroRunning = true;
        root.persistPomodoro();
    }

    function resetPomodoro() {
        InfoDrawerState.pomodoroRunning = false;
        InfoDrawerState.pomodoroBreak = false;
        InfoDrawerState.pomodoroCycle = 0;
        InfoDrawerState.pomodoroStart = root.currentSeconds();
        root.pomodoroSecondsLeft = root.focusTime;
        root.persistPomodoro();
    }

    function refreshStopwatch() {
        if (!root.stopwatchRunning)
            return;

        if (InfoDrawerState.stopwatchStart <= 0)
            InfoDrawerState.stopwatchStart = root.currentCentiseconds() - InfoDrawerState.stopwatchElapsed;

        root.stopwatchTime = Math.max(0, root.currentCentiseconds() - InfoDrawerState.stopwatchStart);
    }

    function toggleStopwatch() {
        if (root.stopwatchRunning)
            root.stopwatchPause();
        else
            root.stopwatchResume();
    }

    function stopwatchPause() {
        root.refreshStopwatch();
        InfoDrawerState.stopwatchElapsed = root.stopwatchTime;
        InfoDrawerState.stopwatchRunning = false;
        InfoDrawerState.flushSave();
    }

    function stopwatchResume() {
        if (root.stopwatchTime === 0)
            InfoDrawerState.stopwatchLaps = [];

        InfoDrawerState.stopwatchStart = root.currentCentiseconds() - root.stopwatchTime;
        InfoDrawerState.stopwatchElapsed = root.stopwatchTime;
        InfoDrawerState.stopwatchRunning = true;
        InfoDrawerState.flushSave();
    }

    function stopwatchReset() {
        root.stopwatchTime = 0;
        InfoDrawerState.stopwatchElapsed = 0;
        InfoDrawerState.stopwatchLaps = [];
        InfoDrawerState.stopwatchRunning = false;
        InfoDrawerState.stopwatchStart = root.currentCentiseconds();
        InfoDrawerState.flushSave();
    }

    function stopwatchRecordLap() {
        if (!root.stopwatchRunning)
            return;

        root.refreshStopwatch();
        InfoDrawerState.stopwatchLaps = [...InfoDrawerState.stopwatchLaps, root.stopwatchTime];
        InfoDrawerState.flushSave();
    }

    Component.onCompleted: root.syncFromStore()

    Connections {
        target: InfoDrawerState

        function onReadyChanged() {
            if (InfoDrawerState.ready)
                root.syncFromStore();
        }
    }

    Timer {
        interval: 200
        running: root.pomodoroRunning
        repeat: true
        onTriggered: root.refreshPomodoro()
    }

    Timer {
        interval: 10
        running: root.stopwatchRunning
        repeat: true
        onTriggered: root.refreshStopwatch()
    }
}
