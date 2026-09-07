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

function temperature(value, fahrenheit) {
    const converted = fahrenheit && isNumber(value)
        ? value * 9 / 5 + 32 : value;
    return number(converted, 0, fahrenheit ? " °F" : " °C");
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

function rootDisk(disks) {
    if (!Array.isArray(disks) || disks.length === 0)
        return ({});

    for (let index = 0; index < disks.length; index += 1) {
        if (String(disks[index].mountPoint || "") === "/")
            return disks[index];
    }
    return disks[0] || ({});
}

function rootDiskIndex(disks) {
    if (!Array.isArray(disks) || disks.length === 0)
        return 0;

    for (let index = 0; index < disks.length; index += 1) {
        if (String(disks[index].mountPoint || "") === "/")
            return index;
    }
    return 0;
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
        return qsTr("%1 d %2 h").arg(days).arg(hours);
    if (hours > 0)
        return qsTr("%1 h %2 min").arg(hours).arg(minutes);
    if (minutes > 0)
        return qsTr("%n minute(s)", "", minutes);
    return qsTr("%n second(s)", "", total);
}

function batteryStatus(value) {
    switch (String(value || "").toLowerCase()) {
    case "charging":
        return qsTr("Charging");
    case "discharging":
        return qsTr("On battery");
    case "full":
        return qsTr("Fully charged");
    case "not charging":
        return qsTr("Not charging");
    case "unknown":
        return qsTr("Status unknown");
    default:
        return value ? String(value) : unavailable();
    }
}

function yesNo(value) {
    if (value === null || value === undefined)
        return unavailable();
    return value ? qsTr("Yes") : qsTr("No");
}
