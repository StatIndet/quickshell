pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool available: false
    property bool capsLock: false
    property bool numLock: false
    property var error: null
    property bool _hasSnapshot: false
    property int _reconnectAttempts: 0

    signal lockStateChanged
    signal availabilityChanged

    function unavailable(code, message) {
        available = false;
        _hasSnapshot = false;
        error = {
            code: code,
            message: message
        };
        availabilityChanged();
    }

    function consume(line) {
        let value;
        try {
            value = JSON.parse(line);
        } catch (_) {
            unavailable("keyboard_protocol_invalid", "Invalid keyboard JSONL");
            return;
        }
        if (!value || value.schemaVersion !== 1 || value.command !== "keyboard.watch" || typeof value.ok
                !== "boolean" || typeof value.available !== "boolean" || (value.event !== "snapshot"
                                                                          && value.event !== "changed") || (
                    value.available && (!value.ok || value.error !== null || typeof value.capsLock
                                        !== "boolean" || typeof value.numLock !== "boolean")) || (
                    !value.available && (value.ok || !value.error || typeof value.error.code !== "string"
                                         || typeof value.error.message !== "string" || value.capsLock
                                         !== null || value.numLock !== null))) {
            unavailable("keyboard_protocol_invalid", "Unsupported keyboard response");
            return;
        }
        const snapshot = value.event === "snapshot" || !_hasSnapshot || !available;
        const changed = capsLock !== value.capsLock || numLock !== value.numLock;
        available = value.available;
        error = value.error;
        _hasSnapshot = available;
        if (!available) {
            availabilityChanged();
            return;
        }
        capsLock = value.capsLock;
        numLock = value.numLock;
        if (snapshot) {
            // Establish an OSD baseline without announcing a toggle.
            availabilityChanged();
        } else if (changed) {
            lockStateChanged();
        }
    }

    Component.onCompleted: stream.running = true

    Process {
        id: stream
        command: [Paths.stableKey, "keyboard", "watch", "--format", "jsonl"]
        stdout: SplitParser {
            onRead: data => root.consume(data)
        }
        onExited: {
            root.unavailable(root.error ? root.error.code : "keyboard_backend_disconnected", root.error ? root.error.message :
                                                                                                          "Keyboard backend exited");
            if (root._reconnectAttempts < 3) {
                root._reconnectAttempts += 1;
                reconnect.start();
            }
        }
    }

    // Only reconnect an exited process; silence on a healthy stream is normal.
    Timer {
        id: reconnect
        interval: 1000 * root._reconnectAttempts
        onTriggered: stream.running = true
    }
}
