pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property bool enabled: false
    property bool connected: false
    property string connectedName: ""
    property var devices: []

    function refresh() {
        statusPoller.running = true;
    }

    function refreshDevices() {
        devicePoller.running = true;
    }

    function toggle() {
        if (!root.available)
            return;

        Quickshell.execDetached(["bluetoothctl", "power", root.enabled ? "off" : "on"]);
        root.enabled = !root.enabled;
        if (!root.enabled) {
            root.connected = false;
            root.connectedName = "";
            root.devices = [];
        }
        debounceTimer.start();
    }

    function connectDevice(mac) {
        Quickshell.execDetached(["bluetoothctl", "connect", mac]);
        connectDebounceTimer.mac = mac;
        connectDebounceTimer.start();
    }

    function disconnectDevice(mac) {
        Quickshell.execDetached(["bluetoothctl", "disconnect", mac]);
        connectDebounceTimer.start();
    }

    function pairDevice(mac) {
        Quickshell.execDetached(["bluetoothctl", "pair", mac]);
        pairDebounceTimer.start();
    }

    function removeDevice(mac) {
        Quickshell.execDetached(["bluetoothctl", "remove", mac]);
        removeDebounceTimer.start();
    }

    function trustDevice(mac) {
        Quickshell.execDetached(["bluetoothctl", "trust", mac]);
    }

    Process {
        id: statusPoller
        command: ["bash", "-c", `
            if ! command -v bluetoothctl >/dev/null 2>&1 || ! bluetoothctl show >/dev/null 2>&1; then
                echo "AVAILABLE:0"
                exit 0
            fi

            echo "AVAILABLE:1"
            if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
                echo "ENABLED:1"
                first_device="$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-)"
                if [ -n "$first_device" ]; then
                    echo "CONNECTED:1"
                    echo "NAME:$first_device"
                else
                    echo "CONNECTED:0"
                    echo "NAME:"
                fi
            else
                echo "ENABLED:0"
                echo "CONNECTED:0"
                echo "NAME:"
            fi
        `]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const data = line.trim();
                if (data.length === 0)
                    return;

                if (data.startsWith("AVAILABLE:"))
                    root.available = data.substring(10) === "1";
                else if (data.startsWith("ENABLED:"))
                    root.enabled = data.substring(8) === "1";
                else if (data.startsWith("CONNECTED:"))
                    root.connected = data.substring(10) === "1";
                else if (data.startsWith("NAME:"))
                    root.connectedName = data.substring(5);
            }
        }
    }

    Process {
        id: devicePoller
        command: ["bash", "-c", `
            if ! command -v bluetoothctl >/dev/null 2>&1 || ! bluetoothctl show >/dev/null 2>&1; then
                exit 0
            fi

            bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' || exit 0

            # Get paired devices with connection status
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                mac=$(echo "$line" | awk '{print $2}')
                name=$(echo "$line" | cut -d' ' -f3-)
                connected="no"
                trusted="no"

                # Check connection
                info=$(bluetoothctl info "$mac" 2>/dev/null)
                echo "$info" | grep -q "Connected: yes" && connected="yes"
                echo "$info" | grep -q "Trusted: yes" && trusted="yes"

                echo "DEVICE:$mac|$name|$connected|$trusted"
            done < <(bluetoothctl devices Paired 2>/dev/null)

            # Also list discovered (non-paired) devices
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                mac=$(echo "$line" | awk '{print $2}')
                name=$(echo "$line" | cut -d' ' -f3-)

                # Skip if already in paired list
                bluetoothctl devices Paired 2>/dev/null | grep -q "$mac" && continue

                echo "DISCOVERED:$mac|$name"
            done < <(bluetoothctl devices 2>/dev/null)
        `]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const data = line.trim();
                if (data.length === 0)
                    return;

                if (data.startsWith("DEVICE:")) {
                    const parts = data.substring(7).split("|");
                    const dev = {
                        "mac": parts[0] || "",
                        "name": parts[1] || parts[0] || "未知设备",
                        "connected": parts[2] === "yes",
                        "trusted": parts[3] === "yes",
                        "paired": true
                    };

                    const newList = [];
                    let found = false;
                    for (let i = 0; i < root.devices.length; i++) {
                        if (root.devices[i].mac === dev.mac) {
                            newList.push(dev);
                            found = true;
                        } else {
                            newList.push(root.devices[i]);
                        }
                    }
                    if (!found)
                        newList.push(dev);
                    root.devices = newList;
                } else if (data.startsWith("DISCOVERED:")) {
                    const parts = data.substring(11).split("|");
                    const dev = {
                        "mac": parts[0] || "",
                        "name": parts[1] || parts[0] || "未知设备",
                        "connected": false,
                        "trusted": false,
                        "paired": false
                    };

                    // Don't duplicate
                    let exists = false;
                    for (let i = 0; i < root.devices.length; i++) {
                        if (root.devices[i].mac === dev.mac) {
                            exists = true;
                            break;
                        }
                    }
                    if (!exists) {
                        const newList = root.devices.slice();
                        newList.push(dev);
                        root.devices = newList;
                    }
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: debounceTimer
        interval: 350
        running: false
        repeat: false
        onTriggered: {
            root.refresh();
            if (root.enabled)
                root.refreshDevices();
        }
    }

    Timer {
        id: connectDebounceTimer
        property string mac: ""
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            root.refresh();
            root.refreshDevices();
        }
    }

    Timer {
        id: pairDebounceTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: root.refreshDevices()
    }

    Timer {
        id: removeDebounceTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: root.refreshDevices()
    }

    Component.onCompleted: {
        if (root.enabled)
            root.refreshDevices();
    }

    onEnabledChanged: {
        if (root.enabled)
            root.refreshDevices();
    }
}
