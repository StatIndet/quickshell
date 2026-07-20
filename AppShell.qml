import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.WeatherMap 1.0
import qs.Modules.Bar
import qs.Modules.Keystone
import qs.Modules.Launcher
import qs.Modules.Lock
import qs.Modules.RegionSelector
import qs.Modules.Sidebars.Left
import qs.Modules.Sidebars.Right
import qs.Modules.Wallpaper
import qs.Services

Item {
    id: root

    Component.onCompleted: WallpaperService.primaryInstance = true

    WallpaperBackground {}

    Bar {}

    Keystone {}

    RegionSelector {}

    LeftSidebarWindow {}

    RightSidebar {}

    LockWarmup {}

    Lock {
        id: sessionLocker
    }

    IpcHandler {
        target: "lock"

        function open() {
            return sessionLocker.open();
        }

        function isLocked() {
            return sessionLocker.isLocked();
        }
    }

    LauncherWindow {
        id: rofiLauncher
    }

    IpcHandler {
        target: "launcher"

        function toggle(): string {
            rofiLauncher.toggleWindow();
            return "LAUNCHER_TOGGLED";
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path, screenName) {
            return WallpaperService.setWallpaper(path || "", screenName || "", true) ? "OK" : "PENDING";
        }

        function clear(screenName) {
            return WallpaperService.clearWallpaper(screenName || "", true) ? "OK" : "PENDING";
        }

        function previous() {
            return WallpaperService.cyclePrevious(true) ? "OK" : "PENDING";
        }

        function next() {
            return WallpaperService.cycleNext(true) ? "OK" : "PENDING";
        }

        function random() {
            return WallpaperService.cycleRandom(true) ? "OK" : "PENDING";
        }

        function setFolder(path) {
            return WallpaperService.setWallpaperFolder(path || "", true) ? "OK" : "PENDING";
        }
    }

    IpcHandler {
        target: "weather-map"

        function reloadCredentials(): string {
            WeatherMapPlugin.reloadCredentials()
            return "RELOADING"
        }

        function mapTilerStatus(): string {
            return WeatherMapPlugin.mapTilerStatus
        }
    }
}
