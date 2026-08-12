import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.WeatherMap
import qs.Common
import qs.Modules.Bar
import qs.Modules.ControlCenter
import qs.Modules.DesktopCards
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
        LyricsTrackService.initialize();
    }

    WallpaperBackground {}

    // Desktop cards are an independent bottom-layer subsystem.  It remains
    // loaded when the awww backend hides Clavis' wallpaper renderer.
    DesktopCardHost {}

    LazyLoader {
        id: controlCenterLoader

        active: false

        Component.onCompleted:
            ControlCenterService.registerLoader(controlCenterLoader)

        onItemChanged: {
            if (item)
                ControlCenterService.registerWindow(item);
        }

        ControlCenterWindow {
            id: controlCenterWindow

            onPopoutClosed:
                ControlCenterService.windowClosed(controlCenterWindow)
        }
    }

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

    IpcHandler {
        target: "idle"

        function setExternalOwner(value: bool): string {
            return IdleService.setExternalOwner(value);
        }

        function owner(): string {
            return IdleService.externalOwner ? "external" : "quickshell";
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
            return WallpaperService.setWallpaper(path || "", "")
                ? "OK" : "INVALID";
        }

        function setForScreen(path: string, screenName: string): string {
            return WallpaperService.setWallpaper(
                path || "", screenName || "")
                ? "OK" : "INVALID";
        }

        function clear(): string {
            return WallpaperService.clearWallpaper("")
                ? "OK" : "INVALID";
        }

        function clearForScreen(screenName: string): string {
            return WallpaperService.clearWallpaper(screenName || "")
                ? "OK" : "INVALID";
        }

        function previous(): string {
            return WallpaperService.cyclePrevious() ? "OK" : "PENDING";
        }

        function next(): string {
            return WallpaperService.cycleNext() ? "OK" : "PENDING";
        }

        function random(): string {
            return WallpaperService.cycleRandom() ? "OK" : "PENDING";
        }

        function setFolder(path: string): string {
            return WallpaperService.setWallpaperFolder(path || "")
                ? "OK" : "INVALID";
        }
    }

    IpcHandler {
        target: "control-center"

        function open(pageId: string): string {
            return ControlCenterService.open(pageId || "")
                ? "OK" : "UNAVAILABLE";
        }

        function close(): string {
            return ControlCenterService.close() ? "OK" : "CLOSED";
        }

        function toggle(pageId: string): string {
            return ControlCenterService.toggle(pageId || "")
                ? "OPENING" : "CLOSING";
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
