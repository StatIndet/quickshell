pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string commandName: Quickshell.env("CLAVIS_RCLONE") || "rclone"
    property bool available: false
    property bool remotesLoading: false
    property var remotes: []
    property string selectedRemoteName: ""
    readonly property var selectedRemote: remoteByName(selectedRemoteName)
    property string quotaState: "idle"
    property string quotaMessage: ""
    property real totalBytes: -1
    property real usedBytes: -1
    property real freeBytes: -1
    readonly property bool quotaAvailable: quotaState === "ready" && totalBytes > 0 && usedBytes >= 0
    readonly property real usageRatio: quotaAvailable ? Math.max(0, Math.min(1, usedBytes / totalBytes)) : 0
    property string backupState: "idle"
    property string backupPhase: ""
    property string backupMessage: ""
    property string backupSource: ""
    property string backupDestination: ""
    property int backupCurrentIndex: 0
    property int backupTotalCount: 0
    property real backupBytes: 0
    property real backupTotalBytes: -1
    property real backupSpeed: -1
    property real backupEtaSeconds: -1
    property int backupTransfers: 0
    property int backupTotalTransfers: -1
    property int backupChecks: 0
    property int backupTotalChecks: -1
    property int backupErrors: 0
    property int backupListed: 0
    property var backupTransferring: []
    property real backupElapsedSeconds: 0
    property real backupCompletedBytes: 0
    property int backupCompletedTransfers: 0
    property string backupErrorMessage: ""
    readonly property bool backupActive: backupState === "running" || backupState === "stopping"
    readonly property real backupProgress: backupPhase === "transferring" && backupTotalBytes > 0 ? Math.max(0, Math.min(1, backupBytes / backupTotalBytes)) : -1
    readonly property string backupCurrentFolderName: basename(backupSource)
    readonly property string backupCurrentFileName: backupTransferring.length > 0 ? String(backupTransferring[0].name || "") : ""
    property string _remotesOutput: ""
    property string _quotaOutput: ""
    property var _backupQueue: []
    property int _backupQueueIndex: 0
    property string _backupVersionStamp: ""
    property string _backupRemoteName: ""
    property string _backupLastError: ""
    property bool _cancelRequested: false
    property real _backupStartedAtMs: 0

    function remoteByName(name) {
        for (let index = 0; index < root.remotes.length; ++index) {
            if (root.remotes[index].name === name)
                return root.remotes[index];

        }
        return null;
    }

    function isReadOnly(remote) {
        if (!remote)
            return true;

        return ["http"].indexOf(String(remote.type || "").toLowerCase()) >= 0;
    }

    function normalizeRemoteName(name) {
        return String(name || "").replace(/:+$/, "");
    }

    function basename(path) {
        const value = String(path || "").replace(/\/+$/, "");
        const index = value.lastIndexOf("/");
        return index >= 0 ? value.substring(index + 1) : value;
    }

    function safePathSegment(value) {
        const normalized = String(value || "").replace(/[\\/:*?"<>|]/g, "_").replace(/^\.+$/, "_").trim();
        return normalized || qsTr("备份");
    }

    function stablePathHash(path) {
        const value = String(path || "");
        let hash = 2.16614e+09;
        for (let index = 0; index < value.length; ++index) {
            hash ^= value.charCodeAt(index);
            hash = Math.imul(hash, 1.67776e+07);
        }
        return (hash >>> 0).toString(16).padStart(8, "0");
    }

    function normalizedFolderPaths(paths) {
        const result = [];
        const seen = {
        };
        for (const path of paths || []) {
            const normalized = String(path || "").trim().replace(/\/+$/, "");
            if (!normalized.startsWith("/") || normalized === "" || normalized === "/" || seen[normalized])
                continue;

            seen[normalized] = true;
            result.push(normalized);
        }
        return result;
    }

    function selectRemote(name) {
        const normalized = normalizeRemoteName(name);
        if (!remoteByName(normalized))
            return false;

        if (selectedRemoteName === normalized)
            return true;

        selectedRemoteName = normalized;
        refreshQuota();
        return true;
    }

    function refreshRemotes() {
        if (remoteListProcess.running)
            return ;

        remotesLoading = true;
        _remotesOutput = "";
        remoteListProcess.command = [commandName, "listremotes", "--json"];
        remoteListProcess.running = true;
        remoteTimeout.restart();
    }

    function refreshQuota() {
        if (!selectedRemote || quotaProcess.running)
            return ;

        quotaState = "loading";
        quotaMessage = "";
        totalBytes = -1;
        usedBytes = -1;
        freeBytes = -1;
        _quotaOutput = "";
        quotaProcess.command = [commandName, "about", selectedRemoteName + ":", "--json"];
        quotaProcess.running = true;
        quotaTimeout.restart();
    }

    function clearCompletedBackupStatus() {
        if (backupActive)
            return ;

        backupState = "idle";
        backupPhase = "";
        backupMessage = "";
        backupSource = "";
        backupDestination = "";
        backupCurrentIndex = 0;
        backupTotalCount = 0;
        resetCurrentFolderStats();
        backupElapsedSeconds = 0;
        backupCompletedBytes = 0;
        backupCompletedTransfers = 0;
        backupErrorMessage = "";
        _backupQueue = [];
        _backupQueueIndex = 0;
        _backupVersionStamp = "";
        _backupRemoteName = "";
        _backupLastError = "";
        _cancelRequested = false;
        _backupStartedAtMs = 0;
    }

    function refreshCard() {
        refreshQuota();
    }

    function backupFolders(paths) {
        const sources = normalizedFolderPaths(paths);
        return beginBackup(sources, selectedRemoteName);
    }

    function beginBackup(sources, remoteName) {
        const remote = remoteByName(remoteName);
        if (backupActive || backupProcess.running || sources.length === 0 || !remote)
            return false;

        if (isReadOnly(remote)) {
            backupState = "error";
            backupPhase = "";
            backupMessage = qsTr("所选云存储为只读服务");
            backupErrorMessage = backupMessage;
            return false;
        }
        _backupQueue = sources.slice();
        _backupQueueIndex = 0;
        _backupVersionStamp = new Date().toISOString().replace(/[:.]/g, "-");
        _backupRemoteName = normalizeRemoteName(remoteName);
        _backupStartedAtMs = Date.now();
        _cancelRequested = false;
        _backupLastError = "";
        backupCurrentIndex = 1;
        backupTotalCount = sources.length;
        backupCompletedBytes = 0;
        backupCompletedTransfers = 0;
        backupElapsedSeconds = 0;
        backupErrorMessage = "";
        backupState = "running";
        backupPhase = "preparing";
        backupMessage = qsTr("正在准备备份");
        resetCurrentFolderStats();
        startNextBackupFolder();
        return true;
    }

    function backup(path, isDirectory) {
        if (!isDirectory) {
            backupState = "error";
            backupMessage = qsTr("电脑备份仅支持文件夹");
            return false;
        }
        return backupFolders([path]);
    }

    function restartBackup() {
        if (backupActive || _backupQueue.length === 0 || _backupRemoteName === "")
            return false;

        return beginBackup(_backupQueue.slice(), _backupRemoteName);
    }

    function stopBackup() {
        if (backupState !== "running")
            return false;

        _cancelRequested = true;
        backupState = "stopping";
        backupMessage = qsTr("正在停止备份…");
        if (backupProcess.running)
            backupProcess.signal(2);
        else
            finishCancelled();
        return true;
    }

    function resetCurrentFolderStats() {
        backupBytes = 0;
        backupTotalBytes = -1;
        backupSpeed = -1;
        backupEtaSeconds = -1;
        backupTransfers = 0;
        backupTotalTransfers = -1;
        backupChecks = 0;
        backupTotalChecks = -1;
        backupErrors = 0;
        backupListed = 0;
        backupTransferring = [];
    }

    function updateElapsedTime() {
        backupElapsedSeconds = _backupStartedAtMs > 0 ? Math.max(0, (Date.now() - _backupStartedAtMs) / 1000) : 0;
    }

    function finishCancelled() {
        updateElapsedTime();
        backupState = "cancelled";
        backupMessage = qsTr("备份已停止");
        backupTransferring = [];
    }

    function finishError() {
        updateElapsedTime();
        backupState = "error";
        backupErrorMessage = _backupLastError !== "" ? _backupLastError : qsTr("请检查网络和远程权限");
        backupMessage = qsTr("备份 %1 失败：%2").arg(basename(backupSource)).arg(backupErrorMessage);
        backupTransferring = [];
    }

    function finishSuccess() {
        updateElapsedTime();
        backupState = "success";
        backupMessage = qsTr("备份已完成，共备份 %1 个文件夹").arg(backupTotalCount);
        backupTransferring = [];
        refreshQuota();
    }

    function startNextBackupFolder() {
        if (backupState !== "running")
            return ;

        if (_backupQueueIndex >= _backupQueue.length) {
            finishSuccess();
            return ;
        }
        const source = _backupQueue[_backupQueueIndex];
        const sourceName = safePathSegment(basename(source));
        const destinationName = sourceName + "-" + stablePathHash(source);
        const hostName = safePathSegment(SystemIdentityService.hostName);
        const destinationRoot = _backupRemoteName + ":Clavis Backups/" + hostName + "/current/" + destinationName;
        const historyRoot = _backupRemoteName + ":Clavis Backups/" + hostName + "/versions/" + _backupVersionStamp + "/" + destinationName;
        const command = [commandName, "sync", source, destinationRoot];
        command.push("--backup-dir", historyRoot, "--create-empty-src-dirs", "--check-first", "--stats=1s", "--stats-log-level=NOTICE", "--use-json-log");
        backupSource = source;
        backupDestination = destinationRoot;
        backupCurrentIndex = _backupQueueIndex + 1;
        backupPhase = "preparing";
        backupMessage = qsTr("正在准备 %1（%2/%3）").arg(sourceName).arg(backupCurrentIndex).arg(backupTotalCount);
        _backupLastError = "";
        resetCurrentFolderStats();
        backupProcess.command = command;
        backupProcess.running = true;
    }

    function numberOr(value, fallback) {
        if (value === null || value === undefined || value === "")
            return fallback;

        const number = Number(value);
        return isFinite(number) ? number : fallback;
    }

    function usefulError(value) {
        const firstLine = String(value || "").trim().split("\n")[0];
        return firstLine.length > 360 ? firstLine.substring(0, 357) + "…" : firstLine;
    }

    function updateBackupStats(stats) {
        backupBytes = Math.max(0, numberOr(stats.bytes, 0));
        backupTotalBytes = numberOr(stats.totalBytes, -1);
        backupSpeed = numberOr(stats.speed, -1);
        backupEtaSeconds = numberOr(stats.eta, -1);
        backupTransfers = Math.max(0, Math.round(numberOr(stats.transfers, 0)));
        backupTotalTransfers = Math.round(numberOr(stats.totalTransfers, -1));
        backupChecks = Math.max(0, Math.round(numberOr(stats.checks, 0)));
        backupTotalChecks = Math.round(numberOr(stats.totalChecks, -1));
        backupErrors = Math.max(0, Math.round(numberOr(stats.errors, 0)));
        backupListed = Math.max(0, Math.round(numberOr(stats.listed, 0)));
        const transferring = Array.isArray(stats.transferring) ? stats.transferring : [];
        backupTransferring = transferring.map((item) => {
            return ({
                "name": String(item && item.name || ""),
                "bytes": numberOr(item && item.bytes, -1),
                "size": numberOr(item && item.size, -1),
                "percentage": numberOr(item && item.percentage, -1),
                "speed": numberOr(item && item.speed, -1),
                "eta": numberOr(item && item.eta, -1)
            });
        });
        if (backupState === "running") {
            const transferStarted = backupTransferring.length > 0 || backupBytes > 0 || backupTransfers > 0;
            backupPhase = transferStarted ? "transferring" : "checking";
            backupMessage = transferStarted ? qsTr("正在备份 %1（%2/%3）").arg(backupCurrentFolderName).arg(backupCurrentIndex).arg(backupTotalCount) : qsTr("正在检查 %1（%2/%3）").arg(backupCurrentFolderName).arg(backupCurrentIndex).arg(backupTotalCount);
        }
        updateElapsedTime();
    }

    function consumeBackupLine(line) {
        const value = String(line || "").trim();
        if (value === "")
            return ;

        if (value.charAt(0) !== "{") {
            _backupLastError = usefulError(value);
            return ;
        }
        try {
            const parsed = JSON.parse(value);
            if (parsed.stats && typeof parsed.stats === "object")
                updateBackupStats(parsed.stats);

            const level = String(parsed.level || "").toLowerCase();
            if (level === "error" || level === "critical")
                _backupLastError = usefulError(parsed.error || parsed.msg);

        } catch (error) {
        }
    }

    Component.onCompleted: refreshRemotes()

    Process {
        id: remoteListProcess

        onExited: (exitCode) => {
            remoteTimeout.stop();
            root.remotesLoading = false;
            root.available = exitCode === 0;
            if (exitCode !== 0) {
                root.remotes = [];
                root.selectedRemoteName = "";
                root.quotaState = "error";
                root.quotaMessage = qsTr("无法读取 rclone 配置");
                return ;
            }
            try {
                const parsed = JSON.parse(root._remotesOutput || "[]");
                root.remotes = Array.isArray(parsed) ? parsed.map((item) => {
                    return ({
                        "name": root.normalizeRemoteName(item.name),
                        "type": String(item.type || ""),
                        "description": String(item.description || "")
                    });
                }) : [];
            } catch (error) {
                root.remotes = [];
                root.quotaState = "error";
                root.quotaMessage = qsTr("rclone 返回了无效的 remote 列表");
            }
            if (root.remotes.length === 0) {
                root.selectedRemoteName = "";
                root.quotaState = "unavailable";
                root.quotaMessage = qsTr("尚未配置云存储");
                return ;
            }
            const currentStillExists = root.remoteByName(root.selectedRemoteName);
            if (!currentStillExists) {
                const preferred = root.remoteByName("gdrive");
                root.selectedRemoteName = preferred ? preferred.name : root.remotes[0].name;
            }
            root.refreshQuota();
        }

        stdout: StdioCollector {
            onStreamFinished: root._remotesOutput = this.text
        }

    }

    Process {
        id: quotaProcess

        onExited: (exitCode) => {
            quotaTimeout.stop();
            if (exitCode !== 0) {
                root.quotaState = "unavailable";
                root.quotaMessage = qsTr("此云存储暂不提供容量信息");
                return ;
            }
            try {
                const parsed = JSON.parse(root._quotaOutput || "{}");
                const total = Number(parsed.total);
                const used = Number(parsed.used);
                const free = Number(parsed.free);
                root.totalBytes = isFinite(total) ? total : -1;
                root.usedBytes = isFinite(used) ? used : -1;
                root.freeBytes = isFinite(free) ? free : -1;
                if (root.totalBytes > 0 && root.usedBytes >= 0) {
                    root.quotaState = "ready";
                    root.quotaMessage = "";
                } else {
                    root.quotaState = "unavailable";
                    root.quotaMessage = qsTr("此云存储未报告总容量");
                }
            } catch (error) {
                root.quotaState = "error";
                root.quotaMessage = qsTr("无法解析云存储容量");
            }
        }

        stdout: StdioCollector {
            onStreamFinished: root._quotaOutput = this.text
        }

    }

    Process {
        id: backupProcess

        onExited: (exitCode) => {
            if (root._cancelRequested) {
                root.finishCancelled();
                return ;
            }
            if (exitCode !== 0) {
                root.finishError();
                return ;
            }
            root.backupCompletedBytes += Math.max(0, root.backupBytes);
            root.backupCompletedTransfers += Math.max(0, root.backupTransfers);
            root._backupQueueIndex += 1;
            Qt.callLater(root.startNextBackupFolder);
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                return root.consumeBackupLine(line);
            }
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                return root.consumeBackupLine(line);
            }
        }

    }

    Timer {
        id: remoteTimeout

        interval: 10000
        onTriggered: {
            if (remoteListProcess.running)
                remoteListProcess.signal(15);

        }
    }

    Timer {
        id: quotaTimeout

        interval: 20000
        onTriggered: {
            if (quotaProcess.running)
                quotaProcess.signal(15);

        }
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.selectedRemoteName !== ""
        onTriggered: root.refreshQuota()
    }

}
