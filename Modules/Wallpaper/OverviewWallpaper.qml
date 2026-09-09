import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: overviewWindow

        required property var modelData

        screen: modelData
        color: "transparent"
        visible: PersonalizationConfig.overviewEnabled

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "clavis-overview-wallpaper"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        mask: Region {
            item: Item {}
        }

        Item {
            id: root

            anchors.fill: parent
            clip: true

            property int serviceRevision: WallpaperService.revision
            property int settingsRevision: WallpaperService.settingsRevision
            readonly property int blurOverflow: PersonalizationConfig.overviewBlurRadius > 0 ? 64 : 0
            readonly property string targetSource: serviceRevision >= 0
                                                   ? WallpaperService.overviewWallpaperForScreen(
                                                         modelData.name) : ""
            readonly property string targetFillModeName: settingsRevision >= 0
                                                         ? WallpaperService.overviewFillModeForScreen(
                                                               modelData.name) : "Fill"

            function reportSurface() {
                WallpaperService.reportOverviewSurface(modelData.name, !PersonalizationConfig.overviewEnabled
                                                       || renderer.ready, renderer.lastError);
            }

            onTargetSourceChanged: Qt.callLater(root.reportSurface)
            Component.onCompleted: Qt.callLater(root.reportSurface)

            WallpaperTransitionSurface {
                id: renderer

                anchors.fill: parent
                anchors.margins: -root.blurOverflow
                sourcePath: root.targetSource
                previewSource: WallpaperPaletteSession.previewForScreen("overview", modelData.name)
                imageFillMode: WallpaperService.qtFillMode(root.targetFillModeName)
                shaderFillMode: WallpaperService.shaderFillMode(root.targetFillModeName)
                transitionType: PersonalizationConfig.overviewTransitionType
                includedTransitions: PersonalizationConfig.includedTransitions
                transitionDurationMs: PersonalizationConfig.transitionDurationMs
                transitionEasingMode: PersonalizationConfig.transitionEasingMode
                transitionBezierCurve: PersonalizationConfig.transitionBezierCurve
                textureWidth: Math.min(Math.max(1, Math.round(root.width)), 8192)
                textureHeight: Math.min(Math.max(1, Math.round(root.height)), 8192)

                layer.enabled: PersonalizationConfig.overviewBlurRadius > 0
                               || PersonalizationConfig.overviewSaturation !== 1
                               || PersonalizationConfig.overviewContrast !== 1
                layer.effect: MultiEffect {
                    blurEnabled: PersonalizationConfig.overviewBlurRadius > 0
                    blur: PersonalizationConfig.overviewBlurRadius / 100
                    blurMax: 64
                    saturation: PersonalizationConfig.overviewSaturation - 1
                    contrast: PersonalizationConfig.overviewContrast - 1
                }

                onReadyChanged: root.reportSurface()
                onLastErrorChanged: root.reportSurface()
                onLoadFailed: (source, message) => {
                    WallpaperService.reportOverviewSurface(modelData.name, false, message);
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.m3colors.m3scrim
                opacity: PersonalizationConfig.overviewDim
            }
        }
    }
}
