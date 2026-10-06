import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri
import qs.Modules.Bar
import qs.Modules.ControlCenter
import qs.Modules.DesktopCards
import qs.Modules.Dock
import qs.Modules.HotCorners
import qs.Modules.Keystone
import qs.Modules.Launcher
import qs.Modules.Lock
import qs.Modules.PowerMenu
import qs.Modules.RegionSelector
import qs.Modules.Sidebars
import qs.Modules.Wallpaper
import qs.Common
import qs.Services

Item {
    id: root

    property string pendingSecurePowerAction: ""

    // The catalog only supplies fixed, build-validated calls. Both IPC and
    // Search use the same existing business functions, without self-IPC.
    function executeSearchAction(action) {
        switch (action.target) {
        case "lock":
            const status = sessionLocker.open();
            return status === "LOCKED" || status === "ALREADY_LOCKED";
        case "wallpaper":
            switch (action.method) {
            case "clear":
                return WallpaperService.clearWallpaper("");
            case "previous":
                return WallpaperService.cyclePrevious() || WallpaperService.pendingCycleAction === "previous";
            case "next":
                return WallpaperService.cycleNext() || WallpaperService.pendingCycleAction === "next";
            case "random":
                return WallpaperService.cycleRandom() || WallpaperService.pendingCycleAction === "random";
            }
            return false;
        case "keystone":
            switch (action.method) {
            case "closeAllOthers":
            case "dashboard":
            case "hub":
            case "lyrics":
            case "tools":
                return keystone.invoke(action.method) !== "KEYSTONE_UNAVAILABLE";
            }
            return false;
        case "sidebar":
            return (action.method === "toggle" ? sidebarHost.toggleSidebar(action.args[0]) : sidebarHost.setSidebarOpen(
                                                     action.args[0], true)) !== "INVALID_SIDE";
        case "shortcut-map":
            ShortcutMapService.open();
            return true;
        case "power-menu":
            return PowerMenuService.open();
        default:
            return false;
        }
    }

    function runSecurePowerAction() {
        if (pendingSecurePowerAction === "" || !sessionLocker.secure)
            return;

        const action = pendingSecurePowerAction;
        pendingSecurePowerAction = "";
        Quickshell.execDetached(["systemctl", action]);
    }

    function requestSecurePowerAction(action) {
        if (pendingSecurePowerAction !== "")
            return;

        const result = sessionLocker.open();
        if (result !== "LOCKED" && result !== "ALREADY_LOCKED")
            return;

        pendingSecurePowerAction = action;
        runSecurePowerAction();
    }

    Component.onCompleted: {
        SpotlightCatalog.actionExecutor = root.executeSearchAction;
        SpotlightCatalog.keystoneAvailable = Qt.binding(() => keystone.searchActionsAvailable);
        I18nService.initialize();
        DisplayColor.evaluate();
        LyricsTrackService.initialize();
        SystemIdentityService.initialize();
    }

    DisplayOverlays {}

    WallpaperBackground {}

    // Desktop cards are an independent bottom-layer subsystem.  It remains
    // loaded when the awww backend hides Clavis' wallpaper renderer.
    DesktopCardHost {}

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

    Bar {}

    DockHost {}

    Keystone {
        id: keystone
    }

    RegionSelector {}

    SidebarHostWindow {
        id: sidebarHost
    }

    HotCorners {
        locked: sessionLocker.active
        onTriggered: (action, screenName) => {
            if (action === "overview") {
                WidgetState.closeAllPopups();
                Niri.toggleOverview();
                return;
            }
            const target = action.split(":");
            if (target.length === 2) {
                if (Niri.inOverview)
                    Niri.toggleOverview();
                sidebarHost.openOnScreen(target[0], target[1], screenName);
            }
        }
    }

    Lock {
        id: sessionLocker
    }

    PowerMenu {}

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

    Loader {
        active: ShortcutMapService.visible
        sourceComponent: ShortcutMap {
            targetScreen: ShortcutMapService.targetScreen
            onDismissed: ShortcutMapService.close()
        }
    }

    IpcHandler {
        target: "power-menu"
        function open(): void {
        PowerMenuService.open();
    }
        function close(): void {
                              PowerMenuService.close();
                          }
        function toggle(): void {
        PowerMenuService.toggle();
    }
    }

        IpcHandler {
            target: "shortcut-map"
            function open(): void {
            ShortcutMapService.open();
        }
            function close(): void {
                                  ShortcutMapService.close();
                              }
            function toggle(): void {
            ShortcutMapService.toggle();
        }
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
                function toggle(): string {
                    spotlightLauncher.toggleWindow();
                    return spotlightLauncher.windowPhase.toUpperCase();
                }

                function open(): string {
                    spotlightLauncher.openSpotlight();
                    return spotlightLauncher.windowPhase.toUpperCase();
                }

                function search(): string {
                    spotlightLauncher.openSpotlight("search");
                    return "SEARCH";
                }

                function close(): string {
                    spotlightLauncher.requestClose();
                    return spotlightLauncher.windowPhase.toUpperCase();
                }

                function web(): string {
                    spotlightLauncher.openWebMode();
                    return "WEB";
                }

                function command(name: string): string {
                    return spotlightLauncher.runCommand(name);
                }

                function commands(): string {
                    return openMode("commands");
                }

                function files(): string {
                    return openMode("files");
                }

                function openMode(mode: string): string {
                    if (spotlightLauncher.normalizedMode(mode || "") === "")
                        return "INVALID_MODE";

                    spotlightLauncher.openSpotlight(mode);
                    return String(mode).toUpperCase();
                }

                target: "spotlight"
            }

            IpcHandler {
                function set(path: string): string {
                    return WallpaperService.setWallpaper(path || "", "") ? "OK" : "INVALID";
                }

                function setForScreen(path: string, screenName: string): string {
                    return WallpaperService.setWallpaper(path || "", screenName || "") ? "OK" : "INVALID";
                }

                function clear(): string {
                    return WallpaperService.clearWallpaper("") ? "OK" : "INVALID";
                }

                function clearForScreen(screenName: string): string {
                    return WallpaperService.clearWallpaper(screenName || "") ? "OK" : "INVALID";
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
                    return WallpaperService.setWallpaperFolder(path || "") ? "OK" : "INVALID";
                }

                target: "wallpaper"
            }

            IpcHandler {
                function open(pageId: string): string {
                    return ControlCenterService.open(pageId || "") ? "OK" : "UNAVAILABLE";
                }

                function close(): string {
                    return ControlCenterService.close() ? "OK" : "CLOSED";
                }

                function toggle(pageId: string): string {
                    return ControlCenterService.toggle(pageId || "") ? "OPENING" : "CLOSING";
                }

                target: "control-center"
            }
        }
