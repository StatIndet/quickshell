pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string colorsPath: Quickshell.env("HOME") + "/.cache/quickshell-dev-colorscheme/colors.json"
    property string matugenScheme: "scheme-tonal-spot"
    property string matugenMode: "dark"
    readonly property string effectiveMatugenMode: matugenMode.toLowerCase() === "light" ? "light" : "dark"
    property string currentWallpaperPreview: ""
    property real backgroundTransparency: 0
    property real contentTransparency: 0.9
    property QtObject m3colors
    property QtObject animationCurves
    property QtObject animation
    property QtObject colors
    property QtObject rounding
    property QtObject spacing
    property QtObject scrollBar

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function mix(color1, color2, percentage) {
        const amount = percentage === undefined ? 0.5 : percentage;
        const c1 = Qt.color(color1);
        const c2 = Qt.color(color2);
        return Qt.rgba(
            amount * c1.r + (1 - amount) * c2.r,
            amount * c1.g + (1 - amount) * c2.g,
            amount * c1.b + (1 - amount) * c2.b,
            amount * c1.a + (1 - amount) * c2.a
        );
    }

    function transparentize(color, percentage) {
        const amount = percentage === undefined ? 1 : percentage;
        const c = Qt.color(color);
        return Qt.rgba(c.r, c.g, c.b, c.a * (1 - amount));
    }

    function applyAlpha(color, alpha) {
        const c = Qt.color(color);
        return Qt.rgba(c.r, c.g, c.b, clamp01(alpha));
    }

    function solveOverlayColor(baseColor, targetColor, overlayOpacity) {
        const opacity = clamp01(overlayOpacity);
        if (opacity <= 0)
            return transparentize(targetColor, 1);

        const base = Qt.color(baseColor);
        const target = Qt.color(targetColor);
        const invOpacity = 1 - opacity;
        return Qt.rgba(
            clamp01((target.r - base.r * invOpacity) / opacity),
            clamp01((target.g - base.g * invOpacity) / opacity),
            clamp01((target.b - base.b * invOpacity) / opacity),
            opacity
        );
    }

    function snakeToM3(key) {
        const parts = key.split("_");
        let result = "m3" + parts[0];
        for (let i = 1; i < parts.length; i += 1)
            result += parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        return result;
    }

    function applyGeneratedColors(text) {
        if (!text)
            return;

        const generatedColors = JSON.parse(text);
        for (let key in generatedColors) {
            const propertyName = root.snakeToM3(key);
            if (propertyName in root.m3colors)
                root.m3colors[propertyName] = Qt.color(generatedColors[key]);
        }
    }

    function reloadColors() {
        colorFile.reload();
    }

    m3colors: QtObject {
        property bool darkmode: root.effectiveMatugenMode === "dark"
        property color m3background: "#0f1416"
        property color m3error: "#ffb4ab"
        property color m3errorContainer: "#93000a"
        property color m3inverseOnSurface: "#2c3134"
        property color m3inversePrimary: "#09677f"
        property color m3inverseSurface: "#dee3e6"
        property color m3onBackground: "#dee3e6"
        property color m3onError: "#690005"
        property color m3onErrorContainer: "#ffdad6"
        property color m3onPrimary: "#003544"
        property color m3onPrimaryContainer: "#b8eaff"
        property color m3onPrimaryFixed: "#001f28"
        property color m3onPrimaryFixedVariant: "#004d61"
        property color m3onSecondary: "#1e333c"
        property color m3onSecondaryContainer: "#cfe6f1"
        property color m3onSecondaryFixed: "#071e26"
        property color m3onSecondaryFixedVariant: "#354a53"
        property color m3onSurface: "#dee3e6"
        property color m3onSurfaceVariant: "#bfc8cc"
        property color m3onTertiary: "#2c2d4d"
        property color m3onTertiaryContainer: "#e1e0ff"
        property color m3onTertiaryFixed: "#171837"
        property color m3onTertiaryFixedVariant: "#434465"
        property color m3outline: "#8a9296"
        property color m3outlineVariant: "#40484c"
        property color m3primary: "#88d0ec"
        property color m3primaryContainer: "#004d61"
        property color m3primaryFixed: "#b8eaff"
        property color m3primaryFixedDim: "#88d0ec"
        property color m3scrim: "#000000"
        property color m3secondary: "#b3cad5"
        property color m3secondaryContainer: "#354a53"
        property color m3secondaryFixed: "#cfe6f1"
        property color m3secondaryFixedDim: "#b3cad5"
        property color m3shadow: "#000000"
        property color m3sourceColor: "#669cb1"
        property color m3surface: "#0f1416"
        property color m3surfaceBright: "#353a3d"
        property color m3surfaceContainer: "#1b2023"
        property color m3surfaceContainerHigh: "#252b2d"
        property color m3surfaceContainerHighest: "#303638"
        property color m3surfaceContainerLow: "#171c1f"
        property color m3surfaceContainerLowest: "#0a0f11"
        property color m3surfaceDim: "#0f1416"
        property color m3surfaceTint: "#88d0ec"
        property color m3surfaceVariant: "#40484c"
        property color m3tertiary: "#c3c3eb"
        property color m3tertiaryContainer: "#434465"
        property color m3tertiaryFixed: "#e1e0ff"
        property color m3tertiaryFixedDim: "#c3c3eb"
    }

    colors: QtObject {
        property color colSubtext: root.m3colors.m3outline

        property color colLayer0Base: root.mix(root.m3colors.m3background, root.m3colors.m3primary, 0.99)
        property color colLayer0: root.transparentize(colLayer0Base, root.backgroundTransparency)
        property color colOnLayer0: root.m3colors.m3onBackground
        property color colLayer0Hover: root.transparentize(root.mix(colLayer0, colOnLayer0, 0.9), root.contentTransparency)
        property color colLayer0Active: root.transparentize(root.mix(colLayer0, colOnLayer0, 0.8), root.contentTransparency)
        property color colLayer0Border: root.mix(root.m3colors.m3outlineVariant, colLayer0, 0.4)

        property color colLayer1Base: root.m3colors.m3surfaceContainerLow
        property color colLayer1: root.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - root.contentTransparency)
        property color colOnLayer1: root.m3colors.m3onSurfaceVariant
        property color colOnLayer1Inactive: root.mix(colOnLayer1, colLayer1, 0.45)
        property color colLayer1Hover: root.transparentize(root.mix(colLayer1, colOnLayer1, 0.92), root.contentTransparency)
        property color colLayer1Active: root.transparentize(root.mix(colLayer1, colOnLayer1, 0.85), root.contentTransparency)

        property color colLayer2Base: root.m3colors.m3surfaceContainer
        property color colLayer2: root.solveOverlayColor(colLayer1Base, colLayer2Base, 1 - root.contentTransparency)
        property color colLayer2Hover: root.solveOverlayColor(colLayer1Base, root.mix(colLayer2Base, colOnLayer2, 0.90), 1 - root.contentTransparency)
        property color colLayer2Active: root.solveOverlayColor(colLayer1Base, root.mix(colLayer2Base, colOnLayer2, 0.80), 1 - root.contentTransparency)
        property color colLayer2Disabled: root.solveOverlayColor(colLayer1Base, root.mix(colLayer2Base, root.m3colors.m3background, 0.8), 1 - root.contentTransparency)
        property color colOnLayer2: root.m3colors.m3onSurface
        property color colOnLayer2Disabled: root.mix(colOnLayer2, root.m3colors.m3background, 0.4)

        property color colLayer3Base: root.m3colors.m3surfaceContainerHigh
        property color colLayer3: root.solveOverlayColor(colLayer2Base, colLayer3Base, 1 - root.contentTransparency)
        property color colLayer3Hover: root.solveOverlayColor(colLayer2Base, root.mix(colLayer3Base, colOnLayer3, 0.90), 1 - root.contentTransparency)
        property color colLayer3Active: root.solveOverlayColor(colLayer2Base, root.mix(colLayer3Base, colOnLayer3, 0.80), 1 - root.contentTransparency)
        property color colOnLayer3: root.m3colors.m3onSurface

        property color colLayer4Base: root.m3colors.m3surfaceContainerHighest
        property color colLayer4: root.solveOverlayColor(colLayer3Base, colLayer4Base, 1 - root.contentTransparency)
        property color colLayer4Hover: root.solveOverlayColor(colLayer3Base, root.mix(colLayer4Base, colOnLayer4, 0.90), 1 - root.contentTransparency)
        property color colLayer4Active: root.solveOverlayColor(colLayer3Base, root.mix(colLayer4Base, colOnLayer4, 0.80), 1 - root.contentTransparency)
        property color colOnLayer4: root.m3colors.m3onSurface

        property color colPrimary: root.m3colors.m3primary
        property color colOnPrimary: root.m3colors.m3onPrimary
        property color colPrimaryHover: root.mix(colPrimary, colLayer1Hover, 0.87)
        property color colPrimaryActive: root.mix(colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: root.m3colors.m3primaryContainer
        property color colOnPrimaryContainer: root.m3colors.m3onPrimaryContainer
        property color colPrimaryContainerHover: root.mix(colPrimaryContainer, colOnPrimaryContainer, 0.9)
        property color colPrimaryContainerActive: root.mix(colPrimaryContainer, colOnPrimaryContainer, 0.8)
        property color colPrimaryFixed: root.m3colors.m3primaryFixed
        property color colPrimaryFixedDim: root.m3colors.m3primaryFixedDim
        property color colOnPrimaryFixed: root.m3colors.m3onPrimaryFixed
        property color colOnPrimaryFixedVariant: root.m3colors.m3onPrimaryFixedVariant

        property color colSecondary: root.m3colors.m3secondary
        property color colOnSecondary: root.m3colors.m3onSecondary
        property color colSecondaryHover: root.mix(colSecondary, colLayer1Hover, 0.85)
        property color colSecondaryActive: root.mix(colSecondary, colLayer1Active, 0.4)
        property color colSecondaryContainer: root.m3colors.m3secondaryContainer
        property color colOnSecondaryContainer: root.m3colors.m3onSecondaryContainer
        property color colSecondaryContainerHover: root.mix(colSecondaryContainer, colOnSecondaryContainer, 0.90)
        property color colSecondaryContainerActive: root.mix(colSecondaryContainer, colOnSecondaryContainer, 0.54)
        property color colSecondaryFixed: root.m3colors.m3secondaryFixed
        property color colSecondaryFixedDim: root.m3colors.m3secondaryFixedDim
        property color colOnSecondaryFixed: root.m3colors.m3onSecondaryFixed
        property color colOnSecondaryFixedVariant: root.m3colors.m3onSecondaryFixedVariant

        property color colTertiary: root.m3colors.m3tertiary
        property color colOnTertiary: root.m3colors.m3onTertiary
        property color colTertiaryHover: root.mix(colTertiary, colLayer1Hover, 0.85)
        property color colTertiaryActive: root.mix(colTertiary, colLayer1Active, 0.4)
        property color colTertiaryContainer: root.m3colors.m3tertiaryContainer
        property color colOnTertiaryContainer: root.m3colors.m3onTertiaryContainer
        property color colTertiaryContainerHover: root.mix(colTertiaryContainer, colOnTertiaryContainer, 0.90)
        property color colTertiaryContainerActive: root.mix(colTertiaryContainer, colLayer1Active, 0.54)
        property color colTertiaryFixed: root.m3colors.m3tertiaryFixed
        property color colTertiaryFixedDim: root.m3colors.m3tertiaryFixedDim
        property color colOnTertiaryFixed: root.m3colors.m3onTertiaryFixed
        property color colOnTertiaryFixedVariant: root.m3colors.m3onTertiaryFixedVariant

        property color colBackgroundSurfaceContainer: root.transparentize(root.m3colors.m3surfaceContainer, root.backgroundTransparency)
        property color colSurfaceContainerLow: root.solveOverlayColor(root.m3colors.m3background, root.m3colors.m3surfaceContainerLow, 1 - root.contentTransparency)
        property color colSurfaceContainer: root.solveOverlayColor(root.m3colors.m3surfaceContainerLow, root.m3colors.m3surfaceContainer, 1 - root.contentTransparency)
        property color colSurfaceContainerHigh: root.solveOverlayColor(root.m3colors.m3surfaceContainer, root.m3colors.m3surfaceContainerHigh, 1 - root.contentTransparency)
        property color colSurfaceContainerHighest: root.solveOverlayColor(root.m3colors.m3surfaceContainerHigh, root.m3colors.m3surfaceContainerHighest, 1 - root.contentTransparency)
        property color colSurfaceContainerHighestHover: root.mix(root.m3colors.m3surfaceContainerHighest, root.m3colors.m3onSurface, 0.95)
        property color colSurfaceContainerHighestActive: root.mix(root.m3colors.m3surfaceContainerHighest, root.m3colors.m3onSurface, 0.85)
        property color colOnSurface: root.m3colors.m3onSurface
        property color colOnSurfaceVariant: root.m3colors.m3onSurfaceVariant
        property color colInversePrimary: root.m3colors.m3inversePrimary
        property color colOnImage: Qt.rgba(1.0, 1.0, 1.0, 0.96)
        property color colOnImageMuted: root.applyAlpha(colOnImage, 0.82)
        property color colWeatherCardSurface: root.m3colors.m3surfaceContainerLowest
        property color colOnWeatherCardSurface: root.m3colors.m3onSurface
        property color colOnWeatherCardSurfaceVariant: root.m3colors.m3onSurfaceVariant

        property color colTooltip: root.m3colors.m3inverseSurface
        property color colOnTooltip: root.m3colors.m3inverseOnSurface
        property color colScrim: root.transparentize(root.m3colors.m3scrim, 0.5)
        property color colShadow: root.transparentize(root.m3colors.m3shadow, 0.7)
        property color colOutline: root.m3colors.m3outline
        property color colOutlineVariant: root.m3colors.m3outlineVariant

        property color colError: root.m3colors.m3error
        property color colOnError: root.m3colors.m3onError
        property color colErrorHover: root.mix(colError, colLayer1Hover, 0.85)
        property color colErrorActive: root.mix(colError, colLayer1Active, 0.7)
        property color colErrorContainer: root.m3colors.m3errorContainer
        property color colOnErrorContainer: root.m3colors.m3onErrorContainer
        property color colErrorContainerHover: root.mix(colErrorContainer, colOnErrorContainer, 0.90)
        property color colErrorContainerActive: root.mix(colErrorContainer, colOnErrorContainer, 0.70)
    }

    animationCurves: Animations.curves
    animation: Animations.animation

    rounding: QtObject {
        property int extraSmall: 4
        property int small: 12
        property int normal: 17
        property int large: 23
        property int extraLarge: 28
        property int veryLarge: 30
        property int full: 9999
    }

    spacing: QtObject {
        property int xSmall: 4
        property int small: 8
        property int medium: 16
        property int large: 24
        property int panelPadding: 20
    }

    scrollBar: QtObject {
        property int width: 8
        property int margin: 4
        property int minLength: 24
        property int radius: root.rounding.full
        property real activeOpacity: 0.5
        property real inactiveOpacity: 0
        property color thumbColor: root.colors.colOnSurfaceVariant
    }

    FileView {
        id: colorFile
        path: root.colorsPath
        watchChanges: true

        onLoaded: {
            try {
                root.applyGeneratedColors(colorFile.text());
            } catch (error) {
            }
        }

        onFileChanged: colorFile.reload()
    }
}
