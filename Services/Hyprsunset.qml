pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    signal gammaChangeAttempt()

    readonly property real gammaLowerLimit: 25
    property int gamma: 100

    function clampGamma(value) {
        return Math.round(Math.max(root.gammaLowerLimit, Math.min(100, value)));
    }

    function startHyprsunset() {
        Quickshell.execDetached(["bash", "-c", "pidof hyprsunset >/dev/null || hyprsunset >/dev/null 2>&1"]);
    }

    function setGamma(value) {
        const safeGamma = root.clampGamma(value);
        root.gamma = safeGamma;
        root.gammaChangeAttempt();
        root.startHyprsunset();
        applyGammaTimer.restart();
    }

    Timer {
        id: applyGammaTimer

        interval: 40
        repeat: false
        onTriggered: Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", String(root.gamma)])
    }
}
