import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.WeatherMap
import qs.Common
import qs.Modules.Bar
import qs.Modules.ControlCenter
import qs.Modules.DesktopCards
import qs.Modules.Debug
import qs.Modules.Keystone
import qs.Modules.Launcher
import qs.Modules.Lock
import qs.Modules.PowerMenu
import qs.Modules.RegionSelector
import qs.Modules.Sidebars
import qs.Modules.Wallpaper
import qs.Services

Item {
    id: root

    property string pendingSecurePowerAction: ""

    function runSecurePowerAction() {
        if (pendingSecurePowerAction === "" || !sessionLocker.secure)
            return ;

        const action = pendingSecurePowerAction;
        pendingSecurePowerAction = "";
        Quickshell.execDetached(["loginctl", action]);
    }

    function requestSecurePowerAction(action) {
        if (pendingSecurePowerAction !== "")
            return ;

        const result = sessionLocker.open();
        if (result !== "LOCKED" && result !== "ALREADY_LOCKED")
            return ;

        pendingSecurePowerAction = action;
        runSecurePowerAction();
    }

    Component.onCompleted: {
        I18nService.initialize();
        LyricsTrackService.initialize();
        SystemIdentityService.initialize();
    }

    WallpaperBackground {
    }

    // Desktop cards are an independent bottom-layer subsystem.  It remains
    // loaded when the awww backend hides Clavis' wallpaper renderer.
    DesktopCardHost {
    }

    MapLibreProbeHost {
    }

    LazyLoader {
        id: controlCenterLoader

        active: false
        Component.onCompleted: ControlCenterService.registerLoader(controlCenterLoader)
        onItemChanged: {
            if (item)
                ControlCenterService.registerWindow(item);

        }

        ControlCenterWindow {
            id: controlCenterWindow

            onPopoutClosed: ControlCenterService.windowClosed(controlCenterWindow)
        }

    }

    Bar {
    }

    Keystone {
    }

    RegionSelector {
    }

    SidebarHostWindow {
    }

    LockWarmup {
    }

    Lock {
        id: sessionLocker
    }

    PowerMenu {
    }

    Connections {
        function onActionRequested(action) {
            switch (action) {
            case "lock":
                sessionLocker.open();
                break;
            case "logout":
                Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
                break;
            case "suspend":
                root.requestSecurePowerAction("suspend");
                break;
            case "poweroff":
                Quickshell.execDetached(["systemctl", "poweroff"]);
                break;
            case "hibernate":
                root.requestSecurePowerAction("hibernate");
                break;
            case "reboot":
                Quickshell.execDetached(["systemctl", "reboot"]);
                break;
            }
        }

        target: PowerMenuService
    }

    Connections {
        function onSecured() {
            root.runSecurePowerAction();
        }

        function onActiveChanged() {
            if (!sessionLocker.active)
                root.pendingSecurePowerAction = "";

        }

        target: sessionLocker
    }

    Connections {
        function onLockRequested() {
            IdleService.reportLockResult(sessionLocker.open());
        }

        target: IdleService
    }

    IpcHandler {
        function open() {
            return sessionLocker.open();
        }

        function isLocked() {
            return sessionLocker.isLocked();
        }

        target: "lock"
    }

    LauncherWindow {
        id: spotlightLauncher
    }

    IpcHandler {
        function toggle() : string {
            spotlightLauncher.toggleWindow();
            return spotlightLauncher.windowPhase.toUpperCase();
        }

        function open() : string {
            spotlightLauncher.openSpotlight();
            return spotlightLauncher.windowPhase.toUpperCase();
        }

        function close() : string {
            spotlightLauncher.requestClose();
            return spotlightLauncher.windowPhase.toUpperCase();
        }

        function web() : string {
            spotlightLauncher.openSpotlight();
            spotlightLauncher.enterWeb();
            return "WEB";
        }

        function openMode(mode: string) : string {
            if (spotlightLauncher.normalizedMode(mode || "") === "")
                return "INVALID_MODE";

            spotlightLauncher.openSpotlight(mode);
            return String(mode).toUpperCase();
        }

        target: "spotlight"
    }

    IpcHandler {
        function set(path: string) : string {
            return WallpaperService.setWallpaper(path || "", "") ? "OK" : "INVALID";
        }

        function setForScreen(path: string, screenName: string) : string {
            return WallpaperService.setWallpaper(path || "", screenName || "") ? "OK" : "INVALID";
        }

        function clear() : string {
            return WallpaperService.clearWallpaper("") ? "OK" : "INVALID";
        }

        function clearForScreen(screenName: string) : string {
            return WallpaperService.clearWallpaper(screenName || "") ? "OK" : "INVALID";
        }

        function previous() : string {
            return WallpaperService.cyclePrevious() ? "OK" : "PENDING";
        }

        function next() : string {
            return WallpaperService.cycleNext() ? "OK" : "PENDING";
        }

        function random() : string {
            return WallpaperService.cycleRandom() ? "OK" : "PENDING";
        }

        function setFolder(path: string) : string {
            return WallpaperService.setWallpaperFolder(path || "") ? "OK" : "INVALID";
        }

        target: "wallpaper"
    }

    IpcHandler {
        function open(pageId: string) : string {
            return ControlCenterService.open(pageId || "") ? "OK" : "UNAVAILABLE";
        }

        function close() : string {
            return ControlCenterService.close() ? "OK" : "CLOSED";
        }

        function toggle(pageId: string) : string {
            return ControlCenterService.toggle(pageId || "") ? "OPENING" : "CLOSING";
        }

        target: "control-center"
    }

    IpcHandler {
        function reloadCredentials() : string {
            WeatherMapPlugin.reloadCredentials();
            return "RELOADING";
        }

        function mapTilerStatus() : string {
            return WeatherMapPlugin.mapTilerStatus;
        }

        target: "weather-map"
    }

}
