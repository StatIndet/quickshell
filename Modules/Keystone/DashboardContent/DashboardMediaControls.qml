import QtQuick
import qs.Common
import qs.Components
import qs.Widgets.common

// Adapted from Caelestia Shell's ButtonRow and shape-morphing IconButton (GPL-3.0).
Item {
    id: root

    required property var player

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool isPlaying: hasPlayer && player.isPlaying
    readonly property real sideButtonWidth: 48
    readonly property real buttonSpacing: 4
    readonly property real centerBaseWidth: width - sideButtonWidth * 2 - buttonSpacing * 2

    implicitWidth: 240
    implicitHeight: 44

    component ControlButton: MaterialRippleButton {
        id: control

        required property string iconName
        required property bool primaryButton
        property bool compactRadius: false
        property real shapeMorphExpansion: down ? 24 : 0
        property real visualRadius: down || compactRadius ? 12 : height / 2

        buttonRadius: visualRadius
        buttonRadiusPressed: visualRadius
        rippleOpacity: 0.1
        colBackground: primaryButton
            ? Appearance.colors.colPrimary
            : Appearance.colors.colSecondaryContainer
        colBackgroundHover: primaryButton
            ? Appearance.colors.colPrimaryHover
            : Appearance.colors.colSecondaryContainerHover
        colBackgroundToggled: colBackground
        colBackgroundToggledHover: colBackgroundHover
        colRipple: primaryButton
            ? Appearance.colors.colOnPrimary
            : Appearance.colors.colOnSecondaryContainer
        colRippleToggled: colRipple

        Behavior on shapeMorphExpansion {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        Behavior on visualRadius {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }
        }

        contentItem: MaterialSymbol {
            text: control.iconName
            iconSize: control.primaryButton ? 27 : 25
            fill: 1
            color: control.primaryButton
                ? Appearance.colors.colOnPrimary
                : Appearance.colors.colOnSecondaryContainer
        }
    }

    ControlButton {
        id: previousButton

        x: 0
        width: root.sideButtonWidth + shapeMorphExpansion
            - playPauseButton.shapeMorphExpansion / 2
        height: root.height
        iconName: "skip_previous"
        primaryButton: false
        enabled: root.hasPlayer && root.player.canGoPrevious
        onClicked: if (root.player) root.player.previous()
    }

    ControlButton {
        id: playPauseButton

        x: previousButton.x + previousButton.width + root.buttonSpacing
        width: root.centerBaseWidth + shapeMorphExpansion
            - previousButton.shapeMorphExpansion - nextButton.shapeMorphExpansion
        height: root.height
        iconName: root.isPlaying ? "pause" : "play_arrow"
        primaryButton: true
        compactRadius: root.isPlaying
        enabled: root.hasPlayer && root.player.canTogglePlaying
        onClicked: if (root.player) root.player.togglePlaying()
    }

    ControlButton {
        id: nextButton

        x: playPauseButton.x + playPauseButton.width + root.buttonSpacing
        width: root.sideButtonWidth + shapeMorphExpansion
            - playPauseButton.shapeMorphExpansion / 2
        height: root.height
        iconName: "skip_next"
        primaryButton: false
        enabled: root.hasPlayer && root.player.canGoNext
        onClicked: if (root.player) root.player.next()
    }
}
