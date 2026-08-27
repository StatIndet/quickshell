pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.Common

Singleton {
    id: root

    readonly property var _nativeAdapters: Bluetooth.adapters ? Bluetooth.adapters.values : []
    readonly property var _nativeDevices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var adapter: Bluetooth.defaultAdapter

    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool discovering: _nativeAdapters.some(candidate => candidate && candidate.discovering)
    readonly property bool scanning: discovering
    readonly property bool discoverable: available && adapter.discoverable
    readonly property bool pairable: available && adapter.pairable
    readonly property bool connected: connectedDevices.length > 0
    readonly property string connectedName: connected ? connectedDevices[0].name : ""
    readonly property bool busy: _pendingOperation.length > 0
        || _nativeAdapters.some(candidate => candidate
            && (candidate.state === BluetoothAdapterState.Enabling
                || candidate.state === BluetoothAdapterState.Disabling))
        || _nativeDevices.some(device => device
            && (device.pairing
                || device.state === BluetoothDeviceState.Connecting
                || device.state === BluetoothDeviceState.Disconnecting))

    readonly property var adapters: _nativeAdapters.map(candidate => root._describeAdapter(candidate))
    readonly property var devices: root._deduplicatedDeviceDescriptors()
    readonly property var connectedDevices: devices.filter(device => device.connected)
    readonly property var pairedDevices: devices.filter(device => !device.connected
        && (device.paired || device.bonded || device.trusted))
    readonly property var availableDevices: devices.filter(device => !device.connected
        && !device.paired && !device.bonded && !device.trusted)

    property string lastError: ""
    property var _discoveryOwners: ({})
    property bool _manualDiscoveryActive: false
    property string _pendingOperation: ""
    property string _pendingAddress: ""
    property string _pendingAdapterId: ""
    property bool _pendingTargetState: false
    property bool _pendingStateWasChanging: false
    property bool _pendingPairingStarted: false
    property var _pendingAdapter: null
    property var _pendingDevice: null

    signal operationStarted(string operation)
    signal operationSucceeded(string operation)
    signal operationFailed(string operation, string message)

    function _describeAdapter(candidate) {
        if (!candidate)
            return {};
        return {
            "id": String(candidate.adapterId || ""),
            "name": String(candidate.name || candidate.adapterId || ""),
            "dbusPath": String(candidate.dbusPath || ""),
            "available": true,
            "enabled": !!candidate.enabled,
            "state": BluetoothAdapterState.toString(candidate.state),
            "blocked": candidate.state === BluetoothAdapterState.Blocked,
            "discovering": !!candidate.discovering,
            "discoverable": !!candidate.discoverable,
            "discoverableTimeout": Number(candidate.discoverableTimeout || 0),
            "pairable": !!candidate.pairable,
            "pairableTimeout": Number(candidate.pairableTimeout || 0)
        };
    }

    function _describeDevice(device) {
        if (!device)
            return {};
        const deviceAdapter = device.adapter;
        return {
            "name": String(device.name || device.deviceName || device.address || qsTr("未知设备")),
            "deviceName": String(device.deviceName || ""),
            "address": String(device.address || ""),
            "icon": String(device.icon || ""),
            "adapterId": deviceAdapter ? String(deviceAdapter.adapterId || "") : "",
            "state": BluetoothDeviceState.toString(device.state),
            "connected": !!device.connected,
            "paired": !!device.paired,
            "bonded": !!device.bonded,
            "pairing": !!device.pairing,
            "trusted": !!device.trusted,
            "blocked": !!device.blocked,
            "wakeAllowed": !!device.wakeAllowed,
            "batteryAvailable": !!device.batteryAvailable,
            "battery": device.batteryAvailable ? Number(device.battery || 0) : -1,
            "batteryLevel": device.batteryAvailable ? Math.round(Number(device.battery || 0) * 100) : -1
        };
    }

    function _deduplicatedDeviceDescriptors() {
        const byAddress = {};
        for (const device of root._nativeDevices) {
            if (!device)
                continue;
            const descriptor = root._describeDevice(device);
            const key = descriptor.address.length > 0
                ? descriptor.address
                : descriptor.adapterId + "|" + descriptor.name;
            const current = byAddress[key];
            if (!current
                    || (descriptor.connected && !current.connected)
                    || (descriptor.paired && !current.paired))
                byAddress[key] = descriptor;
        }

        return Object.keys(byAddress)
            .map(key => byAddress[key])
            .sort((a, b) => {
                if (a.connected !== b.connected)
                    return a.connected ? -1 : 1;
                if ((a.paired || a.bonded) !== (b.paired || b.bonded))
                    return (a.paired || a.bonded) ? -1 : 1;
                return a.name.localeCompare(b.name);
            });
    }

    function _resolveAdapter(adapterLike) {
        const adapterId = typeof adapterLike === "string"
            ? adapterLike
            : adapterLike ? String(adapterLike.id || adapterLike.adapterId || "") : "";
        if (adapterId.length === 0)
            return root.adapter;
        return root._nativeAdapters.find(candidate => candidate && candidate.adapterId === adapterId) || null;
    }

    function _resolveDevice(deviceLike) {
        if (!deviceLike)
            return null;
        const address = typeof deviceLike === "string"
            ? deviceLike
            : String(deviceLike.address || "");
        const adapterId = typeof deviceLike === "string"
            ? ""
            : String(deviceLike.adapterId || "");
        return root._nativeDevices.find(device => device
            && device.address === address
            && (adapterId.length === 0
                || (device.adapter && device.adapter.adapterId === adapterId))) || null;
    }

    function _beginOperation(operation) {
        if (root._pendingOperation.length > 0) {
            root.operationFailed(operation, qsTr("另一项蓝牙操作仍在进行"));
            return false;
        }
        root.lastError = "";
        root._pendingOperation = operation;
        root._pendingStateWasChanging = false;
        root._pendingPairingStarted = false;
        operationTimeout.restart();
        root.operationStarted(operation);
        return true;
    }

    function _finishOperationSucceeded() {
        if (root._pendingOperation.length === 0)
            return;
        const operation = root._pendingOperation;
        operationTimeout.stop();
        root._clearPendingOperation();
        root.operationSucceeded(operation);
    }

    function _finishOperationFailed(message) {
        if (root._pendingOperation.length === 0)
            return;
        const operation = root._pendingOperation;
        root.lastError = String(message || qsTr("蓝牙操作失败"));
        operationTimeout.stop();
        root._clearPendingOperation();
        root.operationFailed(operation, root.lastError);
    }

    function _clearPendingOperation() {
        root._pendingOperation = "";
        root._pendingAddress = "";
        root._pendingAdapterId = "";
        root._pendingTargetState = false;
        root._pendingStateWasChanging = false;
        root._pendingPairingStarted = false;
        root._pendingAdapter = null;
        root._pendingDevice = null;
    }

    function setAdapterEnabled(adapterLike, value) {
        const nativeAdapter = root._resolveAdapter(adapterLike);
        const requested = !!value;
        if (!nativeAdapter) {
            root.lastError = qsTr("未检测到蓝牙适配器");
            root.operationFailed("set-adapter-enabled", root.lastError);
            return;
        }
        if (requested && nativeAdapter.state === BluetoothAdapterState.Blocked) {
            root.lastError = qsTr("蓝牙适配器已被 rfkill 阻止");
            root.operationFailed("set-adapter-enabled", root.lastError);
            return;
        }
        if (nativeAdapter.enabled === requested)
            return;
        if (!root._beginOperation("set-adapter-enabled"))
            return;

        root._pendingAdapter = nativeAdapter;
        root._pendingAdapterId = String(nativeAdapter.adapterId || "");
        root._pendingTargetState = requested;
        nativeAdapter.enabled = requested;
    }

    function setBluetoothEnabled(value) {
        root.setAdapterEnabled(root.adapter, value);
    }

    function toggle() {
        root.setBluetoothEnabled(!root.enabled);
    }

    function setDiscoverable(value, adapterLike) {
        const nativeAdapter = root._resolveAdapter(adapterLike);
        const requested = !!value;
        if (!nativeAdapter || !nativeAdapter.enabled) {
            root.lastError = nativeAdapter ? qsTr("蓝牙适配器已关闭") : qsTr("未检测到蓝牙适配器");
            root.operationFailed("set-discoverable", root.lastError);
            return;
        }
        if (nativeAdapter.discoverable === requested)
            return;
        if (!root._beginOperation("set-discoverable"))
            return;
        root._pendingAdapter = nativeAdapter;
        root._pendingTargetState = requested;
        nativeAdapter.discoverable = requested;
    }

    function setPairable(value, adapterLike) {
        const nativeAdapter = root._resolveAdapter(adapterLike);
        const requested = !!value;
        if (!nativeAdapter || !nativeAdapter.enabled) {
            root.lastError = nativeAdapter ? qsTr("蓝牙适配器已关闭") : qsTr("未检测到蓝牙适配器");
            root.operationFailed("set-pairable", root.lastError);
            return;
        }
        if (nativeAdapter.pairable === requested)
            return;
        if (!root._beginOperation("set-pairable"))
            return;
        root._pendingAdapter = nativeAdapter;
        root._pendingTargetState = requested;
        nativeAdapter.pairable = requested;
    }

    function _discoveryOwnerKey(owner) {
        return String(owner || "anonymous");
    }

    function acquireDiscovery(owner) {
        const key = root._discoveryOwnerKey(owner);
        const next = Object.assign({}, root._discoveryOwners);
        next[key] = Number(next[key] || 0) + 1;
        root._discoveryOwners = next;
        root._applyDiscovery();
    }

    function releaseDiscovery(owner) {
        const key = root._discoveryOwnerKey(owner);
        const next = Object.assign({}, root._discoveryOwners);
        if (!next[key])
            return;
        if (next[key] <= 1)
            delete next[key];
        else
            next[key] -= 1;
        root._discoveryOwners = next;
        root._applyDiscovery();
    }

    function requestDiscovery() {
        if (!root.available) {
            root.lastError = qsTr("未检测到蓝牙适配器或 BlueZ 不可用");
            root.operationFailed("discovery", root.lastError);
            return;
        }
        if (!root.enabled) {
            root.lastError = qsTr("蓝牙适配器已关闭");
            root.operationFailed("discovery", root.lastError);
            return;
        }
        root.lastError = "";
        root._manualDiscoveryActive = true;
        manualDiscoveryReleaseTimer.restart();
        root._applyDiscovery();
        root.operationStarted("discovery");
        root.operationSucceeded("discovery");
    }

    function stopDiscovery() {
        root._manualDiscoveryActive = false;
        manualDiscoveryReleaseTimer.stop();
        root._applyDiscovery();
    }

    function _applyDiscovery() {
        const requested = root._manualDiscoveryActive
            || Object.keys(root._discoveryOwners).length > 0;
        for (const nativeAdapter of root._nativeAdapters) {
            if (!nativeAdapter)
                continue;
            const shouldDiscover = requested && nativeAdapter.enabled;
            if (nativeAdapter.discovering !== shouldDiscover)
                nativeAdapter.discovering = shouldDiscover;
        }
    }

    function _beginDeviceOperation(operation, deviceLike, targetState) {
        const nativeDevice = root._resolveDevice(deviceLike);
        if (!nativeDevice) {
            root.lastError = qsTr("目标蓝牙设备已不可用");
            root.operationFailed(operation, root.lastError);
            return null;
        }
        if (nativeDevice.blocked && (operation === "connect" || operation === "pair")) {
            root.lastError = qsTr("目标蓝牙设备已被阻止");
            root.operationFailed(operation, root.lastError);
            return null;
        }
        if (!root._beginOperation(operation))
            return null;
        root._pendingDevice = nativeDevice;
        root._pendingAddress = String(nativeDevice.address || "");
        root._pendingAdapterId = nativeDevice.adapter ? String(nativeDevice.adapter.adapterId || "") : "";
        root._pendingTargetState = !!targetState;
        return nativeDevice;
    }

    function connectDevice(device) {
        const current = root._resolveDevice(device);
        if (current && current.connected)
            return;
        const nativeDevice = root._beginDeviceOperation("connect", device, true);
        if (nativeDevice)
            nativeDevice.connect();
    }

    function disconnectDevice(device) {
        const current = root._resolveDevice(device);
        if (current && !current.connected)
            return;
        const nativeDevice = root._beginDeviceOperation("disconnect", device, false);
        if (nativeDevice)
            nativeDevice.disconnect();
    }

    function pairDevice(device) {
        // TODO(Extras phase 2): custom PIN/passkey confirmation requires a
        // project-owned BlueZ agent, which the installed Quickshell API does not expose.
        const current = root._resolveDevice(device);
        if (current && current.paired)
            return;
        const nativeDevice = root._beginDeviceOperation("pair", device, true);
        if (nativeDevice)
            nativeDevice.pair();
    }

    function cancelPairing(device) {
        const current = root._resolveDevice(device);
        if (current && !current.pairing)
            return;
        const nativeDevice = root._beginDeviceOperation("cancel-pair", device, false);
        if (nativeDevice)
            nativeDevice.cancelPair();
    }

    function forgetDevice(device) {
        const nativeDevice = root._beginDeviceOperation("forget", device, false);
        if (nativeDevice)
            nativeDevice.forget();
    }

    function setDeviceTrusted(device, value) {
        const current = root._resolveDevice(device);
        if (current && current.trusted === !!value)
            return;
        const nativeDevice = root._beginDeviceOperation("set-trusted", device, value);
        if (nativeDevice)
            nativeDevice.trusted = !!value;
    }

    function setDeviceBlocked(device, value) {
        const current = root._resolveDevice(device);
        if (current && current.blocked === !!value)
            return;
        const nativeDevice = root._beginDeviceOperation(value ? "block" : "unblock", device, value);
        if (nativeDevice)
            nativeDevice.blocked = !!value;
    }

    Connections {
        target: Bluetooth

        function onDefaultAdapterChanged() {
            Qt.callLater(root._applyDiscovery);
        }
    }

    Connections {
        target: Bluetooth.adapters

        function onValuesChanged() {
            Qt.callLater(root._applyDiscovery);
        }
    }

    Connections {
        target: Bluetooth.devices

        function onValuesChanged() {
            if (root._pendingOperation === "forget"
                    && root._pendingAddress.length > 0
                    && !root._resolveDevice({
                        "address": root._pendingAddress,
                        "adapterId": root._pendingAdapterId
                    }))
                root._finishOperationSucceeded();
        }
    }

    Connections {
        target: root._pendingAdapter
        enabled: root._pendingAdapter !== null

        function onEnabledChanged() {
            root._applyDiscovery();
            if (root._pendingOperation === "set-adapter-enabled"
                    && root._pendingAdapter.enabled === root._pendingTargetState)
                root._finishOperationSucceeded();
        }

        function onDiscoverableChanged() {
            if (root._pendingOperation === "set-discoverable"
                    && root._pendingAdapter.discoverable === root._pendingTargetState)
                root._finishOperationSucceeded();
        }

        function onPairableChanged() {
            if (root._pendingOperation === "set-pairable"
                    && root._pendingAdapter.pairable === root._pendingTargetState)
                root._finishOperationSucceeded();
        }
    }

    Connections {
        target: root._pendingDevice
        enabled: root._pendingDevice !== null

        function onConnectedChanged() {
            if (root._pendingOperation === "connect" && root._pendingDevice.connected)
                root._finishOperationSucceeded();
            else if (root._pendingOperation === "disconnect" && !root._pendingDevice.connected)
                root._finishOperationSucceeded();
        }

        function onStateChanged() {
            if (!root._pendingDevice)
                return;
            if (root._pendingDevice.state === BluetoothDeviceState.Connecting
                    || root._pendingDevice.state === BluetoothDeviceState.Disconnecting)
                root._pendingStateWasChanging = true;
            if (root._pendingOperation === "connect"
                    && root._pendingStateWasChanging
                    && root._pendingDevice.state === BluetoothDeviceState.Disconnected)
                root._finishOperationFailed(qsTr("设备连接失败"));
        }

        function onPairingChanged() {
            if (!root._pendingDevice)
                return;
            if (root._pendingDevice.pairing)
                root._pendingPairingStarted = true;
            else if (root._pendingOperation === "cancel-pair")
                root._finishOperationSucceeded();
            else if (root._pendingOperation === "pair"
                    && root._pendingPairingStarted
                    && !root._pendingDevice.paired)
                root._finishOperationFailed(qsTr("配对失败；需要 PIN/Passkey 交互的设备将在第二阶段支持"));
        }

        function onPairedChanged() {
            if (root._pendingOperation === "pair" && root._pendingDevice.paired)
                root._finishOperationSucceeded();
            else if (root._pendingOperation === "forget"
                    && !root._pendingDevice.paired && !root._pendingDevice.bonded)
                root._finishOperationSucceeded();
        }

        function onBondedChanged() {
            if (root._pendingOperation === "forget"
                    && !root._pendingDevice.paired && !root._pendingDevice.bonded)
                root._finishOperationSucceeded();
        }

        function onTrustedChanged() {
            if (root._pendingOperation === "set-trusted"
                    && root._pendingDevice.trusted === root._pendingTargetState)
                root._finishOperationSucceeded();
        }

        function onBlockedChanged() {
            if ((root._pendingOperation === "block" || root._pendingOperation === "unblock")
                    && root._pendingDevice.blocked === root._pendingTargetState)
                root._finishOperationSucceeded();
        }
    }

    Timer {
        id: manualDiscoveryReleaseTimer
        interval: 30000
        repeat: false
        onTriggered: {
            root._manualDiscoveryActive = false;
            root._applyDiscovery();
        }
    }

    Timer {
        id: operationTimeout
        interval: 60000
        repeat: false
        onTriggered: root._finishOperationFailed(qsTr("蓝牙操作超时；当前 Quickshell API 未提供更详细的 BlueZ 错误"))
    }

    Process {
        id: agentProcess
        command: ["python3", Paths.scriptPath("system", "bluetooth-agent.py")]
        running: true
    }

    Component.onCompleted: {
        root._applyDiscovery();
        if (root.adapter && !root.adapter.pairable) {
            root.adapter.pairable = true;
        }
    }
    Component.onDestruction: {
        for (const nativeAdapter of root._nativeAdapters) {
            if (nativeAdapter && nativeAdapter.discovering)
                nativeAdapter.discovering = false;
        }
    }
}
