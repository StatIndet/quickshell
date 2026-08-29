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
    property int remotesRevision: 0
    property string remotesError: ""
    property var providers: []
    property bool providersLoading: false
    property string providersError: ""
    property bool configBusy: false
    property string configState: "idle"
    property string configError: ""
    property var configQuestion: null
    property string configRemoteName: ""
    property string configRemoteType: ""
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
    property string _quotaRemoteName: ""
    property var _backupQueue: []
    property int _backupQueueIndex: 0
    property string _backupVersionStamp: ""
    property string _backupRemoteName: ""
    property string _backupRoot: ""
    property string _backupLastError: ""
    property bool _cancelRequested: false
    property real _backupStartedAtMs: 0
    property string _providersOutput: ""
    property string _providersErrorOutput: ""
    property string _configOutput: ""
    property string _configErrorOutput: ""
    property string _configOperation: ""
    property bool _configCancelRequested: false
    property bool _configCreatedRemote: false
    property string _pendingConfigFailure: ""
    property bool _remotesRefreshPending: false

    signal providersLoaded()
    signal providersLoadFailed(string message)
    signal configQuestionReady()
    signal configSucceeded(string remoteName, string remoteType)
    signal configFailed(string message)
    signal configCancelled()
    signal remoteDeleted(string remoteName)
    signal remoteDeleteFailed(string message)

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

    function writableRemotes() {
        return root.remotes.filter((remote) => {
            return !root.isReadOnly(remote);
        });
    }

    function providerByName(name) {
        const normalized = String(name || "").toLowerCase();
        for (const provider of root.providers) {
            if (String(provider && provider.Name || "").toLowerCase() === normalized)
                return provider;
        }
        return null;
    }

    function providerDisplayName(type, remoteName) {
        const normalizedType = String(type || "").toLowerCase();
        const normalizedName = String(remoteName || "").toLowerCase();
        if (normalizedType === "s3")
            return normalizedName.indexOf("r2") >= 0 || normalizedName.indexOf("cloudflare") >= 0
                ? "Cloudflare R2" : "Amazon S3";

        const provider = providerByName(type);
        if (provider && provider.Description)
            return String(provider.Description);

        switch (normalizedType) {
        case "drive": return "Google Drive";
        case "onedrive": return "Microsoft OneDrive";
        case "dropbox": return "Dropbox";
        case "webdav": return "WebDAV";
        case "sftp": return "SFTP";
        default: return String(type || qsTr("其他云存储"));
        }
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

    function reconcileDefaultRemote() {
        if (!UiPreferences.preferencesReady)
            return ;

        const preferredName = normalizeRemoteName(UiPreferences.cloudDefaultRemoteName);
        const preferred = remoteByName(preferredName);
        const fallback = writableRemotes().length > 0 ? writableRemotes()[0] : null;
        const nextName = preferred && !isReadOnly(preferred) ? preferred.name : fallback ? fallback.name : "";
        if (UiPreferences.cloudDefaultRemoteName !== nextName)
            UiPreferences.setCloudDefaultRemoteName(nextName);

        if (selectedRemoteName !== nextName) {
            selectedRemoteName = nextName;
            refreshQuota();
        } else if (nextName !== "" && quotaState === "idle") {
            refreshQuota();
        }
        if (nextName === "") {
            quotaState = "unavailable";
            quotaMessage = qsTr("尚未配置可写云存储");
        }
    }

    function setDefaultRemote(name) {
        const normalized = normalizeRemoteName(name);
        const remote = remoteByName(normalized);
        if (!remote || isReadOnly(remote))
            return false;

        UiPreferences.setCloudDefaultRemoteName(normalized);
        if (selectedRemoteName !== normalized) {
            selectedRemoteName = normalized;
            refreshQuota();
        }
        return true;
    }

    function selectRemote(name) {
        return setDefaultRemote(name);
    }

    function refreshRemotes() {
        if (remoteListProcess.running) {
            _remotesRefreshPending = true;
            return ;
        }

        remotesLoading = true;
        _remotesRefreshPending = false;
        remotesError = "";
        _remotesOutput = "";
        remoteListProcess.command = [commandName, "listremotes", "--json"];
        remoteListProcess.running = true;
        remoteTimeout.restart();
    }

    function loadProviders() {
        if (providersProcess.running)
            return ;

        providersLoading = true;
        providersError = "";
        _providersOutput = "";
        _providersErrorOutput = "";
        providersProcess.command = [commandName, "config", "providers"];
        providersProcess.running = true;
    }

    function validRemoteName(name) {
        const normalized = normalizeRemoteName(name).trim();
        return normalized !== "" && normalized.indexOf(":") < 0
            && normalized.indexOf("/") < 0 && normalized.indexOf("\\") < 0;
    }

    function startRemoteConfiguration(name, type) {
        const normalizedName = normalizeRemoteName(name).trim();
        const normalizedType = String(type || "").trim();
        if (configBusy || !validRemoteName(normalizedName) || remoteByName(normalizedName) || !providerByName(normalizedType))
            return false;

        configBusy = true;
        configState = "processing";
        configError = "";
        configQuestion = null;
        configRemoteName = normalizedName;
        configRemoteType = normalizedType;
        _configOperation = "create";
        _configCancelRequested = false;
        _configCreatedRemote = true;
        _pendingConfigFailure = "";
        _configOutput = "";
        _configErrorOutput = "";
        configProcess.command = [commandName, "config", "create", normalizedName, normalizedType, "--all", "--non-interactive"];
        configProcess.running = true;
        return true;
    }

    function answerConfigQuestion(stateToken, answer) {
        if (!configBusy || configProcess.running || configRemoteName === "" || String(stateToken || "") === "")
            return false;

        configState = "processing";
        configQuestion = null;
        _configOperation = "continue";
        _configOutput = "";
        _configErrorOutput = "";
        configProcess.command = [commandName, "config", "update", configRemoteName, "--continue", "--state", String(stateToken), "--result", String(answer), "--non-interactive"];
        configProcess.running = true;
        return true;
    }

    function deleteRemote(name) {
        const normalized = normalizeRemoteName(name);
        if (configBusy || backupActive || !remoteByName(normalized))
            return false;

        configBusy = true;
        configState = "deleting";
        configError = "";
        configRemoteName = normalized;
        configRemoteType = "";
        _configOperation = "delete";
        _configCancelRequested = false;
        _configCreatedRemote = false;
        _configOutput = "";
        _configErrorOutput = "";
        configProcess.command = [commandName, "config", "delete", normalized];
        configProcess.running = true;
        return true;
    }

    function cancelRemoteConfiguration() {
        if (!configBusy || (_configOperation !== "create" && _configOperation !== "continue"))
            return false;

        _configCancelRequested = true;
        configState = "cancelling";
        configQuestion = null;
        if (configProcess.running)
            configProcess.signal(2);
        else
            cleanupPartialRemote();
        return true;
    }

    function cleanupPartialRemote() {
        if (!_configCreatedRemote || configRemoteName === "") {
            finishConfigCancelled();
            return ;
        }
        _configOperation = "cleanup";
        _configOutput = "";
        _configErrorOutput = "";
        configProcess.command = [commandName, "config", "delete", configRemoteName];
        configProcess.running = true;
    }

    function finishConfigCancelled() {
        const pendingFailure = _pendingConfigFailure;
        configBusy = false;
        configState = pendingFailure === "" ? "idle" : "error";
        configError = pendingFailure;
        configQuestion = null;
        configRemoteName = "";
        configRemoteType = "";
        _configOperation = "";
        _configCancelRequested = false;
        _configCreatedRemote = false;
        _pendingConfigFailure = "";
        if (pendingFailure === "")
            configCancelled();
        else
            configFailed(pendingFailure);
        refreshRemotes();
    }

    function failConfiguration(message) {
        const useful = usefulError(message) || qsTr("rclone 配置失败");
        configBusy = false;
        configState = "error";
        configError = useful;
        configQuestion = null;
        _configOperation = "";
        _configCreatedRemote = false;
        configFailed(useful);
        refreshRemotes();
    }

    function consumeConfigResult() {
        let parsed = null;
        try {
            parsed = JSON.parse(_configOutput || "{}");
        } catch (error) {
            failConfiguration(qsTr("rclone 返回了无效的配置问题"));
            return ;
        }
        const protocolError = usefulError(parsed.Error || "");
        if (protocolError !== "") {
            configError = protocolError;
        }
        const stateToken = String(parsed.State || "");
        if (stateToken === "") {
            if (protocolError !== "") {
                _pendingConfigFailure = protocolError;
                _configCancelRequested = true;
                cleanupPartialRemote();
                return ;
            }
            const completedName = configRemoteName;
            const completedType = configRemoteType;
            configBusy = false;
            configState = "success";
            configQuestion = null;
            _configOperation = "";
            _configCreatedRemote = false;
            configSucceeded(completedName, completedType);
            refreshRemotes();
            return ;
        }
        if (!parsed.Option || typeof parsed.Option !== "object") {
            failConfiguration(protocolError || qsTr("rclone 配置问题缺少选项信息"));
            return ;
        }
        configQuestion = {
            "state": stateToken,
            "option": parsed.Option,
            "error": protocolError
        };
        configState = "question";
        configQuestionReady();
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
        _quotaRemoteName = selectedRemoteName;
        quotaProcess.command = [commandName, "about", _quotaRemoteName + ":", "--json"];
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
        _backupRoot = "";
        _backupLastError = "";
        _cancelRequested = false;
        _backupStartedAtMs = 0;
    }

    function refreshCard() {
        refreshQuota();
    }

    function backupFolders(paths) {
        const sources = normalizedFolderPaths(paths);
        return beginBackup(sources, selectedRemoteName, UiPreferences.cloudBackupRoot);
    }

    function beginBackup(sources, remoteName, backupRoot) {
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
        _backupRoot = UiPreferences.normalizedCloudBackupRoot(backupRoot);
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

        return beginBackup(_backupQueue.slice(), _backupRemoteName, _backupRoot);
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
        const destinationRoot = _backupRemoteName + ":" + _backupRoot + "/" + hostName + "/current/" + destinationName;
        const historyRoot = _backupRemoteName + ":" + _backupRoot + "/" + hostName + "/versions/" + _backupVersionStamp + "/" + destinationName;
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

    Component.onCompleted: {
        refreshRemotes();
        loadProviders();
    }

    Connections {
        target: UiPreferences

        function onPreferencesReadyChanged() {
            if (UiPreferences.preferencesReady)
                root.reconcileDefaultRemote();
        }

        function onCloudDefaultRemoteNameChanged() {
            if (UiPreferences.preferencesReady)
                root.reconcileDefaultRemote();
        }
    }

    Process {
        id: remoteListProcess

        onExited: (exitCode) => {
            remoteTimeout.stop();
            root.remotesLoading = false;
            root.available = exitCode === 0;
            if (exitCode !== 0) {
                root.remotesError = qsTr("无法读取 rclone 配置");
                if (root.remotes.length === 0) {
                    root.quotaState = "error";
                    root.quotaMessage = root.remotesError;
                }
                if (root._remotesRefreshPending)
                    Qt.callLater(root.refreshRemotes);
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
                root.remotesRevision += 1;
            } catch (error) {
                root.remotesError = qsTr("rclone 返回了无效的 remote 列表");
                if (root.remotes.length === 0) {
                    root.quotaState = "error";
                    root.quotaMessage = root.remotesError;
                }
                if (root._remotesRefreshPending)
                    Qt.callLater(root.refreshRemotes);
                return ;
            }
            if (root.remotes.length === 0) {
                root.selectedRemoteName = "";
                if (UiPreferences.cloudDefaultRemoteName !== "")
                    UiPreferences.setCloudDefaultRemoteName("");
                root.quotaState = "unavailable";
                root.quotaMessage = qsTr("尚未配置云存储");
                if (root._remotesRefreshPending)
                    Qt.callLater(root.refreshRemotes);
                return ;
            }
            root.reconcileDefaultRemote();
            if (root._remotesRefreshPending)
                Qt.callLater(root.refreshRemotes);
        }

        stdout: StdioCollector {
            onStreamFinished: root._remotesOutput = this.text
        }

    }

    Process {
        id: providersProcess

        onExited: (exitCode) => {
            root.providersLoading = false;
            if (exitCode !== 0) {
                root.providersError = root.usefulError(root._providersErrorOutput) || qsTr("无法读取 rclone 服务列表");
                root.providersLoadFailed(root.providersError);
                return ;
            }
            try {
                const parsed = JSON.parse(root._providersOutput || "[]");
                if (!Array.isArray(parsed))
                    throw new Error("providers is not an array");
                root.providers = parsed;
                root.providersError = "";
                root.providersLoaded();
            } catch (error) {
                root.providersError = qsTr("rclone 返回了无效的服务列表");
                root.providersLoadFailed(root.providersError);
            }
        }

        stdout: StdioCollector {
            onStreamFinished: root._providersOutput = this.text
        }

        stderr: StdioCollector {
            onStreamFinished: root._providersErrorOutput = this.text
        }
    }

    Process {
        id: configProcess

        onExited: (exitCode) => {
            // In particular, do not retain a --result password in the Process
            // command property after rclone has consumed it.
            configProcess.command = [];
            const operation = root._configOperation;
            if (operation === "cleanup") {
                root.finishConfigCancelled();
                return ;
            }
            if (operation === "delete") {
                const deletedName = root.configRemoteName;
                root.configBusy = false;
                root.configState = exitCode === 0 ? "idle" : "error";
                root._configOperation = "";
                if (exitCode === 0) {
                    root.remoteDeleted(deletedName);
                    root.refreshRemotes();
                } else {
                    root.configError = root.usefulError(root._configErrorOutput) || qsTr("无法删除云存储配置");
                    root.remoteDeleteFailed(root.configError);
                }
                return ;
            }
            if (root._configCancelRequested) {
                root.cleanupPartialRemote();
                return ;
            }
            if (exitCode !== 0) {
                const failure = root.usefulError(root._configErrorOutput) || qsTr("rclone 配置命令失败");
                root._pendingConfigFailure = failure;
                if (root._configCreatedRemote) {
                    root._configCancelRequested = true;
                    root.cleanupPartialRemote();
                } else {
                    root.failConfiguration(failure);
                }
                return ;
            }
            root.consumeConfigResult();
        }

        stdout: StdioCollector {
            onStreamFinished: root._configOutput = this.text
        }

        stderr: StdioCollector {
            onStreamFinished: root._configErrorOutput = this.text
        }
    }

    Process {
        id: quotaProcess

        onExited: (exitCode) => {
            quotaTimeout.stop();
            if (root._quotaRemoteName !== root.selectedRemoteName) {
                Qt.callLater(root.refreshQuota);
                return ;
            }
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
