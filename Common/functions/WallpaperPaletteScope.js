// Configuration scope rules for ephemeral palette previews. These operate on
// saved configuration only; the draft never participates in fallback lookup.
function affects(scope, target, output, config, dark) {
    if (!scope) return false;
    var desktopMonitor = config.perMonitorWallpaper && (config.monitorWallpapers || {})[output];
    var overviewMonitor = config.overviewPerMonitorWallpaper && (config.overviewMonitorWallpapers || {})[output];
    if (scope.target === "overview") {
        if (target !== "overview" || config.overviewUseDesktopWallpaper) return false;
        if (scope.monitor) return output === scope.monitor;
        return !overviewMonitor;
    }
    if (target === "overview" && !config.overviewUseDesktopWallpaper
            && (overviewMonitor || config.overviewWallpaperPath)) return false;
    if (scope.monitor) return output === scope.monitor;
    if (desktopMonitor) return false;
    if (scope.field !== "path") return true;
    return !config.perModeWallpaper || !(dark ? config.wallpaperPathDark : config.wallpaperPathLight);
}
