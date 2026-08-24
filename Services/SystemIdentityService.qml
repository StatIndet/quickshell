pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int supportedSchemaVersion: 1
    property string commandName: {
        const configured = String(Quickshell.env("CLAVIS_KEYTOP") || "").trim();
        return configured !== "" ? configured : "keytop";
    }
    property var system: ({
    })
    property bool ready: false
    property bool _initializationStarted: false
    property string errorMessage: ""
    property var _uptimeConsumers: ({
    })
    property real _baseUptimeSeconds: 0
    property real uptimeSeconds: 0
    property bool _uptimeBaseReady: false
    readonly property bool uptimeActive: Object.keys(_uptimeConsumers).length > 0
    readonly property string accountName: system.systemUser || "user"
    readonly property string hostName: system.hostName || "host"
    readonly property string accountIdentity: accountName + "@" + hostName
    readonly property string wmName: system.wmName || "unknown"
    readonly property string shellName: system.shellName || "unknown"
    readonly property string kernelRelease: system.kernel || "unknown"
    readonly property string architecture: system.architecture || "unknown"
    readonly property string chassis: system.chassis || qsTr("电脑")
    readonly property string vendor: system.vendor || ""
    readonly property string productName: system.productName || ""
    readonly property string boardName: system.boardName || ""
    readonly property string biosVersion: system.biosVersion || ""
    readonly property string cpuModelName: system.cpuModelName || ""
    readonly property int physicalCoreCount: Number(system.physicalCoreCount) || 0
    readonly property int logicalCpuCount: Number(system.logicalCpuCount) || 0
    readonly property real bootTimeMs: Number(system.bootTimeMs) || 0
    readonly property string osAgeText: system.osAgeText || ""
    readonly property string distroId: system.distroId || "linux"
    readonly property string distroName: system.osName || "Linux"
    readonly property string uptimeText: formatUptime(uptimeSeconds)

    function setUptimeConsumer(owner, active) {
        const key = String(owner || "").trim();
        if (key === "")
            return ;

        const next = Object.assign({
        }, root._uptimeConsumers);
        if (active)
            next[key] = true;
        else
            delete next[key];
        root._uptimeConsumers = next;
    }

    function _startUptimeSession() {
        root._uptimeBaseReady = false;
        root.uptimeSeconds = 0;
        uptimeFile.path = "";
        uptimeFile.path = "/proc/uptime";
    }

    function _finishUptimeRead() {
        const fields = String(uptimeFile.text() || "").trim().split(/\s+/);
        const value = Number(fields[0]);
        if (!isFinite(value) || value < 0)
            return ;

        root._baseUptimeSeconds = value;
        root.uptimeSeconds = value;
        root._uptimeBaseReady = true;
        monotonicTimer.restartMs();
    }

    function _updateUptime() {
        if (root._uptimeBaseReady)
            root.uptimeSeconds = root._baseUptimeSeconds + monotonicTimer.elapsedMs() / 1000;

    }

    function _consumeIdentity() {
        try {
            const payload = JSON.parse(identityOutput.text.trim());
            if (payload.schemaVersion !== root.supportedSchemaVersion || !payload.system || typeof payload.system !== "object")
                throw new Error("schemaVersion or system field is invalid");

            root.system = payload.system;
            root.ready = true;
            root.errorMessage = "";
        } catch (error) {
            root.errorMessage = qsTr("无法读取系统身份信息");
            console.warn("SystemIdentityService:", error);
        }
    }

    function initialize() {
        if (root._initializationStarted)
            return ;

        root._initializationStarted = true;
        identityProcess.command = [root.commandName, "value", "system", "--format", "json"];
        identityProcess.running = true;
    }

    function formatUptime(value) {
        const total = Math.max(0, Math.floor(Number(value) || 0));
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (days > 0)
            return qsTr("%1 天 %2 小时").arg(days).arg(hours);

        if (hours > 0)
            return qsTr("%1 小时 %2 分钟").arg(hours).arg(minutes);

        return qsTr("%1 分钟").arg(minutes);
    }

    onUptimeActiveChanged: {
        if (uptimeActive) {
            root._startUptimeSession();
        } else {
            root._uptimeBaseReady = false;
            uptimeFile.path = "";
        }
    }
    Component.onCompleted: root.initialize()

    ElapsedTimer {
        id: monotonicTimer
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.uptimeActive && root._uptimeBaseReady
        onTriggered: root._updateUptime()
    }

    FileView {
        id: uptimeFile

        path: ""
        watchChanges: false
        blockLoading: true
        onLoaded: root._finishUptimeRead()
        onLoadFailed: (error) => {
            return console.warn("SystemIdentityService /proc/uptime:", error);
        }
    }

    Process {
        id: identityProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root._consumeIdentity();
            else
                root.errorMessage = qsTr("无法读取系统身份信息");
        }

        stdout: StdioCollector {
            id: identityOutput
        }

        stderr: StdioCollector {
        }

    }

}
