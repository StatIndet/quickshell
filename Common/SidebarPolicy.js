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

function restoredPositions(config) {
    const sidebar = config || {};
    return {
        dashboard: normalizeSide(sidebar.dashboardSide, "left"),
        quickSettings: normalizeSide(sidebar.quickSettingsSide, "right")
    };
}

function resolveOpenState(dashboard, quickSettings, preferred, dashboardSide, quickSettingsSide) {
    if (dashboard && quickSettings && dashboardSide === quickSettingsSide) {
        dashboard = preferred !== "quicksettings";
        quickSettings = !dashboard;
    }
    return { dashboard: dashboard, quickSettings: quickSettings };
}

function edgeOpen(side, dashboard, quickSettings, dashboardSide, quickSettingsSide) {
    return (dashboard && dashboardSide === side) || (quickSettings && quickSettingsSide === side);
}
