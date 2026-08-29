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
    property string backupMessage: ""
    property real backupProgress: -1
    property string backupSource: ""
    property string backupDestination: ""
    property int backupCurrentIndex: 0
    property int backupTotalCount: 0
    property string _remotesOutput: ""
    property string _quotaOutput: ""
    property var _backupQueue: []
    property int _backupQueueIndex: 0
    property string _backupVersionStamp: ""
    property string _backupRemoteName: ""
    property real _currentFolderProgress: -1
    property string _backupLastError: ""

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
        if (backupState === "running")
            return ;

        backupState = "idle";
        backupMessage = "";
        backupProgress = -1;
        backupSource = "";
        backupDestination = "";
        backupCurrentIndex = 0;
        backupTotalCount = 0;
        _backupQueue = [];
        _backupQueueIndex = 0;
        _backupVersionStamp = "";
        _backupRemoteName = "";
        _currentFolderProgress = -1;
        _backupLastError = "";
    }

    function refreshCard() {
        clearCompletedBackupStatus();
        refreshQuota();
    }

    function backupFolders(paths) {
        const sources = normalizedFolderPaths(paths);
        const remote = selectedRemote;
        if (backupProcess.running || sources.length === 0 || !remote)
            return false;

        if (isReadOnly(remote)) {
            backupState = "error";
            backupMessage = qsTr("所选云存储为只读服务");
            return false;
        }
        _backupQueue = sources;
        _backupQueueIndex = 0;
        _backupVersionStamp = new Date().toISOString().replace(/[:.]/g, "-");
        _backupRemoteName = selectedRemoteName;
        backupCurrentIndex = 1;
        backupTotalCount = sources.length;
        backupState = "running";
        backupProgress = -1;
        _backupLastError = "";
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

    function startNextBackupFolder() {
        if (_backupQueueIndex >= _backupQueue.length) {
            backupProgress = 1;
            backupState = "success";
            backupMessage = qsTr("备份已完成，共备份 %1 个文件夹").arg(backupTotalCount);
            refreshQuota();
            return ;
        }
        const source = _backupQueue[_backupQueueIndex];
        const sourceName = safePathSegment(basename(source));
        const destinationName = sourceName + "-" + stablePathHash(source);
        const hostName = safePathSegment(SystemIdentityService.hostName);
        const destinationRoot = _backupRemoteName + ":Clavis Backups/" + hostName + "/current/" + destinationName;
        const historyRoot = _backupRemoteName + ":Clavis Backups/" + hostName + "/versions/" + _backupVersionStamp + "/" + destinationName;
        const command = [commandName, "sync", source, destinationRoot];
        command.push("--backup-dir", historyRoot, "--create-empty-src-dirs", "--stats=1s", "--stats-log-level=NOTICE", "--use-json-log");
        backupSource = source;
        backupDestination = destinationRoot;
        backupCurrentIndex = _backupQueueIndex + 1;
        _currentFolderProgress = -1;
        updateAggregateProgress();
        backupMessage = qsTr("正在备份 %1（%2/%3）").arg(sourceName).arg(backupCurrentIndex).arg(backupTotalCount);
        backupProcess.command = command;
        backupProcess.running = true;
    }

    function updateAggregateProgress() {
        if (backupTotalCount <= 0) {
            backupProgress = -1;
            return ;
        }
        if (_currentFolderProgress < 0) {
            backupProgress = _backupQueueIndex > 0 ? _backupQueueIndex / backupTotalCount : -1;
            return ;
        }
        backupProgress = Math.max(0, Math.min(1, (_backupQueueIndex + _currentFolderProgress) / backupTotalCount));
    }

    function consumeBackupLine(line) {
        const value = String(line || "").trim();
        if (value === "")
            return ;

        if (value.charAt(0) !== "{") {
            _backupLastError = value;
            return ;
        }
        try {
            const parsed = JSON.parse(value);
            const stats = parsed.stats || parsed;
            const percentage = Number(stats.percentage);
            const bytes = Number(stats.bytes);
            const total = Number(stats.totalBytes);
            if (isFinite(percentage))
                _currentFolderProgress = Math.max(0, Math.min(1, percentage / 100));
            else if (isFinite(bytes) && isFinite(total) && total > 0)
                _currentFolderProgress = Math.max(0, Math.min(1, bytes / total));
            const level = String(parsed.level || "").toLowerCase();
            if ((level === "error" || level === "critical") && parsed.msg)
                _backupLastError = String(parsed.msg);

            updateAggregateProgress();
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
            if (exitCode !== 0) {
                root.backupState = "error";
                root.backupMessage = root._backupLastError !== "" ? qsTr("备份 %1 失败：%2").arg(root.basename(root.backupSource)).arg(root._backupLastError) : qsTr("备份 %1 失败，请检查网络和远程权限").arg(root.basename(root.backupSource));
                return ;
            }
            root._backupQueueIndex += 1;
            root._currentFolderProgress = 1;
            root.updateAggregateProgress();
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
