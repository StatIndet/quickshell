pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property int visibleItemCount: 5
    readonly property int cachedItemCount: 4

    readonly property real previewWidth: 220
    readonly property real previewAspectRatio: 16 / 9
    readonly property real delegateWidth: 252
    readonly property real delegateHeight: 184
    readonly property real previewTopPadding: 18
    readonly property real labelGap: 6
    readonly property real labelWidthInset: 24
    readonly property real previewRadius: Appearance.rounding.large

    readonly property real selectedScale: 1
    readonly property real sideScale: 0.8
    readonly property real initialScale: 0.5
    readonly property real hiddenScale: 0

    readonly property real searchHeight: 48
    readonly property real searchHorizontalMargin: 24
    readonly property real searchBottomMargin: 14
    readonly property real searchIconInset: 18
    readonly property real searchTextInset: 52
    readonly property real clearButtonSize: 36
    readonly property real carouselBottomGap: 8

    readonly property int labelFontSize: 13
    readonly property int searchFontSize: 15
    readonly property int searchIconSize: 22
    readonly property int emptyIconSize: 32

    readonly property QtObject spatialMotion: Animations.animation.expressiveDefaultSpatial
    readonly property QtObject effectsMotion: Animations.animation.expressiveDefaultEffects
}
