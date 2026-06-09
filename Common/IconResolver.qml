pragma Singleton

import QtQuick
import Quickshell

QtObject {
    id: root

    // 窗口类名 → 图标名的已知映射
    readonly property var knownMappings: ({
        "Code": "visual-studio-code",
        "code": "visual-studio-code",
        "codium": "vscodium",
        "footclient": "foot",
        "QQ": "qq",
        "org.kde.konsole": "konsole",
        "org.kde.dolphin": "dolphin"
    })

    // 从 reverse-DNS app_id 提取候选图标名列表
    function candidates(appId) {
        if (!appId || appId === "")
            return []

        var result = []

        // 已知映射优先
        if (knownMappings[appId])
            result.push(knownMappings[appId])

        // 前缀匹配
        if (appId.startsWith("steam_app_"))
            result.push("steam_icon_" + appId.substring(10))
        if (appId.startsWith("jetbrains-"))
            result.push("jetbrains-toolbox")

        // reverse-DNS: 取最后一段
        var lastDot = appId.lastIndexOf(".")
        if (lastDot >= 0 && lastDot < appId.length - 1) {
            var lastSegment = appId.substring(lastDot + 1)
            if (result.indexOf(lastSegment) < 0)
                result.push(lastSegment)
        }

        // 原始 appId
        if (result.indexOf(appId) < 0)
            result.push(appId)

        // 小写版本
        if (appId !== appId.toLowerCase() && result.indexOf(appId.toLowerCase()) < 0)
            result.push(appId.toLowerCase())

        return result
    }

    // 解析图标路径，返回 Quickshell.iconPath 或 image:// 回退
    function resolveIcon(appId) {
        if (!appId || appId === "")
            return "image://icon/application-x-executable"

        var cands = candidates(appId)
        for (var i = 0; i < cands.length; i++) {
            var resolved = Quickshell.iconPath(cands[i], "")
            if (resolved && resolved !== "")
                return resolved
        }

        return "image://icon/application-x-executable"
    }
}
