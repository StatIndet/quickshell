.pragma library

function isNumber(value) {
    return typeof value === "number" && isFinite(value);
}

function unavailable() {
    return "—";
}

function number(value, decimals, suffix) {
    if (!isNumber(value))
        return unavailable();

    const precision = decimals === undefined ? 1 : Math.max(0, decimals);
    return Number(value).toFixed(precision) + (suffix || "");
}

function percent(value, decimals) {
    return number(value, decimals === undefined ? 1 : decimals, "%");
}

function temperature(value) {
    return number(value, 0, " °C");
}

function watts(value) {
    return number(value, value !== null && value < 10 ? 1 : 0, " W");
}

function bytes(value) {
    if (!isNumber(value) || value < 0)
        return unavailable();

    const units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"];
    let scaled = value;
    let unitIndex = 0;
    while (scaled >= 1024 && unitIndex < units.length - 1) {
        scaled /= 1024;
        unitIndex += 1;
    }

    const decimals = unitIndex === 0 || scaled >= 100 ? 0 : scaled >= 10 ? 1 : 2;
    return scaled.toFixed(decimals) + " " + units[unitIndex];
}

function bytesPerSecond(value) {
    const formatted = bytes(value);
    return formatted === unavailable() ? formatted : formatted + "/s";
}

function frequencyMHz(value) {
    if (!isNumber(value) || value < 0)
        return unavailable();
    if (value >= 1000)
        return (value / 1000).toFixed(value >= 10000 ? 1 : 2) + " GHz";
    return value.toFixed(0) + " MHz";
}

function duration(seconds) {
    if (!isNumber(seconds) || seconds < 0)
        return unavailable();

    const total = Math.floor(seconds);
    const days = Math.floor(total / 86400);
    const hours = Math.floor((total % 86400) / 3600);
    const minutes = Math.floor((total % 3600) / 60);

    if (days > 0)
        return days + " 天 " + hours + " 小时";
    if (hours > 0)
        return hours + " 小时 " + minutes + " 分钟";
    if (minutes > 0)
        return minutes + " 分钟";
    return total + " 秒";
}

function batteryStatus(value) {
    switch (String(value || "").toLowerCase()) {
    case "charging":
        return "充电中";
    case "discharging":
        return "使用电池";
    case "full":
        return "已充满";
    case "not charging":
        return "未充电";
    case "unknown":
        return "状态未知";
    default:
        return value ? String(value) : unavailable();
    }
}

function yesNo(value) {
    if (value === null || value === undefined)
        return unavailable();
    return value ? "是" : "否";
}
