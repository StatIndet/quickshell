pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager
    readonly property bool wifiEnabled: available && Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: available && Networking.wifiHardwareEnabled
    readonly property bool connected: root._nativeDevices.some((device) => {
        return device && device.connected;
    })
    readonly property bool internetAvailable: Networking.connectivity === NetworkConnectivity.Full
    readonly property bool captivePortal: Networking.connectivity === NetworkConnectivity.Portal
    readonly property bool limitedConnectivity: Networking.connectivity === NetworkConnectivity.Limited
    readonly property bool connectivityKnown: Networking.connectivity !== NetworkConnectivity.Unknown
    readonly property bool canCheckConnectivity: available && Networking.canCheckConnectivity
    readonly property bool connectivityCheckEnabled: available && Networking.connectivityCheckEnabled
    readonly property bool scanning: wifiScanning
    readonly property bool wifiScanning: root._nativeWifiDevices.some((device) => {
        return device && device.scannerEnabled;
    })
    readonly property bool busy: root._pendingOperation.length > 0 || root._pendingSettings !== null || root._pendingForgetSettings !== null || NetworkManagerExtras.mutationBusy
    readonly property bool wifiConnecting: root._pendingOperation === "connect" || root._nativeWifiDevices.some((device) => {
        return device && device.state === ConnectionState.Connecting;
    })
    property string lastError: ""
    property string passwordRequestSsid: ""
    property string passwordRequestDeviceName: ""
    property string connectTargetSsid: ""
    property string connectTargetDeviceName: ""
    readonly property var _nativeDevices: Networking.devices ? Networking.devices.values : []
    readonly property var _nativeWifiDevices: _nativeDevices.filter((device) => {
        return device && device.type === DeviceType.Wifi;
    })
    readonly property var _nativeWiredDevices: _nativeDevices.filter((device) => {
        return device && device.type === DeviceType.Wired;
    })
    readonly property var allWifiNetworks: {
        const result = [];
        for (const device of root._nativeWifiDevices) {
            for (const network of (device && device.networks ? device.networks.values : [])) {
                if (network && String(network.name || "").length > 0)
                    result.push(root._describeWifiNetwork(device, network));

            }
        }
        return result;
    }
    readonly property var settingsWifiNetworks: allWifiNetworks.slice().sort((a, b) => {
        if (a.active !== b.active)
            return a.active ? -1 : 1;

        if (a.known !== b.known)
            return a.known ? -1 : 1;

        return b.strength - a.strength;
    })
    // Quickshell keeps a WifiNetwork visible while it owns saved settings,
    // even when no AP is currently in range. Keep those entries on the Saved
    // Networks page instead of presenting them as nearby scan results.
    readonly property var nearbyWifiNetworks: settingsWifiNetworks.filter((network) => {
        return network.active || !network.known || network.strength > 0;
    })
    readonly property var devices: _nativeDevices.map((device) => {
        return root._describeDevice(device);
    })
    readonly property var wifiDevices: devices.filter((device) => {
        return device.type === "wifi";
    })
    readonly property var wiredDevices: devices.filter((device) => {
        return device.type === "wired";
    })
    readonly property bool wifiAvailable: wifiDevices.length > 0
    readonly property bool wifiConnected: activeWifi !== null
    readonly property bool wiredConnected: wiredDevices.some((device) => {
        return device.connected;
    })
    readonly property bool ethernetConnected: wiredConnected
    // Quickshell's NetworkManager backend already groups BSSIDs by SSID and keeps the
    // strongest AP as the WifiNetwork representative. This second pass only merges the
    // same SSID across multiple Wi-Fi adapters.
    readonly property var accessPoints: {
        const bySsid = {
        };
        for (const device of root._nativeWifiDevices) {
            const networks = device && device.networks ? device.networks.values : [];
            for (const network of networks) {
                if (!network)
                    continue;

                const ssid = String(network.name || "");
                if (ssid.length === 0)
                    continue;

                const candidate = root._describeWifiNetwork(device, network);
                const current = bySsid[ssid];
                if (!current || (candidate.active && !current.active) || (candidate.active === current.active && candidate.strength > current.strength))
                    bySsid[ssid] = candidate;

            }
        }
        return Object.keys(bySsid).map((ssid) => {
            return bySsid[ssid];
        });
    }
    readonly property var wifiNetworks: accessPoints
    readonly property var friendlyWifiNetworks: accessPoints.slice().sort((a, b) => {
        if (a.active !== b.active)
            return a.active ? -1 : 1;

        if (a.known !== b.known)
            return a.known ? -1 : 1;

        return b.strength - a.strength;
    })
    readonly property var savedWifiNetworks: friendlyWifiNetworks.filter((network) => {
        return network.known;
    })
    readonly property var availableWifiNetworks: friendlyWifiNetworks.filter((network) => {
        return !network.known;
    })
    readonly property var savedWifiConnections: savedWifiNetworks.map((network) => {
        return ({
            "ssid": network.ssid,
            "deviceName": network.deviceName
        });
    })
    readonly property var savedWifiProfiles: {
        const profiles = [];
        const byUuid = {
        };
        for (const network of root.allWifiNetworks) {
            for (const profile of network.profiles || []) {
                const currentIndex = byUuid[profile.uuid];
                if (currentIndex === undefined) {
                    byUuid[profile.uuid] = profiles.length;
                    profiles.push(profile);
                } else {
                    const current = profiles[currentIndex];
                    if ((profile.networkConnected && !current.networkConnected) || (profile.networkConnected === current.networkConnected && profile.strength > current.strength))
                        profiles[currentIndex] = profile;

                }
            }
        }
        return profiles.sort((a, b) => {
            return a.name.localeCompare(b.name);
        });
    }
    readonly property var wiredProfiles: {
        const profiles = [];
        const seen = {
        };
        for (const device of root._nativeWiredDevices) {
            const network = device ? device.network : null;
            for (const settings of (network && network.nmSettings ? network.nmSettings : [])) {
                const profile = root._describeProfile(settings, network, device, "wired");
                if (!seen[profile.uuid]) {
                    seen[profile.uuid] = true;
                    profiles.push(profile);
                }
            }
        }
        return profiles;
    }
    property var runtimeDetails: ({
    })
    property bool runtimeDetailsLoading: false
    property string runtimeDetailsError: ""
    property int _runtimeRequestGeneration: 0
    property var _queuedRuntimeRequest: null
    property var _pendingSettings: null
    property string _pendingProfileUuid: ""
    property var _pendingProfileExpected: null
    property var _pendingForgetSettings: null
    property string _pendingForgetUuid: ""
    property bool _addWifiPending: false
    property bool _addWifiUsesNative: false
    property var _addWifiTarget: null
    readonly property var activeWifi: accessPoints.find((network) => {
        return network.active;
    }) || null
    readonly property var activeNetwork: {
        for (const device of root._nativeWiredDevices) {
            if (device && device.connected && device.network)
                return root._describeWiredNetwork(device, device.network);

        }
        return activeWifi;
    }
    readonly property string activeSsid: activeWifi ? activeWifi.ssid : ""
    readonly property string activeConnection: activeNetwork ? activeNetwork.name : qsTr("已断开")
    readonly property string activeConnectionType: activeNetwork ? (activeNetwork.type === "wired" ? qsTr("有线") : "Wi-Fi") : ""
    readonly property int signalStrength: activeWifi ? activeWifi.strength : 0
    readonly property var wifiConnectTarget: connectTargetSsid.length > 0 ? accessPoints.find((network) => {
        return network.ssid === connectTargetSsid && (connectTargetDeviceName.length === 0 || network.deviceName === connectTargetDeviceName);
    }) || null : null
    readonly property bool passwordPromptActive: passwordRequestSsid.length > 0
    property var _scanOwners: ({
    })
    property bool _manualScanActive: false
    property string _pendingOperation: ""
    property string _pendingSsid: ""
    property bool _pendingWithPsk: false
    property bool _pendingWifiState: false
    property bool _pendingStateWasChanging: false
    property var _pendingNetwork: null

    signal operationStarted(string operation)
    signal operationSucceeded(string operation)
    signal operationFailed(string operation, string message)
    signal profileWriteSucceeded(string uuid)
    signal profileWriteFailed(string uuid, string message)
    signal profileForgetSucceeded(string uuid)
    signal profileForgetFailed(string uuid, string message)
    signal addWifiFinished(bool success, var result, string message)

    function _describeDevice(device) {
        if (!device)
            return {
        };

        const isWifi = device.type === DeviceType.Wifi;
        return {
            "name": String(device.name || ""),
            "deviceName": String(device.name || ""),
            "address": String(device.address || ""),
            "type": isWifi ? "wifi" : device.type === DeviceType.Wired ? "wired" : "unknown",
            "connected": !!device.connected,
            "state": ConnectionState.toString(device.state),
            "managed": !!device.nmManaged,
            "autoconnect": !!device.autoconnect,
            "scanning": isWifi && !!device.scannerEnabled,
            "hasLink": !isWifi && !!device.hasLink,
            "linkSpeed": !isWifi ? Number(device.linkSpeed || 0) : 0,
            "nativeDevice": device,
            "nativeNetwork": !isWifi ? device.network : null
        };
    }

    function _describeWifiNetwork(device, network) {
        const securityType = network.security;
        return {
            "name": String(network.name || ""),
            "ssid": String(network.name || ""),
            "deviceName": String(device.name || ""),
            "address": String(device.address || ""),
            "type": "wifi",
            "strength": Math.round(Number(network.signalStrength || 0) * 100),
            "security": WifiSecurityType.toString(securityType),
            "securityType": securityType,
            "isSecure": securityType !== WifiSecurityType.Open && securityType !== WifiSecurityType.Owe,
            "known": !!network.known,
            "saved": !!network.known,
            "active": !!network.connected,
            "connected": !!network.connected,
            "state": ConnectionState.toString(network.state),
            "stateChanging": !!network.stateChanging,
            "askingPassword": root.passwordRequestSsid === String(network.name || "") && (root.passwordRequestDeviceName.length === 0 || root.passwordRequestDeviceName === String(device.name || "")),
            "profiles": (network.nmSettings || []).map((settings) => {
                return root._describeProfile(settings, network, device, "wifi");
            }),
            "nativeNetwork": network
        };
    }

    function _describeProfile(settings, network, device, type) {
        const map = settings ? settings.read() : {
        };
        const connection = map.connection || {
        };
        return {
            "uuid": String(settings ? settings.uuid || "" : ""),
            "name": String(settings ? settings.id || network.name || "" : ""),
            "ssid": String(network ? network.name || "" : ""),
            "type": type,
            "deviceName": String(device ? device.name || "" : ""),
            "deviceAddress": String(device ? device.address || "" : ""),
            "networkConnected": !!(network && network.connected),
            "strength": network ? Math.round(Number(network.signalStrength || 0) * 100) : 0,
            "autoconnect": connection.autoconnect === undefined ? true : !!connection.autoconnect,
            "nativeSettings": settings,
            "nativeNetwork": network
        };
    }

    function _describeWiredNetwork(device, network) {
        return {
            "name": String(network.name || device.name || qsTr("有线网络")),
            "deviceName": String(device.name || ""),
            "address": String(device.address || ""),
            "type": "wired",
            "known": !!network.known,
            "active": !!network.connected,
            "connected": !!network.connected,
            "state": ConnectionState.toString(network.state),
            "stateChanging": !!network.stateChanging,
            "hasLink": !!device.hasLink,
            "linkSpeed": Number(device.linkSpeed || 0)
        };
    }

    function _resolveNativeNetwork(network) {
        if (!network)
            return null;

        const type = String(network.type || "wifi");
        const deviceName = String(network.deviceName || "");
        if (type === "wired") {
            const wiredDevice = root._nativeWiredDevices.find((device) => {
                return device && (deviceName.length === 0 || device.name === deviceName);
            });
            return wiredDevice ? wiredDevice.network : null;
        }
        const ssid = String(network.ssid || network.name || network);
        for (const device of root._nativeWifiDevices) {
            if (!device || (deviceName.length > 0 && device.name !== deviceName))
                continue;

            const match = (device.networks ? device.networks.values : []).find((candidate) => {
                return candidate && candidate.name === ssid;
            });
            if (match)
                return match;

        }
        return null;
    }

    function _beginOperation(operation, network, ssid) {
        if (root.busy) {
            root.operationFailed(operation, qsTr("另一项网络操作仍在进行"));
            return false;
        }
        root.lastError = "";
        root._pendingOperation = operation;
        root._pendingNetwork = network;
        root._pendingSsid = ssid || "";
        root._pendingWithPsk = false;
        root._pendingStateWasChanging = false;
        operationTimeout.restart();
        root.operationStarted(operation);
        return true;
    }

    function _finishOperationSucceeded() {
        if (!root.busy)
            return ;

        const operation = root._pendingOperation;
        operationTimeout.stop();
        root._clearPendingOperation();
        root.operationSucceeded(operation);
    }

    function _finishOperationFailed(message) {
        if (!root.busy)
            return ;

        const operation = root._pendingOperation;
        root.lastError = String(message || qsTr("网络操作失败"));
        operationTimeout.stop();
        root._clearPendingOperation();
        root.operationFailed(operation, root.lastError);
    }

    function _clearPendingOperation() {
        root._pendingOperation = "";
        root._pendingNetwork = null;
        root._pendingSsid = "";
        root._pendingWithPsk = false;
        root._pendingStateWasChanging = false;
        root.connectTargetSsid = "";
        root.connectTargetDeviceName = "";
    }

    function _isPskSecurity(securityType) {
        return securityType === WifiSecurityType.WpaPsk || securityType === WifiSecurityType.Wpa2Psk || securityType === WifiSecurityType.Sae;
    }

    function setWifiEnabled(enabled) {
        const requested = !!enabled;
        if (!root.available) {
            root.lastError = qsTr("NetworkManager 不可用");
            root.operationFailed("set-wifi-enabled", root.lastError);
            return ;
        }
        if (requested && !root.wifiHardwareEnabled) {
            root.lastError = qsTr("Wi-Fi 已被硬件或 rfkill 阻止");
            root.operationFailed("set-wifi-enabled", root.lastError);
            return ;
        }
        if (root.wifiEnabled === requested)
            return ;

        if (!root._beginOperation("set-wifi-enabled", null, ""))
            return ;

        root._pendingWifiState = requested;
        Networking.wifiEnabled = requested;
    }

    function enableWifi(enabled = true) {
        root.setWifiEnabled(enabled);
    }

    function toggleWifi() {
        root.setWifiEnabled(!root.wifiEnabled);
    }

    function _scanOwnerKey(owner) {
        return String(owner || "anonymous");
    }

    function acquireScan(owner) {
        const key = root._scanOwnerKey(owner);
        const next = Object.assign({
        }, root._scanOwners);
        next[key] = Number(next[key] || 0) + 1;
        root._scanOwners = next;
        root._applyScanning();
    }

    function releaseScan(owner) {
        const key = root._scanOwnerKey(owner);
        const next = Object.assign({
        }, root._scanOwners);
        if (!next[key])
            return ;

        if (next[key] <= 1)
            delete next[key];
        else
            next[key] -= 1;
        root._scanOwners = next;
        root._applyScanning();
    }

    function requestScan() {
        if (!root.available) {
            root.lastError = qsTr("NetworkManager 不可用");
            root.operationFailed("scan", root.lastError);
            return ;
        }
        if (!root.wifiAvailable) {
            root.lastError = qsTr("未检测到 Wi-Fi 设备");
            root.operationFailed("scan", root.lastError);
            return ;
        }
        if (!root.wifiEnabled) {
            root.lastError = qsTr("Wi-Fi 已关闭");
            root.operationFailed("scan", root.lastError);
            return ;
        }
        root.lastError = "";
        root._manualScanActive = true;
        manualScanReleaseTimer.restart();
        root._applyScanning();
        root.operationStarted("scan");
        root.operationSucceeded("scan");
    }

    function rescanWifi() {
        root.requestScan();
    }

    function _applyScanning() {
        const shouldScan = root.wifiEnabled && (root._manualScanActive || Object.keys(root._scanOwners).length > 0);
        for (const device of root._nativeWifiDevices) {
            if (device && device.scannerEnabled !== shouldScan)
                device.scannerEnabled = shouldScan;

        }
    }

    function connectNetwork(network, credentials) {
        const nativeNetwork = root._resolveNativeNetwork(network);
        if (!nativeNetwork) {
            root.lastError = qsTr("目标网络已不可用");
            root.operationFailed("connect", root.lastError);
            return ;
        }
        const ssid = String(network.ssid || network.name || "");
        const password = typeof credentials === "string" ? credentials : credentials && credentials.password ? String(credentials.password) : "";
        if (String(network.type || "wifi") !== "wired" && password.length === 0) {
            if (!nativeNetwork.known && nativeNetwork.security !== WifiSecurityType.Open && nativeNetwork.security !== WifiSecurityType.Owe) {
                if (root._isPskSecurity(nativeNetwork.security)) {
                    root.openPasswordPrompt(network);
                    return ;
                }
                root.lastError = qsTr("该网络认证类型需要第二阶段 Secret Agent/Extras 后端");
                root.operationFailed("connect", root.lastError);
                return ;
            }
        }
        if (!root._beginOperation("connect", nativeNetwork, ssid))
            return ;

        root.connectTargetSsid = ssid;
        root.connectTargetDeviceName = String(network.deviceName || "");
        if (String(network.type || "wifi") === "wired") {
            nativeNetwork.connect();
            return ;
        }
        if (password.length > 0) {
            if (!root._isPskSecurity(nativeNetwork.security)) {
                root._finishOperationFailed(qsTr("当前 Quickshell API 仅支持 WPA/WPA2-PSK 与 SAE 密码连接"));
                return ;
            }
            root._pendingWithPsk = true;
            nativeNetwork.connectWithPsk(password);
            return ;
        }
        nativeNetwork.connect();
    }

    function connectToWifiNetwork(network) {
        if (!network)
            return ;

        if (network.active) {
            root.disconnectNetwork(network);
            return ;
        }
        root.connectNetwork(network, null);
    }

    function openPasswordPrompt(network) {
        root.lastError = "";
        root.passwordRequestSsid = network ? String(network.ssid || network.name || "") : "";
        root.passwordRequestDeviceName = network ? String(network.deviceName || "") : "";
    }

    function cancelPasswordRequest(network) {
        const ssid = network ? String(network.ssid || network.name || "") : "";
        const deviceName = network ? String(network.deviceName || "") : "";
        if (ssid.length === 0 || (root.passwordRequestSsid === ssid && (deviceName.length === 0 || root.passwordRequestDeviceName === deviceName))) {
            root.passwordRequestSsid = "";
            root.passwordRequestDeviceName = "";
        }
    }

    function changePassword(network, password) {
        if (!network)
            return ;

        const secret = String(password || "");
        if (secret.length === 0) {
            root.openPasswordPrompt(network);
            return ;
        }
        root.passwordRequestSsid = "";
        root.passwordRequestDeviceName = "";
        root.connectNetwork(network, {
            "password": secret
        });
    }

    function disconnectNetwork(network) {
        let nativeNetwork = root._resolveNativeNetwork(network || root.activeNetwork);
        if (!nativeNetwork) {
            root.lastError = qsTr("没有可断开的活动网络");
            root.operationFailed("disconnect", root.lastError);
            return ;
        }
        if (!root._beginOperation("disconnect", nativeNetwork, String(nativeNetwork.name || "")))
            return ;

        nativeNetwork.disconnect();
    }

    function disconnectWifiNetwork() {
        root.disconnectNetwork(root.activeWifi);
    }

    function forgetNetwork(network) {
        const nativeNetwork = root._resolveNativeNetwork(network);
        if (!nativeNetwork || !nativeNetwork.known) {
            root.lastError = qsTr("未找到已保存的网络配置");
            root.operationFailed("forget", root.lastError);
            return ;
        }
        if (!root._beginOperation("forget", nativeNetwork, String(nativeNetwork.name || "")))
            return ;

        nativeNetwork.forget();
    }

    function hasSavedSecret(ssid) {
        return root.savedWifiConnections.some((connection) => {
            return connection.ssid === ssid;
        });
    }

    function profileSnapshot(profile) {
        const settings = profile && profile.nativeSettings;
        if (!settings)
            return null;

        const map = settings.read();
        const ipv4 = map.ipv4 || {
        };
        const connection = map.connection || {
        };
        const addressData = ipv4["address-data"] || [];
        const legacyAddresses = ipv4.addresses || [];
        let address = "";
        if (addressData.length > 0) {
            const first = addressData[0];
            address = String(first.address || "") + "/" + String(first.prefix === undefined ? 24 : first.prefix);
        } else if (legacyAddresses.length > 0 && legacyAddresses[0].length >= 2) {
            address = root._uintToIpv4(Number(legacyAddresses[0][0])) + "/" + String(legacyAddresses[0][1]);
        }
        const dnsData = ipv4["dns-data"] || [];
        const dns = dnsData.length > 0 ? dnsData.map((value) => {
            return String(value);
        }) : (ipv4.dns || []).map((value) => {
            return root._uintToIpv4(Number(value));
        });
        const customDns = !!ipv4["ignore-auto-dns"];
        const method = String(ipv4.method || "auto");
        return {
            "method": method === "manual" ? "manual" : method === "auto" ? (customDns ? "auto-dns" : "auto") : method,
            "address": address,
            "gateway": String(ipv4.gateway || ""),
            "dns": dns.join(", "),
            "ignoreAutoDns": customDns,
            "autoconnect": connection.autoconnect === undefined ? true : !!connection.autoconnect
        };
    }

    function _ipv4ToUint(address) {
        const parts = String(address).split(".").map(Number);
        return ((parts[0] + parts[1] * 256 + parts[2] * 65536 + parts[3] * 1.67772e+07) >>> 0);
    }

    function _uintToIpv4(value) {
        const number = value >>> 0;
        return [number & 255, (number >>> 8) & 255, (number >>> 16) & 255, (number >>> 24) & 255].join(".");
    }

    function _validIpv4(value) {
        const parts = String(value || "").split(".");
        return parts.length === 4 && parts.every((part) => {
            return /^\d{1,3}$/.test(part) && Number(part) >= 0 && Number(part) <= 255;
        });
    }

    function _normalizedDns(value) {
        return String(value || "").trim().split(/[\s,]+/).filter((item) => {
            return item.length > 0;
        });
    }

    function _utf8Length(value) {
        try {
            return encodeURIComponent(String(value || "")).replace(/%[0-9A-Fa-f]{2}|./g, "x").length;
        } catch (error) {
            return 33;
        }
    }

    function _profileMatchesExpected(settings, expected) {
        const actual = root.profileSnapshot({
            "nativeSettings": settings
        });
        return actual && actual.method === expected.method && actual.address === expected.address && actual.gateway === expected.gateway && root._normalizedDns(actual.dns).join(",") === root._normalizedDns(expected.dns).join(",") && actual.autoconnect === expected.autoconnect;
    }

    function writeProfile(profile, values) {
        const settings = profile && profile.nativeSettings;
        if (!settings || root._pendingSettings) {
            root.profileWriteFailed(profile ? profile.uuid : "", qsTr("网络配置当前不可写入"));
            return false;
        }
        const mode = String(values.method || "auto");
        const current = root.profileSnapshot(profile);
        const dnsStrings = root._normalizedDns(values.dns);
        const addressPieces = String(values.address || "").trim().split("/");
        const gateway = String(values.gateway || "").trim();
        const manualValid = mode !== "manual" || (addressPieces.length === 2 && root._validIpv4(addressPieces[0]) && /^\d{1,2}$/.test(addressPieces[1]) && Number(addressPieces[1]) >= 0 && Number(addressPieces[1]) <= 32 && (gateway.length === 0 || root._validIpv4(gateway)));
        const dnsValid = mode === "auto" || (mode === "manual" && dnsStrings.length === 0) || (dnsStrings.length > 0 && dnsStrings.every(root._validIpv4));
        if (!current || !manualValid || !dnsValid) {
            root.profileWriteFailed(String(profile.uuid || ""), qsTr("IPv4 配置格式无效"));
            return false;
        }
        const requested = {
            "method": mode,
            "address": mode === "manual" ? addressPieces[0] + "/" + String(Number(addressPieces[1])) : "",
            "gateway": mode === "manual" ? gateway : "",
            "dns": mode === "auto" ? (current.method === "auto" ? current.dns : "") : dnsStrings.join(", "),
            "autoconnect": !!values.autoconnect
        };
        const ipv4Changed = requested.method !== current.method || requested.address !== current.address || requested.gateway !== current.gateway || root._normalizedDns(requested.dns).join(",") !== root._normalizedDns(current.dns).join(",");
        if (ipv4Changed && mode !== "auto" && mode !== "auto-dns" && mode !== "manual") {
            root.profileWriteFailed(String(profile.uuid || ""), qsTr("当前 IPv4 模式不在此页面的编辑范围内"));
            return false;
        }
        const ipv4 = {
            "method": mode === "manual" ? "manual" : "auto",
            "ignore-auto-dns": mode === "auto-dns" || (mode === "manual" && current.ignoreAutoDns),
            "dns": root._normalizedDns(requested.dns).map(root._ipv4ToUint),
            "dns-data": null
        };
        if (mode === "manual") {
            ipv4["address-data"] = [{
                "address": addressPieces[0],
                "prefix": Number(addressPieces[1])
            }];
            ipv4.addresses = [[root._ipv4ToUint(addressPieces[0]), Number(addressPieces[1]), gateway.length > 0 ? root._ipv4ToUint(gateway) : 0]];
            ipv4.gateway = gateway;
        } else {
            ipv4["address-data"] = null;
            ipv4.addresses = null;
            ipv4.gateway = null;
        }
        root._pendingSettings = settings;
        root._pendingProfileUuid = String(profile.uuid || "");
        root._pendingProfileExpected = requested;
        profileWriteTimeout.restart();
        const changes = {
        };
        if (requested.autoconnect !== current.autoconnect)
            changes.connection = {
            "autoconnect": !!values.autoconnect
        };

        if (ipv4Changed)
            changes.ipv4 = ipv4;

        if (Object.keys(changes).length === 0) {
            root._pendingSettings = null;
            root._pendingProfileUuid = "";
            root._pendingProfileExpected = null;
            profileWriteTimeout.stop();
            root.profileWriteSucceeded(String(profile.uuid || ""));
            return true;
        }
        settings.write(changes);
        return true;
    }

    function forgetProfile(profile) {
        const settings = profile && profile.nativeSettings;
        const uuid = String(profile ? profile.uuid || "" : "");
        if (!settings || root._pendingForgetSettings) {
            root.profileForgetFailed(uuid, qsTr("网络配置当前无法删除"));
            return false;
        }
        root._pendingForgetSettings = settings;
        root._pendingForgetUuid = uuid;
        profileForgetTimeout.restart();
        settings.forget();
        return true;
    }

    function requestRuntimeDetails(target) {
        const interfaceName = String(target ? target.deviceName || target.name || "" : "");
        const request = {
            "generation": ++root._runtimeRequestGeneration,
            "interfaceName": interfaceName,
            "isWifi": String(target ? target.type || "" : "") === "wifi"
        };
        root.runtimeDetailsLoading = true;
        root.runtimeDetailsError = "";
        root.runtimeDetails = {
        };
        root._queuedRuntimeRequest = request;
        if (!NetworkManagerExtras.busy)
            root._startRuntimeRequest();

        return interfaceName.length > 0;
    }

    function _startRuntimeRequest() {
        const request = root._queuedRuntimeRequest;
        if (!request || NetworkManagerExtras.busy)
            return ;

        root._queuedRuntimeRequest = null;
        NetworkManagerExtras.queryRuntimeDetails(request.interfaceName, request.isWifi, (success, details, errorMessage) => {
            if (request.generation !== root._runtimeRequestGeneration)
                return ;

            root.runtimeDetailsLoading = false;
            if (success)
                root.runtimeDetails = details;
            else
                root.runtimeDetailsError = errorMessage;
        });
    }

    function releaseRuntimeDetails() {
        ++root._runtimeRequestGeneration;
        root._queuedRuntimeRequest = null;
        root.runtimeDetailsLoading = false;
        root.runtimeDetailsError = "";
        root.runtimeDetails = {
        };
        NetworkManagerExtras.cancelRuntimeDetails();
    }

    function _finishAddWifi(success, result, message) {
        if (!root._addWifiPending)
            return ;

        root._addWifiPending = false;
        root._addWifiUsesNative = false;
        root._addWifiTarget = null;
        root.addWifiFinished(success, result, String(message || ""));
    }

    function addWifiNetwork(ssid, hidden, secure, password) {
        const normalizedSsid = String(ssid || "");
        const secret = String(password || "");
        const validSecret = !secure || (secret.length >= 8 && secret.length <= 63) || (/^[0-9A-Fa-f]{64}$/.test(secret));
        if (root._addWifiPending) {
            root.addWifiFinished(false, null, qsTr("另一项添加操作仍在进行"));
            return false;
        }
        if (normalizedSsid.length === 0 || normalizedSsid.indexOf("\0") >= 0 || root._utf8Length(normalizedSsid) > 32) {
            root.addWifiFinished(false, null, qsTr("SSID 必须是 1 至 32 个 UTF-8 字节"));
            return false;
        }
        if (!validSecret) {
            root.addWifiFinished(false, null, qsTr("Wi-Fi 密码格式无效"));
            return false;
        }
        const matches = root.nearbyWifiNetworks.filter((network) => {
            return network.ssid === normalizedSsid;
        });
        if (!hidden && matches.length > 1) {
            root.addWifiFinished(false, null, qsTr("多个 Wi-Fi 设备发现了同名网络，请从附近网络列表选择具体设备"));
            return false;
        }
        root._addWifiPending = true;
        if (!hidden && matches.length === 1) {
            const match = matches[0];
            const matchSecretValid = !match.isSecure || (secret.length >= 8 && secret.length <= 63) || (/^[0-9A-Fa-f]{64}$/.test(secret));
            if (!matchSecretValid) {
                root.addWifiFinished(false, null, qsTr("该网络需要有效的 Wi-Fi 密码"));
                return false;
            }
            root._addWifiUsesNative = true;
            root._addWifiTarget = match;
            root.connectNetwork(match, match.isSecure ? {
                "password": secret
            } : null);
            return true;
        }
        root._addWifiUsesNative = false;
        const started = NetworkManagerExtras.createHiddenWifi(normalizedSsid, hidden, secure, secret, (success, result, message) => {
            root._finishAddWifi(success, result, message);
        });
        if (!started)
            root._finishAddWifi(false, null, NetworkManagerExtras.lastError || qsTr("无法创建 Wi-Fi 配置"));

        return started;
    }

    function connectProfile(profile) {
        if (!profile || !profile.nativeNetwork || !profile.nativeSettings) {
            root.lastError = qsTr("该 NetworkManager 配置当前无法连接");
            root.operationFailed("connect", root.lastError);
            return false;
        }
        if (!root._beginOperation("connect", profile.nativeNetwork, profile.ssid || profile.name))
            return false;

        root.connectTargetSsid = String(profile.ssid || "");
        root.connectTargetDeviceName = String(profile.deviceName || "");
        profile.nativeNetwork.connectWithSettings(profile.nativeSettings);
        return true;
    }

    function savedConnectionForSsid(ssid) {
        return root.savedWifiConnections.find((connection) => {
            return connection.ssid === ssid;
        }) || null;
    }

    function connectHiddenNetwork(ssid, credentials) {
        const values = credentials || {
        };
        return root.addWifiNetwork(ssid, true, values.secure !== false, String(values.password || ""));
    }

    function recheckConnectivity() {
        if (!root.canCheckConnectivity || !root.connectivityCheckEnabled) {
            root.lastError = qsTr("NetworkManager 连接性检查不可用或未启用");
            root.operationFailed("check-connectivity", root.lastError);
            return ;
        }
        root.lastError = "";
        Networking.checkConnectivity();
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]);
    }

    Component.onCompleted: root._applyScanning()
    Component.onDestruction: {
        for (const device of root._nativeWifiDevices) {
            if (device && device.scannerEnabled)
                device.scannerEnabled = false;

        }
    }

    Connections {
        function onBusyChanged() {
            if (!NetworkManagerExtras.busy)
                root._startRuntimeRequest();

        }

        target: NetworkManagerExtras
    }

    Connections {
        function onOperationSucceeded(operation) {
            if (operation === "connect" && root._addWifiPending && root._addWifiUsesNative)
                root._finishAddWifi(true, root._addWifiTarget, "");

        }

        function onOperationFailed(operation, message) {
            if (operation === "connect" && root._addWifiPending && root._addWifiUsesNative)
                root._finishAddWifi(false, null, message);

        }

        target: root
    }

    Connections {
        function onSavedWifiProfilesChanged() {
            if (!root._pendingForgetSettings || root.savedWifiProfiles.some((profile) => {
                return profile.uuid === root._pendingForgetUuid;
            }))
                return ;

            const uuid = root._pendingForgetUuid;
            profileForgetTimeout.stop();
            root._pendingForgetSettings = null;
            root._pendingForgetUuid = "";
            root.profileForgetSucceeded(uuid);
        }

        target: root
    }

    Connections {
        function onWifiEnabledChanged() {
            root._applyScanning();
            if (root._pendingOperation === "set-wifi-enabled" && root.wifiEnabled === root._pendingWifiState)
                root._finishOperationSucceeded();

        }

        target: Networking
    }

    Connections {
        function onValuesChanged() {
            Qt.callLater(root._applyScanning);
        }

        target: Networking.devices
    }

    Connections {
        function onConnectionFailed(reason) {
            if (root._pendingOperation !== "connect")
                return ;

            let message = ConnectionFailReason.toString(reason);
            if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout) {
                message = root._pendingWithPsk ? qsTr("密码错误或认证超时") : qsTr("网络需要密码");
                if (root._pendingSsid.length > 0) {
                    root.passwordRequestSsid = root._pendingSsid;
                    root.passwordRequestDeviceName = root.connectTargetDeviceName;
                }
            }
            root._finishOperationFailed(message);
        }

        function onConnectedChanged() {
            if (root._pendingOperation === "connect" && root._pendingNetwork.connected)
                root._finishOperationSucceeded();
            else if (root._pendingOperation === "disconnect" && !root._pendingNetwork.connected)
                root._finishOperationSucceeded();
        }

        function onKnownChanged() {
            if (root._pendingOperation === "forget" && !root._pendingNetwork.known)
                root._finishOperationSucceeded();

        }

        function onStateChanged() {
            if (!root._pendingNetwork)
                return ;

            if (root._pendingNetwork.stateChanging)
                root._pendingStateWasChanging = true;

            if (root._pendingOperation === "connect" && root._pendingStateWasChanging && root._pendingNetwork.state === ConnectionState.Disconnected)
                root._finishOperationFailed(qsTr("连接未完成"));

        }

        target: root._pendingNetwork
        enabled: root._pendingNetwork !== null
    }

    Connections {
        function onSettingsChanged() {
            const uuid = root._pendingProfileUuid;
            if (!root._profileMatchesExpected(root._pendingSettings, root._pendingProfileExpected))
                return ;

            profileWriteTimeout.stop();
            root._pendingSettings = null;
            root._pendingProfileUuid = "";
            root._pendingProfileExpected = null;
            root.profileWriteSucceeded(uuid);
        }

        target: root._pendingSettings
        enabled: root._pendingSettings !== null
    }

    Timer {
        id: profileWriteTimeout

        interval: 10000
        repeat: false
        onTriggered: {
            const uuid = root._pendingProfileUuid;
            root._pendingSettings = null;
            root._pendingProfileUuid = "";
            root._pendingProfileExpected = null;
            root.profileWriteFailed(uuid, qsTr("NetworkManager 未确认配置写入"));
        }
    }

    Timer {
        id: profileForgetTimeout

        interval: 10000
        repeat: false
        onTriggered: {
            const uuid = root._pendingForgetUuid;
            root._pendingForgetSettings = null;
            root._pendingForgetUuid = "";
            root.profileForgetFailed(uuid, qsTr("NetworkManager 未确认配置删除"));
        }
    }

    Timer {
        id: manualScanReleaseTimer

        interval: 15000
        repeat: false
        onTriggered: {
            root._manualScanActive = false;
            root._applyScanning();
        }
    }

    Timer {
        id: operationTimeout

        interval: 60000
        repeat: false
        onTriggered: root._finishOperationFailed(qsTr("网络操作超时"))
    }

}
