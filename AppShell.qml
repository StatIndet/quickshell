import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Weather 1.0
import Clavis.WeatherMap 1.0
import qs.Modules.Bar
import qs.Modules.Keystone
import qs.Modules.Launcher
import qs.Modules.Lock
import qs.Modules.RegionSelector
import qs.Modules.Sidebars
import qs.Modules.Wallpaper
import qs.Services

Item {
    id: root

    Component.onCompleted: {
        I18nService.initialize();
        WallpaperService.primaryInstance = true;
        AwwwWallpaperService.primaryInstance = true;
    }

    WallpaperBackground {}

    Bar {}

    Keystone {}

    RegionSelector {}

    SidebarHostWindow {}

    LockWarmup {}

    Lock {
        id: sessionLocker
    }

    Connections {
        target: IdleService

        function onLockRequested() {
            IdleService.reportLockResult(sessionLocker.open());
        }
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
        id: spotlightLauncher
    }

    IpcHandler {
        target: "spotlight"

        function toggle(): string {
            spotlightLauncher.toggleWindow();
            return spotlightLauncher.windowPhase.toUpperCase();
        }

        function open(): string {
            spotlightLauncher.openSpotlight();
            return spotlightLauncher.windowPhase.toUpperCase();
        }

        function close(): string {
            spotlightLauncher.requestClose();
            return spotlightLauncher.windowPhase.toUpperCase();
        }

        function web(): string {
            spotlightLauncher.openSpotlight();
            spotlightLauncher.enterWeb();
            return "WEB";
        }

        function openMode(mode: string): string {
            if (spotlightLauncher.normalizedMode(mode || "") === "")
                return "INVALID_MODE";
            spotlightLauncher.openSpotlight(mode);
            return String(mode).toUpperCase();
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): string {
            return WallpaperService.setWallpaper(path || "", "", true)
                ? "OK" : "INVALID";
        }

        function setForScreen(path: string, screenName: string): string {
            return WallpaperService.setWallpaper(
                path || "", screenName || "", true)
                ? "OK" : "INVALID";
        }

        function clear(): string {
            return WallpaperService.clearWallpaper("", true)
                ? "OK" : "INVALID";
        }

        function clearForScreen(screenName: string): string {
            return WallpaperService.clearWallpaper(screenName || "", true)
                ? "OK" : "INVALID";
        }

        function previous(): string {
            return WallpaperService.cyclePrevious(true) ? "OK" : "PENDING";
        }

        function next(): string {
            return WallpaperService.cycleNext(true) ? "OK" : "PENDING";
        }

        function random(): string {
            return WallpaperService.cycleRandom(true) ? "OK" : "PENDING";
        }

        function setFolder(path: string): string {
            return WallpaperService.setWallpaperFolder(path || "", true)
                ? "OK" : "INVALID";
        }
    }

    IpcHandler {
        target: "weather"

        function setLocation(latitude: string, longitude: string,
                name: string): string {
            const parsedLatitude = Number(latitude);
            const parsedLongitude = Number(longitude);
            if (!isFinite(parsedLatitude) || !isFinite(parsedLongitude)
                    || parsedLatitude < -90 || parsedLatitude > 90
                    || parsedLongitude < -180 || parsedLongitude > 180) {
                return "INVALID_LOCATION";
            }

            WeatherPlugin.setManualLocation(
                parsedLatitude, parsedLongitude, name || "");
            return "OK";
        }

        function clearLocation(): string {
            WeatherPlugin.clearManualLocation();
            return "OK";
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
