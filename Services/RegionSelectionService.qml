pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property int minimumSelectionSize: 8
    property bool active: false
    property string currentAction: ""
    property var currentOptions: ({})
    property string pendingAction: ""
    property string pendingGeometry: ""
    property var pendingOptions: ({})

    signal selectionAccepted(string action, string geometry, var options)
    signal selectionCancelled(string action)

    function begin(action, options) {
        if (root.active || commitDelay.running || !action)
            return false;

        root.currentAction = String(action);
        root.currentOptions = options || {};
        root.active = true;
        return true;
    }

    function accept(targetScreen, x, y, width, height) {
        if (!root.active || !targetScreen)
            return false;

        const localX = Math.round(x);
        const localY = Math.round(y);
        const selectedWidth = Math.round(width);
        const selectedHeight = Math.round(height);
        if (selectedWidth < root.minimumSelectionSize
                || selectedHeight < root.minimumSelectionSize)
            return false;

        const globalX = Math.round(targetScreen.x + localX);
        const globalY = Math.round(targetScreen.y + localY);
        root.pendingAction = root.currentAction;
        root.pendingGeometry = selectedWidth + "x" + selectedHeight
            + "+" + globalX + "+" + globalY;
        root.pendingOptions = root.currentOptions;
        root.active = false;
        commitDelay.restart();
        return true;
    }

    function cancel() {
        if (!root.active)
            return false;

        const action = root.currentAction;
        root.active = false;
        root.currentAction = "";
        root.currentOptions = {};
        root.selectionCancelled(action);
        return true;
    }

    Timer {
        id: commitDelay
        interval: 90
        repeat: false

        onTriggered: {
            const action = root.pendingAction;
            const geometry = root.pendingGeometry;
            const options = root.pendingOptions;
            root.pendingAction = "";
            root.pendingGeometry = "";
            root.pendingOptions = {};
            root.currentAction = "";
            root.currentOptions = {};
            root.selectionAccepted(action, geometry, options);
        }
    }
}
