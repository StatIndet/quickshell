import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "clavis-shell-spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    Material.theme: Appearance.m3colors.darkmode
        ? Material.Dark : Material.Light
    Material.accent: Appearance.colors.colPrimary

    property string windowPhase: "hidden"
    property string mode: "apps"
    property string previousLocalMode: "apps"
    property bool modeRailExpanded: false
    property int modeFocusIndex: -1
    property string query: ""
    property int selectedResultIndex: -1
    property string selectedResultId: ""
    property string selectedResultQuery: ""
    property string clipboardActionState: "idle"
    property string clipboardActionEntryId: ""
    property bool clipboardActionKeepOpen: false
    property string clipboardActionError: ""

    property real windowProgress: 0
    property real railProgress: 0
    property real webProgress: 0
    property real _windowAnimationTarget: 0
    property real _railAnimationTarget: 0
    property real _webAnimationTarget: 0

    readonly property var activeResults: mode === "apps"
        ? appProvider.results
        : (mode === "wallpapers"
            ? wallpaperProvider.results
            : (mode === "clipboard" ? clipboardProvider.results : []))
    readonly property bool clipboardMode: mode === "clipboard"
    readonly property bool clipboardCanRestore:
        clipboardProvider.canRestore
    readonly property bool wallpaperMode: mode === "wallpapers"
    readonly property bool showing:
        windowPhase !== "hidden" && root.visible
    readonly property bool searchHasFocus: searchBar.inputActiveFocus
    readonly property real searchMainLeft: searchBar.mainLeft
    readonly property real searchMainRight: searchBar.mainRight
    readonly property real searchRequestedWidth:
        searchBar.requestedMainWidth
    readonly property real webPressDepth: searchBar.pressDepth
    readonly property real webPressScaleX: searchBar.pressScaleX
    readonly property real webPressScaleY: searchBar.pressScaleY
    readonly property real searchShadowBlur:
        searchBar.pressShadowBlur
    readonly property real searchShadowVerticalOffset:
        searchBar.pressShadowVerticalOffset
    readonly property real resultsPanelWidth: resultsPanel.width
    readonly property real resultsPanelHeight: resultsPanel.height
    readonly property int wallpaperGridColumns:
        resultsPanel.wallpaperColumnCount
    readonly property real wallpaperPreviewWidth:
        resultsPanel.wallpaperPreviewWidth
    readonly property int blurRegionCount:
        spotlightBlur.regionObjects.length

    SpotlightStyle {
        id: style
    }

    SpotlightAppProvider {
        id: appProvider
        query: root.query
    }

    SpotlightWallpaperProvider {
        id: wallpaperProvider
        query: root.query
    }

    SpotlightClipboardProvider {
        id: clipboardProvider
        query: root.query
        onRestored: id => root.finishClipboardRestore(id)
        onRestoreFailed: (id, code, message) =>
            root.failClipboardRestore(id, code, message)
    }

    Timer {
        id: clipboardFeedbackTimer

        repeat: false
        onTriggered: {
            if (root.clipboardActionKeepOpen) {
                root.resetClipboardAction();
                return;
            }
            root.requestClose();
        }
    }

    function normalizedMode(value) {
        const requested = String(value || "").toLowerCase();
        return requested === "apps"
            || requested === "wallpapers"
            || requested === "clipboard" ? requested : "";
    }

    function modeIndex(value) {
        if (value === "wallpapers")
            return 1;
        if (value === "clipboard")
            return 2;
        return 0;
    }

    function modeForIndex(index) {
        return ["apps", "wallpapers", "clipboard"][
            Math.max(0, Math.min(2, index))
        ];
    }

    function animateWindow(target) {
        root._windowAnimationTarget = target;
        windowAnimation.stop();
        windowAnimation.from = root.windowProgress;
        windowAnimation.to = target;
        windowAnimation.duration = Math.max(
            1,
            (target > root.windowProgress
                ? style.windowOpenDuration
                : style.windowCloseDuration)
                * Math.abs(target - root.windowProgress)
        );
        windowAnimation.restart();
    }

    function animateRail(target) {
        root._railAnimationTarget = target;
        railAnimation.stop();
        railAnimation.from = root.railProgress;
        railAnimation.to = target;
        railAnimation.duration = Math.max(
            1,
            style.railDuration * Math.abs(target - root.railProgress)
        );
        railAnimation.restart();
    }

    function animateWeb(target) {
        root._webAnimationTarget = target;
        webAnimation.stop();
        webAnimation.from = root.webProgress;
        webAnimation.to = target;
        webAnimation.duration = Math.max(
            1,
            style.webDuration * Math.abs(target - root.webProgress)
        );
        webAnimation.restart();
    }

    function openSpotlight(requestedMode) {
        const localMode = normalizedMode(requestedMode);
        if (localMode !== "")
            setLocalMode(localMode);
        else if (root.windowPhase === "hidden")
            setLocalMode("apps");

        if (root.windowPhase === "open"
                || root.windowPhase === "opening") {
            searchBar.focusInput();
            return true;
        }

        if (!root.visible)
            root.visible = true;
        root.windowPhase = "opening";
        root.animateWindow(1);
        Qt.callLater(searchBar.focusInput);
        return true;
    }

    function requestClose() {
        if (root.windowPhase === "hidden"
                || root.windowPhase === "closing")
            return false;
        root.windowPhase = "closing";
        root.modeRailExpanded = false;
        root.modeFocusIndex = -1;
        root.animateRail(0);
        root.animateWindow(0);
        return true;
    }

    function toggleWindow() {
        if (root.windowPhase === "hidden"
                || root.windowPhase === "closing")
            return root.openSpotlight();
        return root.requestClose();
    }

    function openWindow() {
        return root.openSpotlight();
    }

    function setRailExpanded(expanded) {
        if (root.modeRailExpanded === expanded
                && root._railAnimationTarget === (expanded ? 1 : 0))
            return;
        root.modeRailExpanded = expanded;
        if (!expanded)
            root.modeFocusIndex = -1;
        root.animateRail(expanded ? 1 : 0);
    }

    function setLocalMode(requestedMode) {
        const localMode = normalizedMode(requestedMode);
        if (localMode === "")
            return false;
        const enteringClipboard = root.mode !== "clipboard"
            && localMode === "clipboard";
        if (root.mode === "web")
            root.animateWeb(0);
        root.selectedResultId = "";
        root.mode = localMode;
        root.previousLocalMode = localMode;
        root.selectResult(root.activeResults.length > 0 ? 0 : -1);
        if (localMode === "clipboard") {
            if (enteringClipboard)
                root.resetClipboardAction();
            clipboardProvider.refresh();
        }
        searchBar.focusInput();
        return true;
    }

    function enterWeb() {
        if (root.mode === "web"
                && root._webAnimationTarget === 1)
            return true;
        if (root.mode !== "web")
            root.previousLocalMode = root.mode;
        root.mode = "web";
        root.selectedResultIndex = -1;
        root.selectedResultId = "";
        root.setRailExpanded(false);
        root.animateWeb(1);
        searchBar.focusInput();
        return true;
    }

    function exitWeb() {
        if (root.mode !== "web")
            return false;
        root.mode = root.normalizedMode(root.previousLocalMode) !== ""
            ? root.previousLocalMode : "apps";
        root.animateWeb(0);
        root.selectedResultId = "";
        root.selectResult(root.activeResults.length > 0 ? 0 : -1);
        if (root.mode === "clipboard")
            clipboardProvider.refresh();
        searchBar.focusInput();
        return true;
    }

    function moveModeFocus(delta) {
        if (!root.modeRailExpanded) {
            root.modeFocusIndex = root.mode === "web"
                ? 0 : root.modeIndex(root.mode);
            root.setRailExpanded(true);
            return;
        }
        const current = root.modeFocusIndex < 0
            ? 0 : root.modeFocusIndex;
        root.modeFocusIndex = (current + delta + 3) % 3;
    }

    function selectResult(index) {
        root.selectedResultQuery = root.query;
        if (root.activeResults.length === 0 || index < 0) {
            root.selectedResultIndex = -1;
            root.selectedResultId = "";
            return false;
        }

        const bounded = Math.max(
            0,
            Math.min(root.activeResults.length - 1, index)
        );
        const result = root.activeResults[bounded];
        root.selectedResultIndex = bounded;
        root.selectedResultId = result && result.id !== undefined
            ? String(result.id) : "";
        return true;
    }

    function moveSelectionByOffset(offset) {
        if (root.mode === "web" || root.activeResults.length === 0)
            return;
        const current = root.selectedResultIndex < 0
            ? 0 : root.selectedResultIndex;
        root.selectResult(
            Math.max(
                0,
                Math.min(
                    root.activeResults.length - 1,
                    current + offset
                )
            )
        );
    }

    function moveSelection(direction) {
        root.moveSelectionByOffset(
            resultsPanel.navigationStep(direction)
        );
    }

    function reconcileSelection() {
        if (root.activeResults.length === 0) {
            root.selectResult(-1);
            return;
        }

        if (root.selectedResultQuery !== root.query) {
            root.selectResult(0);
            return;
        }

        let restoredIndex = -1;
        if (root.selectedResultId !== "") {
            for (let index = 0;
                    index < root.activeResults.length;
                    index += 1) {
                const result = root.activeResults[index];
                if (result && String(result.id)
                        === root.selectedResultId) {
                    restoredIndex = index;
                    break;
                }
            }
        }
        root.selectResult(restoredIndex >= 0 ? restoredIndex : 0);
    }

    function openWebQuery() {
        const value = String(root.query || "").trim();
        if (value === "")
            return false;
        const encoded = encodeURIComponent(value);
        const url = style.searchEngineUrlTemplate.replace(
            "{query}", encoded);
        return Qt.openUrlExternally(url);
    }

    function resetClipboardAction() {
        clipboardFeedbackTimer.stop();
        root.clipboardActionState = "idle";
        root.clipboardActionEntryId = "";
        root.clipboardActionKeepOpen = false;
        root.clipboardActionError = "";
    }

    function activateClipboard(keepOpen) {
        if (root.selectedResultIndex < 0)
            return false;
        const result = root.activeResults[root.selectedResultIndex];
        if (!result)
            return false;
        const id = String(result.id || "");
        if (root.clipboardActionState === "copying") {
            if (root.clipboardActionEntryId === id)
                return false;
            root.clipboardActionError = qsTr(
                "已有剪贴板操作正在执行");
            return false;
        }
        clipboardFeedbackTimer.stop();
        root.clipboardActionState = "copying";
        root.clipboardActionEntryId = id;
        root.clipboardActionKeepOpen = keepOpen === true;
        root.clipboardActionError = "";
        if (!clipboardProvider.execute(root.selectedResultIndex)) {
            if (root.clipboardActionState === "copying") {
                root.clipboardActionState = "error";
                root.clipboardActionError = qsTr("复制失败");
            }
            return false;
        }
        return true;
    }

    function activateResult(index, keepClipboardOpen) {
        if (!root.selectResult(index))
            return false;
        return root.activateSelected(keepClipboardOpen === true);
    }

    function finishClipboardRestore(id) {
        if (root.clipboardActionState !== "copying"
                || String(id) !== root.clipboardActionEntryId)
            return;
        root.clipboardActionState = "copied";
        root.clipboardActionError = "";
        clipboardFeedbackTimer.interval =
            root.clipboardActionKeepOpen ? 800 : 230;
        clipboardFeedbackTimer.restart();
    }

    function failClipboardRestore(id, code, message) {
        if (root.clipboardActionState === "copying"
                && root.clipboardActionEntryId !== ""
                && String(id) !== root.clipboardActionEntryId)
            return;
        root.clipboardActionEntryId = String(id);
        root.clipboardActionState = "error";
        root.clipboardActionError = String(message || qsTr("复制失败"));
        root.clipboardActionKeepOpen = false;
        clipboardFeedbackTimer.stop();
    }

    function activateSelected(keepClipboardOpen) {
        if (root.modeRailExpanded && root.modeFocusIndex >= 0) {
            root.setLocalMode(root.modeForIndex(root.modeFocusIndex));
            root.setRailExpanded(false);
            return true;
        }
        if (root.mode === "web")
            return root.openWebQuery();
        if (root.selectedResultIndex < 0)
            return false;

        if (root.mode === "apps") {
            if (appProvider.execute(root.selectedResultIndex)) {
                root.requestClose();
                return true;
            }
            return false;
        }
        if (root.mode === "wallpapers")
            return wallpaperProvider.execute(root.selectedResultIndex);
        if (root.mode === "clipboard")
            return root.activateClipboard(keepClipboardOpen === true);
        return false;
    }

    function modeButtonBlend(index) {
        return searchBar.buttonBlend(index);
    }

    function modeButtonBridgeRadius(index) {
        return searchBar.buttonBridgeRadius(index);
    }

    function modeButtonRadius(index) {
        return searchBar.buttonRadius(index);
    }

    function modeButtonCenterX(index) {
        return searchBar.buttonCenterX(index);
    }

    function resultNavigationStep(direction) {
        return resultsPanel.navigationStep(direction);
    }

    function clipboardActivationAreaAt(index) {
        return resultsPanel.clipboardActivationAreaAt(index);
    }

    function clipboardLayoutAt(index) {
        return resultsPanel.clipboardLayoutAt(index);
    }

    function webPressDepthAt(progress) {
        return searchBar.pressDepthForProgress(progress);
    }

    function webPressScaleXAt(progress) {
        return searchBar.pressScaleXForProgress(progress);
    }

    function webPressScaleYAt(progress) {
        return searchBar.pressScaleYForProgress(progress);
    }

    function webShadowBlurAt(progress) {
        return searchBar.shadowBlurForProgress(progress);
    }

    function webShadowVerticalOffsetAt(progress) {
        return searchBar.shadowVerticalOffsetForProgress(progress);
    }

    function handleEscape() {
        if (root.mode === "web") {
            root.exitWeb();
        } else if (root.modeRailExpanded || root.railProgress > 0.001) {
            root.setRailExpanded(false);
        } else if (root.query !== "") {
            root.query = "";
        } else {
            root.requestClose();
        }
    }

    function handleKey(event) {
        const control = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;

        if (control && event.key === Qt.Key_K) {
            root.enterWeb();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Tab
                || event.key === Qt.Key_Backtab) {
            root.moveModeFocus(
                event.key === Qt.Key_Backtab || shift ? -1 : 1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            root.handleEscape();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Up) {
            root.moveSelection(-1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Down) {
            root.moveSelection(1);
            event.accepted = true;
            return;
        }
        if (root.mode === "wallpapers"
                && event.key === Qt.Key_Left) {
            root.moveSelectionByOffset(-1);
            event.accepted = true;
            return;
        }
        if (root.mode === "wallpapers"
                && event.key === Qt.Key_Right) {
            root.moveSelectionByOffset(1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.activateSelected(root.mode === "clipboard" && shift);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Delete
                && root.mode === "clipboard"
                && root.selectedResultIndex >= 0) {
            clipboardProvider.deleteEntry(root.selectedResultIndex);
            event.accepted = true;
        }
    }

    onActiveResultsChanged: root.reconcileSelection()

    NumberAnimation {
        id: windowAnimation

        target: root
        property: "windowProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root._windowAnimationTarget > root.windowProgress
            ? style.windowEnterCurve : style.windowExitCurve

        onFinished: {
            if (root._windowAnimationTarget >= 1) {
                root.windowProgress = 1;
                root.windowPhase = "open";
                searchBar.focusInput();
                return;
            }
            root.windowProgress = 0;
            root.windowPhase = "hidden";
            root.visible = false;
            root.query = "";
            root.mode = "apps";
            root.previousLocalMode = "apps";
            root.selectedResultIndex = -1;
            root.selectedResultId = "";
            root.selectedResultQuery = "";
            root.modeRailExpanded = false;
            root.modeFocusIndex = -1;
            root.railProgress = 0;
            root.webProgress = 0;
            root.resetClipboardAction();
        }
    }

    NumberAnimation {
        id: railAnimation

        target: root
        property: "railProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: style.railCurve
    }

    NumberAnimation {
        id: webAnimation

        target: root
        property: "webProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: style.webCurve
    }

    CompositorBlurRegion {
        id: spotlightBlur

        targetWindow: root
        backgroundItem: searchBar.blurRegionItems[0]
        additionalBackgroundItems:
            searchBar.blurRegionItems.slice(1).concat([
                resultsPanel.blurRegionItem
            ])
        blurEnabled: root.showing
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
        opacity: style.scrimOpacity * root.windowProgress

        MouseArea {
            anchors.fill: parent
            onClicked: root.requestClose()
        }
    }

    Item {
        id: spotlightRoot

        readonly property real baseY:
            Math.max(40, root.height * 0.22 - searchBar.height / 2)

        width: Math.min(
            root.wallpaperMode
                ? style.wallpaperPanelWidth : style.canvasWidth,
            Math.max(
                360,
                root.width - style.windowHorizontalMargin * 2
            )
        )
        height: searchBar.height
            + style.resultGap + resultsPanel.height
        anchors.horizontalCenter: parent.horizontalCenter
        y: baseY
            + style.initialYOffset * (1 - root.windowProgress)
        opacity: root.windowProgress
        scale: style.initialScale
            + (1 - style.initialScale) * root.windowProgress
        transformOrigin: Item.Top

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        SpotlightSearchBar {
            id: searchBar

            width: parent.width
            anchors.top: parent.top
            style: style
            mode: root.mode
            modeRailExpanded: root.modeRailExpanded
            modeFocusIndex: root.modeFocusIndex
            railProgress: root.railProgress
            webProgress: root.webProgress
            requestedMainWidth: Math.max(
                420,
                Math.min(
                    style.searchWidth,
                    width - style.compactSideReserve
                )
            )
            text: root.query
            onTextChanged: root.query = text
            onRoutedKey: event => root.handleKey(event)
            onModeClicked: index => {
                root.modeFocusIndex = index;
                root.setLocalMode(root.modeForIndex(index));
                root.setRailExpanded(false);
            }
        }

        SpotlightResultsPanel {
            id: resultsPanel

            width: root.wallpaperMode
                ? Math.min(
                    style.wallpaperPanelWidth,
                    spotlightRoot.width
                )
                : searchBar.requestedMainWidth
            anchors.top: searchBar.bottom
            anchors.topMargin: style.resultGap
            anchors.horizontalCenter: parent.horizontalCenter
            style: style
            mode: root.mode
            results: root.activeResults
            selectedIndex: root.selectedResultIndex
            loading: root.clipboardMode && clipboardProvider.loading
            providerAvailable:
                !root.clipboardMode || clipboardProvider.available
            canRestore:
                !root.clipboardMode || clipboardProvider.canRestore
            providerError:
                root.clipboardMode ? clipboardProvider.error : null
            clipboardActionState: root.clipboardActionState
            clipboardActionEntryId: root.clipboardActionEntryId
            clipboardActionError: root.clipboardActionError
            clipboardActionRunning: clipboardProvider.actionRunning
                || root.clipboardActionState === "copying"
                || root.clipboardActionState === "copied"
            availableHeight: Math.max(
                style.emptyHeight,
                root.height
                    - spotlightRoot.baseY
                    - searchBar.height
                    - style.resultGap
                    - style.windowBottomMargin
            )

            onSelectionRequested: index =>
                root.selectResult(index)
            onActivationRequested: (index, keepOpen) => {
                root.activateResult(index, keepOpen);
            }
            onDeleteRequested: index =>
                clipboardProvider.deleteEntry(index)
            onClearRequested: clipboardProvider.clear()
            onInspectionRequested: id =>
                clipboardProvider.requestDetails(id)
            onInspectionReleased: id =>
                clipboardProvider.releaseDetails(id)
        }
    }
}
