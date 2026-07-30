//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.Launcher
import qs.Services

ShellRoot {
    id: smoke

    property int stage: 0
    property bool passed: true
    property real collapsedMainLeft: 0
    property real collapsedMainRight: 0

    function verify(condition, message) {
        if (condition)
            return;
        smoke.passed = false;
        console.error("SPOTLIGHT_SMOKE_ASSERT", message);
    }

    function key(key, modifiers) {
        const event = {
            key: key,
            modifiers: modifiers || Qt.NoModifier,
            accepted: false
        };
        spotlight.handleKey(event);
        return event;
    }

    function curveIsBounded(curve) {
        if (!curve || curve.length < 2)
            return false;
        for (let index = 1; index < curve.length; index += 2) {
            if (curve[index] < 0 || curve[index] > 1)
                return false;
        }
        return true;
    }

    LauncherWindow {
        id: spotlight
    }

    SpotlightStyle {
        id: visualStyle
    }

    Timer {
        id: runner

        interval: 90
        repeat: true
        running: true

        onTriggered: {
            smoke.stage += 1;

            if (smoke.stage === 1) {
                smoke.verify(
                    Math.abs(
                        visualStyle.surfaceColor.a
                            - PersonalizationConfig
                                .shellBackgroundOpacity
                    ) < 0.001
                        && Math.abs(
                            visualStyle.panelColor.a
                                - PersonalizationConfig
                                    .shellBackgroundOpacity
                        ) < 0.001,
                    "Spotlight surfaces follow shell transparency");
                smoke.verify(
                    visualStyle.selectedColor
                        !== visualStyle.panelColor,
                    "selected results use a distinct tonal color");
                smoke.verify(
                    visualStyle.shadowBlur > 0
                        && visualStyle.shadowColor.a > 0,
                    "Spotlight surfaces have soft elevation shadows");
                smoke.verify(
                    visualStyle.wallpaperPanelWidth
                            > visualStyle.searchWidth
                        && visualStyle.wallpaperGridHeight
                            > visualStyle.resultMaxHeight,
                    "wallpaper mode uses a significantly larger panel");
                smoke.verify(
                    visualStyle.wallpaperColumnsForWidth(1208) === 5
                        && visualStyle.wallpaperColumnsForWidth(728) === 3,
                    "wallpaper columns adapt from five to narrow layouts");
                smoke.verify(
                    visualStyle.wallpaperHoverScale > 1
                        && visualStyle.wallpaperHoverScale < 1.08
                        && smoke.curveIsBounded(
                            visualStyle.wallpaperHoverCurve),
                    "wallpaper hover zoom is subtle and cannot overshoot");
                smoke.verify(
                    visualStyle.railDuration === 700,
                    "rail animation uses the requested 700ms duration");
                smoke.verify(
                    smoke.curveIsBounded(
                        visualStyle.windowEnterCurve)
                        && smoke.curveIsBounded(
                            visualStyle.windowExitCurve)
                        && smoke.curveIsBounded(
                            visualStyle.panelCurve)
                        && smoke.curveIsBounded(
                            visualStyle.effectsCurve)
                        && smoke.curveIsBounded(
                            visualStyle.railCurve)
                        && smoke.curveIsBounded(
                            visualStyle.webCurve),
                    "driver curves stay bounded; morph geometry owns overshoot");
                spotlight.openSpotlight("apps");
                smoke.verify(spotlight.visible, "window becomes visible");
                smoke.verify(
                    spotlight.blurRegionCount === 8,
                    "blur follows the pill, circles, bridges and panel");
                smoke.verify(
                    spotlight.windowPhase === "opening",
                    "opening phase");
            } else if (smoke.stage === 4) {
                smoke.verify(
                    spotlight.windowPhase === "open",
                    "open phase completes");
                smoke.verify(
                    spotlight.searchHasFocus,
                    "search input owns focus");
                smoke.collapsedMainLeft =
                    spotlight.searchMainLeft;
                smoke.collapsedMainRight =
                    spotlight.searchMainRight;
                smoke.key(Qt.Key_Tab);
                smoke.verify(
                    spotlight.modeRailExpanded
                        && spotlight.modeFocusIndex === 0,
                    "Tab expands rail at Apps");
            } else if (smoke.stage === 7) {
                smoke.verify(
                    spotlight.searchMainRight
                        < smoke.collapsedMainRight
                            - visualStyle.modeButtonDiameter,
                    "pill contracts before the satellite chain forms");
                smoke.verify(
                    spotlight.modeButtonBlend(0) > 0
                        && spotlight.modeButtonBlend(0)
                            <= visualStyle.modeButtonDiameter * 0.20,
                    "early split forms a prominent smooth-union neck");
                smoke.verify(
                    spotlight.modeButtonBridgeRadius(0) > 0
                        && spotlight.modeButtonBridgeRadius(0)
                            <= visualStyle.modeButtonDiameter * 0.13,
                    "early split has a visible connector");
            } else if (smoke.stage === 9) {
                smoke.verify(
                    Math.abs(
                        spotlight.modeButtonBridgeRadius(0)
                    ) < 0.001,
                    "main connector breaks before positional rebound");
                smoke.verify(
                    spotlight.modeButtonBridgeRadius(1)
                            <= visualStyle.modeButtonDiameter * 0.16
                        && spotlight.modeButtonBridgeRadius(2)
                            <= visualStyle.modeButtonDiameter * 0.16,
                    "remaining satellite necks stay below the thin limit");
                smoke.verify(
                    Math.abs(
                        spotlight.searchMainLeft
                            - smoke.collapsedMainLeft
                    ) < 0.01,
                    "rail animation keeps the left edge fixed");
                smoke.verify(
                    spotlight.modeButtonRadius(0) >= 3
                        && spotlight.modeButtonRadius(0)
                            <= visualStyle.modeButtonDiameter / 2,
                    "button radius stays within geometry bounds");
                smoke.verify(
                    spotlight.searchMainRight
                        < smoke.collapsedMainRight
                            - visualStyle.railWidthContraction,
                    "pill briefly contracts beyond its final width");
            } else if (smoke.stage === 12) {
                smoke.verify(
                    Math.abs(
                        spotlight.searchMainRight
                            - (
                                smoke.collapsedMainRight
                                - visualStyle.railWidthContraction
                            )
                    ) < 0.01,
                    "pill rebounds to its final width");
                smoke.verify(
                    Math.abs(
                        spotlight.modeButtonBridgeRadius(0)
                    ) < 0.001
                        && Math.abs(
                            spotlight.modeButtonBridgeRadius(1)
                        ) < 0.001
                        && Math.abs(
                            spotlight.modeButtonBridgeRadius(2)
                        ) < 0.001,
                    "all connector threads are gone at rest");
            } else if (smoke.stage === 16) {
                smoke.verify(
                    Math.abs(spotlight.modeButtonBlend(0)) < 0.001
                        && Math.abs(
                            spotlight.modeButtonBlend(1)) < 0.001
                        && Math.abs(
                            spotlight.modeButtonBlend(2)) < 0.001,
                    "settled circles are fully separated");
                smoke.verify(
                    Math.abs(
                        spotlight.modeButtonBridgeRadius(0)
                    ) < 0.001
                        && Math.abs(
                            spotlight.modeButtonBridgeRadius(1)
                        ) < 0.001
                        && Math.abs(
                            spotlight.modeButtonBridgeRadius(2)
                        ) < 0.001,
                    "settled circles retain no connector capsules");
                smoke.verify(
                    Math.abs(
                        spotlight.searchMainLeft
                            - smoke.collapsedMainLeft
                    ) < 0.01,
                    "settled rail keeps the left edge fixed");
                smoke.verify(
                    spotlight.searchMainRight
                        < smoke.collapsedMainRight,
                    "only the right edge retracts");
                smoke.verify(
                    Math.abs(
                        spotlight.modeButtonRadius(0)
                            - visualStyle.modeButtonDiameter / 2
                    ) < 0.01,
                    "settled button reaches its target radius");
                smoke.verify(
                    visualStyle.modeButtonDiameter
                        === visualStyle.searchHeight,
                    "mode buttons match the search pill height");
                smoke.verify(
                    spotlight.modeButtonCenterX(0)
                        < spotlight.modeButtonCenterX(1)
                        && spotlight.modeButtonCenterX(1)
                            < spotlight.modeButtonCenterX(2),
                    "settled buttons are ordered left to right");
                smoke.verify(
                    Math.abs(
                        spotlight.modeButtonCenterX(2)
                            + visualStyle.modeButtonDiameter / 2
                            - (
                                spotlight.searchMainLeft
                                + spotlight.searchRequestedWidth
                            )
                    ) < 0.01,
                    "settled rail aligns with the results panel");
                smoke.verify(
                    Math.abs(
                        spotlight.webPressDepthAt(0)
                    ) < 0.001
                        && Math.abs(
                            spotlight.webPressDepthAt(0.25) - 1
                        ) < 0.001
                        && Math.abs(
                            spotlight.webPressDepthAt(0.62)
                        ) < 0.001
                        && Math.abs(
                            spotlight.webPressDepthAt(1)
                        ) < 0.001,
                    "web press has one bounded compression cycle");
                smoke.verify(
                    Math.abs(
                        spotlight.webPressScaleXAt(0.25) - 0.985
                    ) < 0.001
                        && Math.abs(
                            spotlight.webPressScaleYAt(0.25) - 0.945
                        ) < 0.001,
                    "web press uses the reference axial deformation");
                smoke.verify(
                    Math.abs(
                        spotlight.webShadowBlurAt(0.25)
                            - visualStyle.shadowBlur * 0.72
                    ) < 0.001
                        && Math.abs(
                            spotlight.webShadowVerticalOffsetAt(0.25)
                                - (visualStyle.shadowVerticalOffset - 3)
                        ) < 0.001,
                    "web press tightens the shadow with the shape");
                smoke.key(Qt.Key_Backtab, Qt.ShiftModifier);
                smoke.verify(
                    spotlight.modeFocusIndex === 2,
                    "Shift+Tab cycles backwards");
                smoke.key(Qt.Key_Tab);
                smoke.verify(
                    spotlight.modeFocusIndex === 0,
                    "Tab wraps logical focus to Apps");
                smoke.key(Qt.Key_Tab);
                smoke.verify(
                    spotlight.modeFocusIndex === 1,
                    "Tab advances logical focus to Wallpapers");
                smoke.key(Qt.Key_Return);
                smoke.verify(
                    spotlight.mode === "wallpapers",
                    "Enter activates Wallpapers");
            } else if (smoke.stage === 19) {
                smoke.verify(
                    Math.abs(
                        spotlight.resultsPanelWidth
                            - visualStyle.wallpaperPanelWidth
                    ) < 1,
                    "wallpaper panel reaches its expanded width");
                smoke.verify(
                    spotlight.wallpaperGridColumns === 5,
                    "current output renders five wallpaper columns");
                smoke.verify(
                    spotlight.wallpaperPreviewWidth
                        >= visualStyle.wallpaperMinPreviewWidth,
                    "expanded wallpaper previews meet their size target");
                smoke.verify(
                    spotlight.resultNavigationStep(1) === 5,
                    "wallpaper keyboard navigation follows grid columns");
                if (spotlight.activeResults.length > 1) {
                    const target = Math.min(
                        2, spotlight.activeResults.length - 1);
                    spotlight.selectResult(target);
                    const selectedId = spotlight.selectedResultId;
                    spotlight.reconcileSelection();
                    smoke.verify(
                        spotlight.selectedResultIndex === target
                            && spotlight.selectedResultId === selectedId,
                        "provider rebuild reconciliation preserves selection");
                    smoke.key(Qt.Key_Right);
                    smoke.verify(
                        spotlight.selectedResultIndex
                            === Math.min(
                                target + 1,
                                spotlight.activeResults.length - 1
                            ),
                        "Right selects the next wallpaper");
                    smoke.key(Qt.Key_Left);
                    smoke.verify(
                        spotlight.selectedResultIndex === target,
                        "Left selects the previous wallpaper");
                    spotlight.selectResult(0);
                    smoke.key(Qt.Key_Down);
                    smoke.verify(
                        spotlight.selectedResultIndex
                            === Math.min(
                                spotlight.wallpaperGridColumns,
                                spotlight.activeResults.length - 1
                            ),
                        "Down advances by one wallpaper row");
                }
                smoke.key(Qt.Key_Tab);
                smoke.verify(
                    spotlight.modeFocusIndex === 1,
                    "collapsed rail opens at Wallpapers");
                smoke.key(Qt.Key_Tab);
                smoke.verify(
                    spotlight.modeFocusIndex === 2,
                    "second Tab advances logical focus to Clipboard");
                smoke.key(Qt.Key_Return);
                smoke.verify(
                    spotlight.mode === "clipboard",
                    "Enter activates Clipboard");
                spotlight.query = "keep me";
                smoke.key(Qt.Key_K, Qt.ControlModifier);
                smoke.verify(
                    spotlight.mode === "web"
                        && spotlight.query === "keep me",
                    "Ctrl+K preserves query");
            } else if (smoke.stage === 21) {
                smoke.key(Qt.Key_Escape);
                smoke.verify(
                    spotlight.mode === "clipboard",
                    "Esc exits web first");
                spotlight.query = "clear me";
            } else if (smoke.stage === 31) {
                smoke.key(Qt.Key_Escape);
                smoke.verify(
                    spotlight.query === "",
                    "Esc clears query after web and rail");
                spotlight.requestClose();
            } else if (smoke.stage === 32) {
                spotlight.toggleWindow();
                smoke.verify(
                    spotlight.windowPhase === "opening",
                    "toggle reverses closing animation");
                spotlight.toggleWindow();
                smoke.verify(
                    spotlight.windowPhase === "closing",
                    "toggle reverses opening animation");
            } else if (smoke.stage === 35) {
                smoke.verify(
                    spotlight.windowPhase === "hidden"
                        && !spotlight.visible,
                    "closed window releases overlay");
                smoke.verify(
                    spotlight.query === ""
                        && spotlight.mode === "apps",
                    "cleanup occurs after close");
                console.log(
                    smoke.passed
                        ? "SPOTLIGHT_SMOKE_PASS"
                        : "SPOTLIGHT_SMOKE_FAIL");
                runner.stop();
                Qt.quit();
            }
        }
    }
}
