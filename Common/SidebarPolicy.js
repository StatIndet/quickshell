.pragma library

function normalizeSide(value, fallback) {
    return value === "left" || value === "right" ? value : fallback;
}

function normalizeTarget(value) {
    const target = String(value || "").trim().toLowerCase();
    // Compatibility aliases identify content, regardless of its configured edge.
    if (target === "dashboard" || target === "left")
        return "dashboard";
    if (target === "quicksettings" || target === "right")
        return "quicksettings";
    return "";
}

function oppositeSide(side) {
    return side === "left" ? "right" : "left";
}

function restoredDashboardSide(config) {
    const sidebar = config || {};
    const dashboard = normalizeSide(sidebar.dashboardSide, "");
    if (dashboard !== "")
        return dashboard;
    return oppositeSide(normalizeSide(sidebar.quickSettingsSide, "right"));
}

function edgeOpen(side, dashboard, quickSettings, dashboardSide, quickSettingsSide) {
    return (dashboard && dashboardSide === side) || (quickSettings && quickSettingsSide === side);
}
