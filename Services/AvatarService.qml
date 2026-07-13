pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string avatarPath: Paths.profileAvatar
    readonly property string avatarUrl: Paths.fileUrl(avatarPath) + "?revision=" + revision
    property int revision: 0
    property bool busy: false
    property string pendingSource: ""

    signal updateFinished(bool success, string message)

    function setAvatar(path) {
        const source = String(path || "");
        if (source === "" || busy) {
            if (source === "")
                updateFinished(false, "未选择有效的头像文件");
            return;
        }

        pendingSource = source;
        busy = true;
        copyProcess.command = ["cp", "--", source, avatarPath];
        copyProcess.running = true;
    }

    Process {
        id: copyProcess

        onExited: exitCode => {
            root.busy = false;
            if (exitCode === 0) {
                root.revision += 1;
                root.updateFinished(true, "头像已更新");
                Quickshell.execDetached([
                    "notify-send",
                    "-a", "quickshell",
                    "-u", "low",
                    "头像已更新",
                    root.pendingSource
                ]);
            } else {
                root.updateFinished(false, "无法更新头像");
                Quickshell.execDetached([
                    "notify-send",
                    "-a", "quickshell",
                    "-u", "critical",
                    "头像更新失败",
                    root.pendingSource
                ]);
            }
            root.pendingSource = "";
        }
    }
}
