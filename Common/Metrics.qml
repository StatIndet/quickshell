pragma Singleton
import QtQuick

QtObject {
    id: root

    // Static logical-pixel design tokens. Qt/Wayland maps these values to the
    // output buffer; they are intentionally not user-scalable.
    readonly property real spacingXXS: 2
    readonly property real spacingXS: 4
    readonly property real spacingS: 8
    readonly property real spacingM: 12
    readonly property real spacingL: 16
    readonly property real spacingXL: 24
    readonly property real iconS: 16
    readonly property real iconM: 24
    readonly property real iconL: 32
    readonly property real controlHeightS: 32
    readonly property real controlHeightM: 40
    readonly property real controlHeightL: 48
    readonly property real controlHeightXL: 56
    readonly property real touchTarget: 48
    readonly property real cornerXS: 4
    readonly property real cornerS: 12
    readonly property real cornerM: 17
    readonly property real cornerL: 23
    readonly property real cornerXL: 28
    readonly property real cardPadding: spacingL
    readonly property real pageMargin: spacingXL
    readonly property real popupMargin: spacingL
    readonly property real dividerWidth: 1
    readonly property real sidebarWidthCompact: 420
    readonly property real sidebarWidthComfortable: 540
    readonly property real barHeight: 44
    readonly property real avatarS: 32
    readonly property real avatarM: 48
    readonly property real avatarL: 64
    // Lock shell design rules. Runtime output geometry stays local to each
    // WlSessionLockSurface and is compared against these logical-pixel tokens.
    readonly property real lockCenterWidth: 600
    readonly property real lockColumnGap: 40
    readonly property real lockCardGap: spacingL
    readonly property real lockOuterPadding: 20
    readonly property real lockCardPadding: spacingXL
    readonly property real lockCardRadius: 33
    readonly property real lockCardRadiusSmall: cornerL
    readonly property real lockAuthHeight: 64
    readonly property real lockTimeFontSize: 112
    readonly property real lockTimeSuffixFontSize: 75
    readonly property real lockDateFontSize: 37
    readonly property real lockIconPanelSize: 213
    readonly property real lockCompactBreakpoint: 640
    readonly property real lockVeryCompactBreakpoint: 540
    readonly property real lockForecastBreakpoint: 680
    readonly property real lockFetchExpandedBreakpoint: 700
    readonly property real lockResourceProgressPadding: 60
    readonly property real lockResourceProgressStroke: 9
    readonly property real lockResourceProgressGap: 9
    readonly property real lockResourceIconScale: 0.82
}
