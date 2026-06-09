// 窗口类名 → 图标名的已知映射
var knownMappings = {
    "Code": "visual-studio-code",
    "code": "visual-studio-code",
    "codium": "vscodium",
    "footclient": "foot",
    "steam_app_": "steam_icon_",  // prefix match
    "jetbrains-": "jetbrains-toolbox",  // prefix match
};

// 从 reverse-DNS app_id 提取候选图标名
// 例: org.kde.konsole → ["org.kde.konsole", "konsole"]
// 例: Code → ["Code", "code"]
function candidates(appId) {
    if (!appId || appId === "")
        return [];

    var result = [];

    // 已知映射
    for (var key in knownMappings) {
        if (appId === key) {
            result.push(knownMappings[key]);
            break;
        }
        // 前缀匹配 (steam_app_440 → steam_icon_440)
        if (key.endsWith("_") || key.endsWith("-")) {
            if (appId.startsWith(key)) {
                result.push(knownMappings[key] + appId.substring(key.length));
                break;
            }
        }
    }

    // 原始 appId
    result.push(appId);

    // 小写版本
    if (appId !== appId.toLowerCase())
        result.push(appId.toLowerCase());

    // reverse-DNS: 取最后一段
    var lastDot = appId.lastIndexOf(".");
    if (lastDot >= 0 && lastDot < appId.length - 1) {
        var lastSegment = appId.substring(lastDot + 1);
        if (result.indexOf(lastSegment) < 0)
            result.push(lastSegment);
        if (lastSegment !== lastSegment.toLowerCase() && result.indexOf(lastSegment.toLowerCase()) < 0)
            result.push(lastSegment.toLowerCase());
    }

    return result;
}

// 解析图标路径，返回可用的文件路径或 image:// URL
function resolveIcon(appId) {
    if (!appId || appId === "")
        return "image://icon/application-x-executable";

    var cands = candidates(appId);
    for (var i = 0; i < cands.length; i++) {
        var resolved = Quickshell.iconPath(cands[i], "");
        if (resolved && resolved !== "")
            return resolved;
    }

    return "image://icon/application-x-executable";
}
