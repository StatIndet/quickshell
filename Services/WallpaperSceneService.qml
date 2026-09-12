pragma Singleton

import QtQuick
import Quickshell
import Clavis.Niri
import qs.Common
import "../Common/SidebarPolicy.js" as SidebarPolicy
import qs.Services
import "../Common/functions/WallpaperMath.js" as WallpaperMath

Singleton {
    id: root

    property var scenes: ({})
    property var lastFocusedHorizontalColumnByWorkspace: ({})

    function rememberFocusedWindow() {
        const next = WallpaperMath.rememberFocusedHorizontalColumn(root.lastFocusedHorizontalColumnByWorkspace,
                                                                   Niri.focusedWindow);
        if (next !== root.lastFocusedHorizontalColumnByWorkspace)
            root.lastFocusedHorizontalColumnByWorkspace = next;
    }

    function resolveHorizontalColumn(workspace, columns) {
        const workspaceId = workspace && workspace.id ? workspace.id : 0;
        if (!workspaceId || !columns || columns.length === 0)
            return 0;

        root.rememberFocusedWindow();
        const workspaceKey = String(workspaceId);
        let preferred = Number(root.lastFocusedHorizontalColumnByWorkspace[workspaceKey]);
        if (!isFinite(preferred) || preferred <= 0) {
            const activeWindow = Niri.windowById(workspace.activeWindowId || 0);
            if (WallpaperMath.isHorizontalTiledWindow(activeWindow))
                preferred = Number(activeWindow.layoutColumn);
        }

        const resolved = WallpaperMath.nearestHorizontalColumn(columns, preferred);
        if (Number(root.lastFocusedHorizontalColumnByWorkspace[workspaceKey]) !== resolved) {
            const next = {};
            for (let key in root.lastFocusedHorizontalColumnByWorkspace)
                next[key] = root.lastFocusedHorizontalColumnByWorkspace[key];
            next[workspaceKey] = resolved;
            root.lastFocusedHorizontalColumnByWorkspace = next;
        }
        return resolved;
    }

    function refreshAllScenes() {
        for (let key in root.scenes) {
            const scene = root.scenes[key];
            if (scene && typeof scene.refreshNiriState === "function")
                scene.refreshNiriState();
        }
    }

    function sceneFor(screenName) {
        const key = String(screenName || "");
        if (root.scenes[key])
            return root.scenes[key];
        const scene = sceneComponent.createObject(root, {
                                                      "screenName": key
                                                  });
        if (!scene)
            return null;
        const next = {};
        for (let name in root.scenes)
            next[name] = root.scenes[name];
        next[key] = scene;
        root.scenes = next;
        scene.refreshNiriState();
        return scene;
    }

    Component {
        id: sceneComponent

        QtObject {
            id: scene

            required property string screenName
            property real screenWidth: 1
            property real screenHeight: 1
            // The renderer supplies the decoded dimensions.  The scene is
            // still usable before the first decode and falls back to the
            // viewport geometry.
            // Keep decoded image dimensions atomic.  Two independent width
            // and height bindings can expose a transient 960x0 (or 0x540)
            // size while an Image changes source.  Panorama geometry would
            // interpret that half-updated value as an enormous canvas.
            property size imagePixelSize: Qt.size(0, 0)
            readonly property real imagePixelWidth: imagePixelSize.width
            readonly property real imagePixelHeight: imagePixelSize.height
            property var outputWorkspaces: []
            property var horizontalColumns: []
            property var activeWorkspace: ({})
            property int focusedHorizontalColumn: 0
            property int serviceRevision: WallpaperService.revision
            property int settingsRevision: WallpaperService.settingsRevision

            readonly property string sourcePath: serviceRevision >= 0 ? WallpaperService.wallpaperForScreen(
                                                                            screenName) : ""
            readonly property string fillModeName: settingsRevision >= 0 ? WallpaperService.fillModeForScreen(
                                                                               screenName) : "Fill"
            readonly property int fillMode: WallpaperService.qtFillMode(fillModeName)
            readonly property bool sourceIsColor: !WallpaperService.isImagePath(sourcePath)
            readonly property bool externalBackend: AwwwWallpaperService.effectiveBackend === "awww"
            readonly property bool panoramaSelected: fillModeName === "panorama" && !externalBackend
            readonly property bool hasHorizontalDriver: PersonalizationConfig.parallaxFollowTiledColumns
                                                        || PersonalizationConfig.parallaxFollowSidebars
            readonly property bool hasVerticalDriver: PersonalizationConfig.parallaxVerticalEnabled
                                                      && PersonalizationConfig.parallaxFollowWorkspaces
            readonly property bool parallaxRequested: hasHorizontalDriver || hasVerticalDriver
            readonly property bool parallaxSupported: !externalBackend && WallpaperMath.supportsParallaxCanvas(
                                                          !panoramaSelected && fillMode
                                                          === Image.PreserveAspectCrop, sourcePath,
                                                          sourceIsColor)
            readonly property bool manualParallaxActive: parallaxRequested && parallaxSupported
            readonly property real preferredScale: panoramaSelected ? 1 : manualParallaxActive
                                                                      ? PersonalizationConfig.parallaxPreferredScale :
                                                                        1
            readonly property var panoramaGeometry: WallpaperMath.panoramaGeometry(screenWidth, screenHeight,
                                                                                   imagePixelWidth,
                                                                                   imagePixelHeight,
                                                                                   panoramaSelected &&
                                                                                   !sourceIsColor)
            readonly property var parallaxCanvas: WallpaperMath.parallaxCanvasGeometry(screenWidth,
                                                                                       screenHeight,
                                                                                       preferredScale,
                                                                                       manualParallaxActive)
            readonly property var canvasGeometry: panoramaGeometry.active ? panoramaGeometry : ({
                                                                                                    scale: parallaxCanvas.scale,
                                                                                                    canvasWidth:
                                                                                                    parallaxCanvas.scaledWidth,
                                                                                                    canvasHeight:
                                                                                                    parallaxCanvas.scaledHeight,
                                                                                                    overflowX:
                                                                                                    parallaxCanvas.overflowX,
                                                                                                    overflowY:
                                                                                                    parallaxCanvas.overflowY
                                                                                                })
            readonly property real canvasWidth: Math.max(1, canvasGeometry.canvasWidth
                                                         || parallaxCanvas.scaledWidth)
            readonly property real canvasHeight: Math.max(1, canvasGeometry.canvasHeight
                                                          || parallaxCanvas.scaledHeight)
            readonly property bool analysisGeometryReady: sourceIsColor || (imagePixelWidth > 1
                                                                            && imagePixelHeight > 1
                                                                            && isFinite(canvasWidth)
                                                                            && isFinite(canvasHeight)
                                                                            && canvasWidth >= 1
                                                                            && canvasHeight >= 1)
            readonly property real overflowX: Math.max(0, canvasWidth - Math.max(1, screenWidth))
            readonly property real overflowY: Math.max(0, canvasHeight - Math.max(1, screenHeight))
            readonly property real tiledProgress: {
                if (!PersonalizationConfig.parallaxFollowTiledColumns)
                    return 0.5;
                return WallpaperMath.focusedColumnProgress(horizontalColumns, focusedHorizontalColumn,
                                                           PersonalizationConfig.parallaxTiledColumnSpan);
            }
            readonly property bool dashboardSidebarOnThisScreen: WidgetState.dashboardSidebarOpen
                                                                 && WidgetState.sidebarScreenName
                                                                 === screenName
            readonly property bool quickSettingsSidebarOnThisScreen: WidgetState.quickSettingsOpen
                                                                     && WidgetState.sidebarScreenName
                                                                     === screenName
            readonly property bool leftEdgeOpen: SidebarPolicy.edgeOpen("left", dashboardSidebarOnThisScreen,
                                                                        quickSettingsSidebarOnThisScreen,
                                                                        PersonalizationConfig.dashboardSidebarSide,
                                                                        PersonalizationConfig.quickSettingsSidebarSide)
            readonly property bool rightEdgeOpen: SidebarPolicy.edgeOpen("right", dashboardSidebarOnThisScreen,
                                                                         quickSettingsSidebarOnThisScreen,
                                                                         PersonalizationConfig.dashboardSidebarSide,
                                                                         PersonalizationConfig.quickSettingsSidebarSide)
            readonly property real sidebarStep: PersonalizationConfig.parallaxPreferredScale / Math.max(2,
                                                                                                        PersonalizationConfig.parallaxTiledColumnSpan)
                                                / 2
            readonly property real horizontalProgress: WallpaperMath.horizontalProgress(tiledProgress,
                                                                                        PersonalizationConfig.parallaxFollowSidebars
                                                                                        && leftEdgeOpen,
                                                                                        PersonalizationConfig.parallaxFollowSidebars
                                                                                        && rightEdgeOpen,
                                                                                        sidebarStep)
            property real panoramaHorizontalProgress: horizontalProgress
            readonly property real verticalProgress: {
                if (!PersonalizationConfig.parallaxVerticalEnabled ||
                        !PersonalizationConfig.parallaxFollowWorkspaces)
                    return 0.5;
                return WallpaperMath.workspaceProgress(outputWorkspaces);
            }
            readonly property real offsetX: WallpaperMath.wallpaperPosition(overflowX, panoramaSelected
                                                                            ? panoramaHorizontalProgress :
                                                                              horizontalProgress)
            readonly property real offsetY: WallpaperMath.wallpaperPosition(overflowY, verticalProgress)
            // These are the only animated screen transforms.  Wallpaper and
            // DesktopCardCanvas both consume them, so parallax never gives
            // the two surfaces separate easing timelines.
            property real animatedOffsetX: offsetX
            property real animatedOffsetY: offsetY
            readonly property string analysisKey: sourcePath + "|revision=" + serviceRevision + "|"
                                                  + fillModeName + "|" + Math.round(canvasWidth) + "x"
                                                  + Math.round(canvasHeight) + "|" + Math.round(
                                                      imagePixelWidth) + "x" + Math.round(imagePixelHeight)
                                                  + "|" + (externalBackend ? "external" : "clavis")

            Behavior on animatedOffsetX {
                NumberAnimation {
                    duration: Appearance.animation.wallpaperParallax.duration
                    easing.type: Appearance.animation.wallpaperParallax.type
                }
            }

            Behavior on animatedOffsetY {
                NumberAnimation {
                    duration: Appearance.animation.wallpaperParallax.duration
                    easing.type: Appearance.animation.wallpaperParallax.type
                }
            }

            function wallpaperToScreen(x, y) {
                return {
                    x: Number(x) + scene.animatedOffsetX,
                    y: Number(y) + scene.animatedOffsetY
                };
            }

            function screenToWallpaper(x, y) {
                return {
                    x: Number(x) - scene.animatedOffsetX,
                    y: Number(y) - scene.animatedOffsetY
                };
            }

            function normalizedToWallpaper(xNorm, yNorm) {
                const normalizedX = Number(xNorm);
                const normalizedY = Number(yNorm);
                return {
                    x: Math.max(0, Math.min(1, isFinite(normalizedX) ? normalizedX : 0.5)) * scene.canvasWidth,
                    y: Math.max(0, Math.min(1, isFinite(normalizedY) ? normalizedY : 0.5))
                       * scene.canvasHeight
                };
            }

            function wallpaperToNormalized(x, y) {
                return {
                    xNorm: Math.max(0, Math.min(1, Number(x) / Math.max(1, scene.canvasWidth))),
                    yNorm: Math.max(0, Math.min(1, Number(y) / Math.max(1, scene.canvasHeight)))
                };
            }

            function refreshNiriState() {
                scene.outputWorkspaces = Niri.workspacesForOutput(scene.screenName);
                scene.activeWorkspace = Niri.activeWorkspaceForOutput(scene.screenName);
                const workspaceId = scene.activeWorkspace && scene.activeWorkspace.id
                      ? scene.activeWorkspace.id : 0;
                const windows = workspaceId ? Niri.windowsForWorkspace(workspaceId) : [];
                scene.horizontalColumns = WallpaperMath.horizontalColumns(windows);
                scene.focusedHorizontalColumn = root.resolveHorizontalColumn(scene.activeWorkspace,
                                                                             scene.horizontalColumns);
            }

            Component.onCompleted: scene.refreshNiriState()
        }
    }

    Connections {
        target: Niri

        function onWorkspacesChanged() {
            root.refreshAllScenes();
        }
        function onWindowsChanged() {
            root.refreshAllScenes();
        }
        function onOutputsChanged() {
            root.refreshAllScenes();
        }
    }
}
