pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool runtimeBusy: runtimeProcess.running || frequencyProcess.running
    readonly property bool mutationBusy: addProcess.running || activateProcess.running || cleanupProcess.running
    readonly property bool busy: runtimeBusy || mutationBusy
    property string lastError: ""
    property string _runtimeInterface: ""
    property bool _runtimeIsWifi: false
    property var _runtimeCallback: null
    property var _runtimeDetails: null
    property bool _runtimeStarted: false
    property bool _frequencyStarted: false
    property var _addCallback: null
    property string _connectionName: ""
    property string _ssid: ""
    property string _password: ""
    property bool _secure: false
    property bool _addStarted: false
    property bool _activateStarted: false

    function _unescape(value) {
        return String(value || "").replace(/\\:/g, ":").replace(/\\\\/g, "\\");
    }

    function _error(stderrText, fallback) {
        const message = String(stderrText || "").trim();
        return message.length > 0 ? message : fallback;
    }

    function queryRuntimeDetails(interfaceName, isWifi, callback) {
        if (root.busy || String(interfaceName || "").length === 0) {
            if (callback)
                callback(false, {
            }, qsTr("网络详情查询当前不可用"));

            return false;
        }
        root.lastError = "";
        root._runtimeInterface = String(interfaceName);
        root._runtimeIsWifi = !!isWifi;
        root._runtimeCallback = callback;
        root._runtimeDetails = null;
        root._runtimeStarted = false;
        runtimeProcess.command = ["nmcli", "-t", "-e", "yes", "-f", "GENERAL.CONNECTION,GENERAL.CON-UUID,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", root._runtimeInterface];
        runtimeProcess.running = true;
        return true;
    }

    function cancelRuntimeDetails() {
        root._runtimeCallback = null;
        root._runtimeDetails = null;
        root._runtimeStarted = false;
        root._frequencyStarted = false;
        runtimeProcess.running = false;
        frequencyProcess.running = false;
        runtimeProcess.command = [];
        frequencyProcess.command = [];
    }

    function createHiddenWifi(ssid, hidden, secure, password, callback) {
        if (root.busy) {
            if (callback)
                callback(false, null, qsTr("另一项补充网络操作仍在进行"));

            return false;
        }
        root.lastError = "";
        root._ssid = String(ssid || "").trim();
        root._connectionName = "Clavis Wi-Fi " + Date.now();
        root._secure = !!secure;
        root._password = root._secure ? String(password || "") : "";
        root._addCallback = callback;
        root._addStarted = false;
        const args = ["nmcli", "--wait", "30", "connection", "add", "type", "wifi", "con-name", root._connectionName, "ifname", "*", "ssid", root._ssid, "--", "802-11-wireless.hidden", hidden ? "yes" : "no"];
        if (root._secure)
            args.push("802-11-wireless-security.key-mgmt", "wpa-psk");

        addProcess.command = args;
        addProcess.running = true;
        return true;
    }

    function _finishAdd(success, errorMessage) {
        const callback = root._addCallback;
        const result = success ? ({
            "id": root._connectionName,
            "ssid": root._ssid
        }) : null;
        root.lastError = success ? "" : String(errorMessage || qsTr("无法创建 Wi-Fi 配置"));
        root._addCallback = null;
        root._password = "";
        root._secure = false;
        addProcess.command = [];
        activateProcess.command = [];
        if (callback)
            callback(success, result, root.lastError);

    }

    function _cleanupAdd(errorMessage) {
        cleanupProcess.command = ["nmcli", "--wait", "15", "connection", "delete", "id", root._connectionName];
        cleanupProcess.running = true;
        root._finishAdd(false, errorMessage);
    }

    Process {
        id: runtimeProcess

        onStarted: root._runtimeStarted = true
        onRunningChanged: {
            if (!running && !root._runtimeStarted && root._runtimeCallback) {
                const callback = root._runtimeCallback;
                root._runtimeCallback = null;
                root.lastError = qsTr("nmcli 不可用，无法读取活动 IPv4 信息");
                callback(false, {
                }, root.lastError);
            }
        }
        onExited: (exitCode) => {
            const callback = root._runtimeCallback;
            if (!callback)
                return ;

            if (exitCode !== 0) {
                root._runtimeCallback = null;
                root.lastError = root._error(runtimeError.text, qsTr("无法读取活动 IPv4 信息"));
                callback(false, {
                }, root.lastError);
                return ;
            }
            const details = ({
                "interfaceName": root._runtimeInterface,
                "connectionName": "",
                "connectionUuid": "",
                "addresses": [],
                "gateway": "",
                "dns": []
            });
            for (const rawLine of String(runtimeOutput.text || "").trim().split("\n")) {
                const separator = rawLine.indexOf(":");
                if (separator < 0)
                    continue;

                const key = rawLine.substring(0, separator);
                const value = root._unescape(rawLine.substring(separator + 1));
                if (key === "GENERAL.CONNECTION")
                    details.connectionName = value;
                else if (key === "GENERAL.CON-UUID")
                    details.connectionUuid = value;
                else if (key.startsWith("IP4.ADDRESS"))
                    details.addresses.push(value);
                else if (key === "IP4.GATEWAY")
                    details.gateway = value;
                else if (key.startsWith("IP4.DNS"))
                    details.dns.push(value);
            }
            if (root._runtimeIsWifi) {
                root._runtimeDetails = details;
                root._frequencyStarted = false;
                frequencyProcess.command = ["nmcli", "-t", "-e", "yes", "-f", "IN-USE,FREQ", "device", "wifi", "list", "ifname", root._runtimeInterface];
                frequencyProcess.running = true;
            } else {
                root._runtimeCallback = null;
                root.lastError = "";
                callback(true, details, "");
            }
        }

        stdout: StdioCollector {
            id: runtimeOutput
        }

        stderr: StdioCollector {
            id: runtimeError
        }

    }

    Process {
        id: frequencyProcess

        onStarted: root._frequencyStarted = true
        onRunningChanged: {
            if (!running && !root._frequencyStarted && root._runtimeCallback) {
                const callback = root._runtimeCallback;
                const details = root._runtimeDetails || {
                };
                root._runtimeCallback = null;
                root._runtimeDetails = null;
                callback(true, details, "");
            }
        }
        onExited: (exitCode) => {
            const callback = root._runtimeCallback;
            root._runtimeCallback = null;
            const details = root._runtimeDetails || {
            };
            root._runtimeDetails = null;
            if (exitCode === 0) {
                for (const line of String(frequencyOutput.text || "").trim().split("\n")) {
                    const separator = line.indexOf(":");
                    if (separator < 0 || line.substring(0, separator) !== "*")
                        continue;

                    details.frequency = root._unescape(line.substring(separator + 1));
                    break;
                }
            }
            root.lastError = "";
            if (callback)
                callback(true, details, "");

        }

        stdout: StdioCollector {
            id: frequencyOutput
        }

    }

    Process {
        id: addProcess

        onStarted: root._addStarted = true
        onRunningChanged: {
            if (!running && !root._addStarted && root._addCallback)
                root._finishAdd(false, qsTr("nmcli 不可用，无法创建隐藏网络配置"));

        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root._finishAdd(false, root._error(addError.text, qsTr("无法创建 Wi-Fi 配置")));
                return ;
            }
            root._activateStarted = false;
            activateProcess.command = root._secure ? ["nmcli", "--ask", "--wait", "60", "connection", "up", "id", root._connectionName] : ["nmcli", "--wait", "60", "connection", "up", "id", root._connectionName];
            activateProcess.running = true;
        }

        stderr: StdioCollector {
            id: addError
        }

    }

    Process {
        id: activateProcess

        stdinEnabled: true
        onStarted: {
            root._activateStarted = true;
            if (root._secure) {
                const secret = root._password;
                root._password = "";
                activateProcess.write(secret + "\n");
            }
        }
        onRunningChanged: {
            if (!running && !root._activateStarted && root._addCallback)
                root._cleanupAdd(qsTr("nmcli 不可用，无法激活隐藏网络配置"));

        }
        onExited: (exitCode) => {
            root._password = "";
            if (exitCode === 0)
                root._finishAdd(true, "");
            else
                root._cleanupAdd(root._error(activateError.text, qsTr("Wi-Fi 配置已创建，但无法激活")));
        }

        stdout: StdioCollector {
        }

        stderr: StdioCollector {
            id: activateError
        }

    }

    Process {
        id: cleanupProcess
    }

}
