import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Variants {
    id: variants

    model: Quickshell.screens

    PanelWindow {
        id: wallpaperWindow

        required property var modelData
        screen: modelData
        color: "transparent"

        // Normal wallpaper belongs below Bottom-layer desktop cards and
        // above the compositor backdrop only.
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "clavis-wallpaper"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: Item {}
        }

        Item {
            id: root

            anchors.fill: parent
            clip: true
            visible: AwwwWallpaperService.quickshellContentVisible

            readonly property string screenKey: String(modelData.name)
            // sceneFor() creates and registers a scene.  Keep creation
            // outside this binding and only observe the service cache here.
            readonly property var scene: WallpaperSceneService.scenes[root.screenKey] || null

            // Wallpaper renderer and DesktopCardHost bind to this exact
            // scene object.  Card coordinates never observe Niri directly.
            property real sceneWidth: root.width
            property real sceneHeight: root.height

            Binding {
                when: root.scene !== null
                target: root.scene
                property: "screenWidth"
                value: root.width
            }
            Binding {
                when: root.scene !== null
                target: root.scene
                property: "screenHeight"
                value: root.height
            }
            Binding {
                when: root.scene !== null
                target: root.scene
                property: "imagePixelSize"
                value: Qt.size(renderer.imagePixelWidth, renderer.imagePixelHeight)
            }

            WallpaperTransitionSurface {
                id: renderer

                x: previewSource !== "" ? 0 : root.scene && !root.scene.panoramaSelected
                                          ? root.scene.animatedOffsetX : 0
                y: previewSource !== "" ? 0 : root.scene ? root.scene.animatedOffsetY : 0
                width: previewSource !== "" ? root.width : root.scene && root.scene.panoramaSelected
                                              ? Math.max(1, root.width) : root.scene ? Math.max(1,
                                                                                                root.scene.canvasWidth) :
                                                                                       Math.max(1, root.width)
                height: previewSource !== "" ? root.height : root.scene && root.scene.panoramaSelected
                                               ? Math.max(1, root.height) : root.scene ? Math.max(1,
                                                                                                  root.scene.canvasHeight) :
                                                                                         Math.max(1,
                                                                                                  root.height)
                previewSource: WallpaperPaletteSession.previewForScreen("desktop", root.screenKey)
                sourcePath: root.scene ? root.scene.sourcePath : ""
                imageFillMode: root.scene ? root.scene.fillMode : Image.PreserveAspectCrop
                shaderFillMode: root.scene ? WallpaperService.shaderFillMode(root.scene.fillModeName) : 2
                panoramaEnabled: root.scene ? root.scene.panoramaSelected && !root.scene.sourceIsColor : false
                horizontalProgress: root.scene ? root.scene.panoramaHorizontalProgress : 0.5
                sharedTransform: root.scene
                transitionType: PersonalizationConfig.wallpaperTransitionType
                includedTransitions: PersonalizationConfig.includedTransitions
                transitionDurationMs: PersonalizationConfig.transitionDurationMs
                transitionEasingMode: PersonalizationConfig.transitionEasingMode
                transitionBezierCurve: PersonalizationConfig.transitionBezierCurve
                transitionsEnabled: AwwwWallpaperService.quickshellContentVisible
                textureWidth: Math.min(Math.max(1, Math.round(root.width)), 8192)
                textureHeight: Math.min(Math.max(1, Math.round(root.height)), 8192)

                onLoadFailed: (source, message) => {
                    WallpaperService.reportDesktopError(modelData.name, message);
                }
            }

            Component.onCompleted: WallpaperSceneService.sceneFor(root.screenKey)
        }
    }
}
