import QtQuick
import qs.Common
import qs.Services

QtObject {
    readonly property color surfaceColor:
        BlurService.backgroundColor(
            Appearance.m3colors.m3surfaceContainerHigh)
    readonly property color panelColor:
        BlurService.backgroundColor(
            Appearance.m3colors.m3surfaceContainer)
    readonly property color selectedColor:
        Appearance.applyAlpha(
            Appearance.m3colors.m3primaryContainer,
            Math.max(
                0.46,
                PersonalizationConfig.shellBackgroundOpacity
            )
        )
    readonly property color selectedContentColor:
        Appearance.m3colors.m3onPrimaryContainer
    readonly property color hoverColor:
        Appearance.applyAlpha(
            Appearance.m3colors.m3surfaceContainerHighest,
            Math.max(
                0.30,
                PersonalizationConfig.shellBackgroundOpacity
            )
        )
    readonly property color shadowColor: Appearance.applyAlpha(
        Appearance.m3colors.m3shadow,
        Appearance.m3colors.darkmode ? 0.34 : 0.20
    )

    readonly property int canvasWidth: 1100
    readonly property int searchWidth: 760
    readonly property int compactSideReserve: 340
    readonly property int searchHeight: 64
    readonly property int searchHorizontalPadding: 22
    readonly property int searchIconSize: 24
    readonly property int modeButtonCount: 3
    readonly property int modeButtonDiameter: searchHeight
    readonly property int modeButtonGap: 10
    readonly property int modeRailReservedWidth:
        modeButtonCount * (modeButtonDiameter + modeButtonGap)
    readonly property int minimumExpandedSearchWidth:
        searchHeight * 3
    readonly property int effectBleed: 18
    readonly property int resultGap: 12
    readonly property int resultRadius: Appearance.rounding.extraLarge
    readonly property int resultPadding: 10
    readonly property int resultMaxHeight: 440
    readonly property int resultRowHeight: 64
    readonly property int resultIconSize: 40
    // Wayland blur regions have a hard, integer edge. Keep that edge beneath
    // the antialiased translucent surface so X-Ray wallpaper-only blur cannot
    // expose a stair-stepped boundary.
    readonly property int blurEdgeInset: 2
    readonly property int wallpaperPanelWidth: 1240
    readonly property int wallpaperGridHeight: 600
    readonly property int wallpaperPanelPadding: 16
    readonly property int wallpaperMaxColumns: 5
    readonly property int wallpaperMinPreviewWidth: 210
    readonly property int wallpaperGridGap: 16
    readonly property real wallpaperPreviewAspectRatio: 16 / 9
    readonly property int wallpaperLabelGap: 8
    readonly property int wallpaperLabelHeight: 28
    readonly property int wallpaperLabelFontSize: 14
    readonly property real wallpaperHoverScale: 1.045
    readonly property int wallpaperHoverDuration: 200
    readonly property real wallpaperHoverOverlayOpacity: 0.08
    readonly property real wallpaperPressedOverlayOpacity: 0.14
    readonly property int wallpaperCurrentMarkSize: 30
    readonly property int windowHorizontalMargin: 32
    readonly property int windowBottomMargin: 40
    readonly property int emptyHeight: 150
    readonly property int enginePillHeight: 34
    readonly property int enginePillWidth: 86
    readonly property int windowOpenDuration: 210
    readonly property int windowCloseDuration: 175
    readonly property int railDuration: 700
    readonly property int railStagger: 28
    readonly property int webDuration: 340
    readonly property int panelDuration: 210
    readonly property real initialScale: 0.96
    readonly property real initialYOffset: -8
    readonly property real railWidthContraction:
        modeRailReservedWidth
    readonly property real edgeSoftness: 0.9
    readonly property real shadowBlur: 0.72
    readonly property real shadowVerticalOffset: 7
    readonly property var windowEnterCurve:
        Appearance.animationCurves.emphasizedDecel
    readonly property var windowExitCurve:
        Appearance.animationCurves.emphasizedAccel
    readonly property var panelCurve: Appearance.animationCurves.emphasized
    readonly property var effectsCurve:
        Appearance.animationCurves.standardDecel
    readonly property var wallpaperHoverCurve:
        Appearance.animationCurves.standard
    // railProgress itself stays reversible and bounded. The morph surface
    // derives its small, deliberate overshoot from this progress so a rapid
    // reverse never has to jump between independent animations.
    readonly property var railCurve: [0.33, 0, 0.67, 1, 1, 1]
    readonly property var webCurve: Appearance.animationCurves.standard

    function clamp(value, lower, upper) {
        return Math.max(lower, Math.min(upper, value));
    }

    function smoothstep(value) {
        const clamped = clamp(value, 0, 1);
        return clamped * clamped * (3 - 2 * clamped);
    }

    function wallpaperColumnsForWidth(gridWidth) {
        const width = Math.max(0, Number(gridWidth) || 0);
        const pitch = wallpaperMinPreviewWidth + wallpaperGridGap;
        return Math.max(
            1,
            Math.min(
                wallpaperMaxColumns,
                Math.floor(
                    (width + wallpaperGridGap) / pitch
                )
            )
        );
    }
}
