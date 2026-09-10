import QtQuick
import qs.Common

Item {
    id: root
    property bool actionsEnabled: true
    property bool paletteEnabled: true
    property real topRadius: Appearance.rounding.normal
    property real bottomRadius: topRadius
    property string fileTooltip: qsTranslate("WallpaperPage", "Choose folder")
    property string clearTooltip: qsTranslate("WallpaperPage", "Clear wallpaper")
    signal chooseFile
    signal chooseColor
    signal clearWallpaper
    component HoverActionButton: IconButton {
        id: action

        property bool darkOverlay: false

        controlSize: 32
        iconSize: 18
        iconFill: 1
        iconColor: action.darkOverlay ? "white" : Appearance.colors.colOnSurface
        normalContainerColor: action.darkOverlay ? Appearance.applyAlpha("white", 0.18) :
                                                   Appearance.colors.colSurfaceContainerHigh
        hoverStateLayerColor: action.darkOverlay ? Appearance.applyAlpha("white", 0.28) :
                                                   Appearance.colors.colSurfaceContainerHighest
        pressedStateLayerColor: action.darkOverlay ? Appearance.applyAlpha("white", 0.36) :
                                                     Appearance.colors.colLayer3Active
    }

    HoverHandler {
        id: overlayHover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
        color: Appearance.applyAlpha(Appearance.m3colors.m3scrim, 0.7)
        opacity: overlayHover.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutSine
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 4

            HoverActionButton {
                iconName: "folder_open"
                tooltipText: root.fileTooltip
                darkOverlay: true
                enabled: root.actionsEnabled
                onClicked: root.chooseFile()
            }

            HoverActionButton {
                iconName: "palette"
                tooltipText: root.paletteEnabled ? qsTranslate("WallpaperPage", "Choose color") : qsTranslate(
                                                       "WallpaperPage",
                                                       "Color and gradient wallpapers require the Quickshell backend")
                darkOverlay: true
                enabled: root.actionsEnabled && root.paletteEnabled
                disabledHoverFeedback: !root.paletteEnabled
                onClicked: root.chooseColor()
            }

            HoverActionButton {
                iconName: "clear"
                tooltipText: root.clearTooltip
                darkOverlay: true
                enabled: root.actionsEnabled
                onClicked: root.clearWallpaper()
            }
        }
    }
}
