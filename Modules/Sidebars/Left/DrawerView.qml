import QtQuick
import M3Shapes
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Modules.SystemCards
import "../../DesktopCards/DesktopCardLayout.js" as DesktopCardLayout
import "../../SystemCards/SystemCardGeometry.js" as CardGeometry
import "../../SystemCards/SystemCardPlacement.js" as Placement
import "./drawer"
import "./drawer/DrawerGridLayout.js" as GridLayout

Item {
    id: root

    property string screenName: ""
    property bool foreground: false
    readonly property bool isForeground: root.foreground
    readonly property var activeSidebarIds: {
        const ids = SystemCardService.sidebarCardIds.slice();
        // Keep the hidden source delegate available while the unified
        // presentation host owns the drag visual. It is not a second
        // ownership record and never suppresses the Desktop delegate.
        if (SystemCardDragSession.active && SystemCardDragSession.tileId !== "" && ids.indexOf(
                    SystemCardDragSession.tileId) === -1)
            ids.push(SystemCardDragSession.tileId);

        return ids;
    }
    readonly property var tileDefinitions: GridLayout.definitions(root.activeSidebarIds)
    readonly property int gridContentWidth: GridLayout.canvasWidth
    readonly property int gridContentHeight: GridLayout.contentHeight(root.dragTargetValid &&
                                                                      !root.desktopExtraction
                                                                      ? root.previewLayout :
                                                                        root.committedLayout,
                                                                      root.activeSidebarIds)
    readonly property var sidebarAnchors: {
        const result = {};
        root.activeSidebarIds.forEach(function (id) {
            result[id] = SystemCardService.sidebarAnchor(id);
        });
        return result;
    }
    property bool preferencesApplied: false
    property bool serviceForegroundAcquired: false
    property var committedLayout: GridLayout.defaultLayout(root.activeSidebarIds, root.sidebarAnchors)
    property var previewLayout: []
    property string draggingTileId: ""
    property Item dragSourceItem: null
    property int targetX: -1
    property int targetY: -1
    property bool dragTargetValid: false
    property bool desktopExtraction: false

    function layoutPlacement(layout, tileId) {
        return GridLayout.placementFor(layout, tileId);
    }

    function cardSize(tileId) {
        return CardGeometry.sizeFor(String(tileId));
    }

    function displayPlacement(tileId) {
        if (root.draggingTileId === tileId)
            return root.layoutPlacement(root.committedLayout, tileId);

        if (root.draggingTileId.length > 0 && root.dragTargetValid && !root.desktopExtraction)
            return root.layoutPlacement(root.previewLayout, tileId);

        return root.layoutPlacement(root.committedLayout, tileId);
    }

    function sidebarContainsPoint(x, y) {
        let item = root;
        while (item) {
            if (typeof item.containsPoint === "function")
                return item.containsPoint(x, y);

            item = item.parent;
        }
        return false;
    }

    function applyStoredLayout(forceRefresh) {
        if ((!forceRefresh && root.preferencesApplied) || !UiPreferences.preferencesReady ||
                !SystemCardService.preferencesLoaded || root.draggingTileId.length > 0)
            return;

        const hydrated = GridLayout.hydrateSaved(UiPreferences.drawerGridLayout, root.activeSidebarIds,
                                                 root.sidebarAnchors);
        root.committedLayout = hydrated;
        root.preferencesApplied = true;
    }

    function beginDrag(tileId, sourceItem, grabLocalX, grabLocalY, pointerLocalX, pointerLocalY) {
        if (root.draggingTileId.length > 0)
            root.cancelDrag();

        if (!SystemCardDragSession.begin(tileId, sourceItem, grabLocalX, grabLocalY))
            return;

        root.draggingTileId = tileId;
        root.dragSourceItem = sourceItem;
        root.targetX = -1;
        root.targetY = -1;
        root.dragTargetValid = false;
        root.desktopExtraction = false;
        dashboard.forceActiveFocus();
        root.updateDrag(tileId, pointerLocalX, pointerLocalY);
    }

    function promoteToPresentation(tileId, sourceItem, pointerLocalX, pointerLocalY) {
        const geometry = DesktopPresentationService.geometry(root.screenName);
        const sourceRect = DesktopPresentationService.mapItemRect(root.screenName, sourceItem);
        const mappedGrabPoint = DesktopPresentationService.mapItemPoint(root.screenName, sourceItem,
                                                                        SystemCardDragSession.grabLocalX,
                                                                        SystemCardDragSession.grabLocalY);
        const presentationPointer = DesktopPresentationService.mapItemPoint(root.screenName, sourceItem,
                                                                            pointerLocalX, pointerLocalY);
        if (!geometry || !sourceRect || !mappedGrabPoint || !presentationPointer) {
            console.warn("[SystemCards] presentation host unavailable", root.screenName, tileId);
            return false;
        }
        // The drawer may be scaled down, but the desktop uses canonical
        // card dimensions. Preserve the relative grab point while promoting.
        const size = root.cardSize(tileId);
        const grabX = (mappedGrabPoint.x - sourceRect.x) * size.width / Math.max(1, sourceRect.width);
        const grabY = (mappedGrabPoint.y - sourceRect.y) * size.height / Math.max(1, sourceRect.height);
        return SystemCardDragSession.promoteToPresentation(root.screenName, presentationPointer.x,
                                                           presentationPointer.y, grabX, grabY, size.width,
                                                           size.height, geometry.width, geometry.height);
    }

    function updateDrag(tileId, pointerLocalX, pointerLocalY) {
        if (tileId !== root.draggingTileId)
            return;

        if (root.desktopExtraction) {
            const presentationPointer = DesktopPresentationService.mapItemPoint(root.screenName,
                                                                                root.dragSourceItem,
                                                                                pointerLocalX, pointerLocalY);
            if (presentationPointer)
                SystemCardDragSession.update(presentationPointer.x, presentationPointer.y);

            return;
        }
        const sidebarPointer = root.dragSourceItem.mapToItem(null, pointerLocalX, pointerLocalY);
        if (!root.sidebarContainsPoint(sidebarPointer.x, sidebarPointer.y)) {
            if (!root.promoteToPresentation(tileId, root.dragSourceItem, pointerLocalX, pointerLocalY)) {
                root.cancelDrag(tileId);
                return;
            }
            root.desktopExtraction = true;
            root.previewLayout = [];
            root.dragTargetValid = false;
            root.targetX = -1;
            root.targetY = -1;
            return;
        }
        const localPoint = dashboard.mapFromItem(root.dragSourceItem, pointerLocalX, pointerLocalY);
        const sourceOrigin = dashboard.mapFromItem(root.dragSourceItem, 0, 0);
        const initialGrabPoint = dashboard.mapFromItem(root.dragSourceItem, SystemCardDragSession.grabLocalX,
                                                       SystemCardDragSession.grabLocalY);
        const grabVectorX = initialGrabPoint.x - sourceOrigin.x;
        const grabVectorY = initialGrabPoint.y - sourceOrigin.y;
        const definition = GridLayout.tileDefinitionFor(tileId);
        if (!definition)
            return;

        const anchor = GridLayout.clampAnchor(definition, localPoint.x - grabVectorX, localPoint.y
                                              - grabVectorY);
        if (anchor.x === root.targetX && anchor.y === root.targetY)
            return;
        root.targetX = anchor.x;
        root.targetY = anchor.y;
        const solved = GridLayout.moveLayout(root.committedLayout, tileId, anchor.x, anchor.y,
                                             root.activeSidebarIds);
        root.previewLayout = solved || [];
        root.dragTargetValid = solved !== null;
    }

    function finishDrag(tileId) {
        if (tileId !== root.draggingTileId)
            return;

        if (root.desktopExtraction) {
            // Every user drag commits the top-left corner in the output-local
            // screen coordinate system. The ghost and DesktopCard therefore
            // share the same geometry without touching wallpaper transforms.
            const output = {
                "width": SystemCardDragSession.hostWidth,
                "height": SystemCardDragSession.hostHeight
            };
            const size = SystemCardService.cardSize(tileId);
            let screenX = Math.max(0, Math.min(Math.max(0, output.width - size.width),
                                               SystemCardDragSession.ghostX));
            let screenY = Math.max(0, Math.min(Math.max(0, output.height - size.height),
                                               SystemCardDragSession.ghostY));
            if (PersonalizationConfig.desktopCardGridSnapEnabled) {
                const snapped = DesktopCardLayout.snapPoint(screenX, screenY, size.width, size.height,
                                                            output.width, output.height);
                screenX = snapped.x;
                screenY = snapped.y;
            }
            const normalized = Placement.normalizedPosition(screenX, screenY, output.width, output.height);
            if (!SystemCardDragSession.freezeGhost(screenX, screenY)) {
                SystemCardDragSession.cancel();
                root.resetDragState(false);
                return;
            }
            if (!SystemCardDragSession.prepareVisualHandoff(tileId)) {
                SystemCardDragSession.cancel();
                root.resetDragState(false);
                return;
            }
            // Resolve the drop against the live Desktop host before the
            // ownership transaction. The incoming card is authoritative at
            // the drop point; existing Desktop cards are the only cards that
            // may be displaced. This keeps Sidebar -> Desktop on the same
            // collision path as a free Desktop drag.
            const collisionRects = DesktopPresentationService.resolveDropCollision(root.screenName, tileId,
                                                                                   screenX, screenY,
                                                                                   size.width, size.height);
            const collisionPositions = [];
            if (Array.isArray(collisionRects))
                collisionRects.forEach(function (rect) {
                    if (!rect || typeof rect.id !== "string")
                        return;

                    const point = Placement.normalizedPosition(rect.x, rect.y, output.width, output.height);
                    collisionPositions.push({
                                                "id": rect.id,
                                                "xNorm": point.xNorm,
                                                "yNorm": point.yNorm
                                            });
                });

            if (collisionPositions.length === 0) {
                root.cancelDrag(tileId);
                return;
            }

            const committed = SystemCardService.transferToDesktop(tileId, root.screenName, normalized.xNorm,
                                                                  normalized.yNorm, collisionPositions,
                                                                  !SystemCardService.isFreeLayoutMode(
                                                                      SystemCardService.globalDesktopLayoutMode));
            const card = SystemCardService.card(tileId);
            if (!committed || !card || !card.enabled || card.container !== "desktop") {
                console.warn("[SystemCards] desktop transfer rejected", tileId);
                SystemCardDragSession.cancel();
                root.resetDragState(false);
                return;
            }
            if (!SystemCardDragSession.markTransferCommitted(tileId)) {
                console.warn("[SystemCards] desktop transfer commit failed", tileId);
                SystemCardDragSession.cancel();
                root.resetDragState(false);
                return;
            }
            SystemCardDragSession.requestVisualHandoffCheck(tileId);
            root.resetDragState(true);
            SystemCardDragSession.finishTransfer();
            return;
        }
        if (root.dragTargetValid) {
            root.committedLayout = root.previewLayout;
            SystemCardService.setSidebarLayout(root.committedLayout);
        }
        root.resetDragState(false);
    }

    function cancelDrag(tileId) {
        if (tileId && tileId !== root.draggingTileId)
            return;

        if (SystemCardDragSession.active)
            SystemCardDragSession.cancel();

        root.resetDragState(false);
    }

    function resetDragState(keepSession) {
        if (!keepSession && SystemCardDragSession.active)
            SystemCardDragSession.end();

        root.draggingTileId = "";
        root.dragSourceItem = null;
        root.previewLayout = [];
        root.dragTargetValid = false;
        root.targetX = -1;
        root.targetY = -1;
        root.desktopExtraction = false;
    }

    function syncServiceOwnership() {
        if (root.isForeground && !root.serviceForegroundAcquired) {
            SystemCardService.setSidebarForeground("sidebar:" + root.screenName, true);
            root.serviceForegroundAcquired = true;
        } else if (!root.isForeground && root.serviceForegroundAcquired) {
            SystemCardService.setSidebarForeground("sidebar:" + root.screenName, false);
            root.serviceForegroundAcquired = false;
        }
    }

    onIsForegroundChanged: root.syncServiceOwnership()
    onActiveSidebarIdsChanged: {
        if (root.draggingTileId.length === 0)
            root.applyStoredLayout(true);
    }
    Component.onCompleted: {
        root.applyStoredLayout();
        root.syncServiceOwnership();
    }
    Component.onDestruction: {
        if (root.draggingTileId !== "" && !SystemCardDragSession.transferCommitted)
            SystemCardDragSession.cancel();

        if (root.serviceForegroundAcquired)
            SystemCardService.setSidebarForeground("sidebar:" + root.screenName, false);
    }

    Connections {
        function onPreferencesReadyChanged() {
            root.applyStoredLayout();
        }

        function onDrawerGridLayoutChanged() {
            if (root.preferencesApplied)
                root.applyStoredLayout(true);
        }

        target: UiPreferences
    }

    Connections {
        function onCardStateChanged() {
            if (root.draggingTileId !== "") {
                const card = SystemCardService.card(root.draggingTileId);
                if (!card || !card.enabled) {
                    root.cancelDrag(root.draggingTileId);
                    return;
                }
            }
            root.applyStoredLayout(true);
        }

        function onPreferencesLoadedChanged() {
            root.applyStoredLayout();
        }
        target: SystemCardService
    }

    Connections {
        function onCancelRequested(tileId) {
            if (root.draggingTileId === String(tileId))
                root.cancelDrag(String(tileId));
        }

        function onCanceled() {
            // A destroyed source item can cancel the global session after
            // this page has stopped receiving pointer events.  Clear only
            // local gesture UI; no CardState rollback is performed here.
            if (root.draggingTileId !== "")
                root.resetDragState(false);
        }

        target: SystemCardDragSession
    }

    Item {
        anchors {
            fill: parent
            margins: Appearance.spacing.small
        }

        SystemLoadingState {
            anchors.fill: parent
            active: root.isForeground && !SystemMonitorService.error
            visible: !SystemMonitorService.hasData && !SystemMonitorService.error &&
                     !SystemMonitorService.reconnecting
            message: qsTr("Connecting to keytop")
        }

        SystemUnavailableState {
            visible: !SystemMonitorService.hasData && (SystemMonitorService.error
                                                       || SystemMonitorService.reconnecting)
            title: SystemMonitorService.reconnecting ? qsTr("Reconnecting") : qsTr(
                                                           "System monitoring is temporarily unavailable")
            message: SystemMonitorService.error ? qsTr(
                                                      "Data is temporarily unavailable; the page will retry in the background with backoff.") :
                                                  qsTr("The connection recovers automatically; existing data is never presented as current.")
            reconnecting: SystemMonitorService.reconnecting
            onRetryRequested: SystemMonitorService.retry()

            anchors {
                fill: parent
                topMargin: Appearance.spacing.large
                bottomMargin: Appearance.spacing.large
            }
        }

        StyledFlickable {
            id: dashboardScroll

            function scrollBy(delta) {
                const minimum = dashboardScroll.originY - dashboardScroll.topMargin;
                const maximum = Math.max(minimum, dashboardScroll.originY + dashboardScroll.contentHeight
                                         - dashboardScroll.height + dashboardScroll.bottomMargin);
                dashboardScroll.cancelFlick();
                dashboardScroll.contentY = Math.max(minimum, Math.min(maximum, dashboardScroll.contentY
                                                                      + delta));
            }

            anchors.fill: parent
            visible: SystemMonitorService.hasData
            contentWidth: width
            contentHeight: Math.max(height, root.gridContentHeight * dashboard.scale)
            // Keep wheel/touchpad scrolling enabled without letting Flickable
            // take the mouse gesture used to drag a card.
            acceptedButtons: Qt.NoButton
            interactive: root.isForeground && root.draggingTileId.length === 0
            showVerticalScrollBar: contentHeight > height + 1
            activeFocusOnTab: contentHeight > height + 1
            Accessible.name: contentHeight > height + 1 ? qsTr(
                                                              "Drawer grid; scrollable with draggable cards") :
                                                          qsTr("Drawer grid with draggable cards")
            Keys.onPressed: event => {
                if (root.draggingTileId.length > 0 && event.key === Qt.Key_Escape) {
                    root.cancelDrag();
                    event.accepted = true;
                    return;
                }
                if (dashboardScroll.contentHeight <= dashboardScroll.height + 1)
                    return;

                if (event.key === Qt.Key_Up)
                    dashboardScroll.scrollBy(-64);
                else if (event.key === Qt.Key_Down)
                    dashboardScroll.scrollBy(64);
                else if (event.key === Qt.Key_PageUp)
                    dashboardScroll.scrollBy(-dashboardScroll.height * 0.8);
                else if (event.key === Qt.Key_PageDown)
                    dashboardScroll.scrollBy(dashboardScroll.height * 0.8);
                else if (event.key === Qt.Key_Home)
                    dashboardScroll.scrollBy(-dashboardScroll.contentHeight);
                else if (event.key === Qt.Key_End)
                    dashboardScroll.scrollBy(dashboardScroll.contentHeight);
                else
                    return;
                event.accepted = true;
            }

            Item {
                id: dashboard

                // Preserve the shared card geometry and drag coordinates. Only a
                // constrained viewport shrinks the grid as a single surface.
                scale: Math.min(1, Math.max(0.01, dashboardScroll.width / root.gridContentWidth))
                transformOrigin: Item.TopLeft
                x: Math.max(0, Math.floor((dashboardScroll.width - root.gridContentWidth * scale) / 2))
                width: root.gridContentWidth
                height: root.gridContentHeight
                focus: root.draggingTileId.length > 0
                Keys.onEscapePressed: event => {
                    if (root.draggingTileId.length === 0)
                        return;

                    root.cancelDrag();
                    event.accepted = true;
                }

                Loader {
                    width: dashboard.width
                    height: dashboardScroll.height / dashboard.scale
                    y: Math.floor(dashboardScroll.contentY / dashboard.scale / 24) * 24
                    active: root.draggingTileId !== "" && !root.desktopExtraction
                    sourceComponent: SystemCardGridGuides {}
                }

                Rectangle {
                    id: targetPreview

                    x: root.targetX
                    y: root.targetY
                    width: {
                        const definition = GridLayout.tileDefinitionFor(root.draggingTileId);
                        return definition ? CardGeometry.widthForSpan(definition.columnSpan) : 0;
                    }
                    height: {
                        const definition = GridLayout.tileDefinitionFor(root.draggingTileId);
                        return definition ? CardGeometry.heightForSpan(definition.rowSpan) : 0;
                    }
                    visible: root.draggingTileId.length > 0 && !root.desktopExtraction && root.targetX >= 0
                             && root.targetY >= 0
                    radius: Appearance.rounding.extraLarge
                    color: Appearance.applyAlpha(root.dragTargetValid ? Appearance.colors.colPrimary :
                                                                        Appearance.colors.colError, 0.14)
                    border.width: 2
                    border.color: root.dragTargetValid ? Appearance.colors.colPrimary :
                                                         Appearance.colors.colError
                    z: 20

                    Behavior on x {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }
                }

                Repeater {
                    model: root.tileDefinitions

                    delegate: DrawerGridTile {
                        id: tile

                        required property var modelData
                        readonly property var definition: modelData
                        readonly property var placement: root.displayPlacement(tile.tileId)

                        tileId: definition.id
                        x: placement ? placement.x : 0
                        y: placement ? placement.y : 0
                        width: root.cardSize(tile.tileId).width
                        height: root.cardSize(tile.tileId).height
                        active: root.isForeground
                        motionEnabled: root.isForeground
                        dragging: root.draggingTileId === tile.tileId
                        z: dragging ? 30 : 1
                        onDragStarted: (tileId, sourceItem, grabLocalX, grabLocalY, pointerLocalX,
                                        pointerLocalY) => {
                                            return root.beginDrag(tileId, sourceItem, grabLocalX, grabLocalY,
                                                                  pointerLocalX, pointerLocalY);
                                        }
                        onDragMoved: (tileId, pointerLocalX, pointerLocalY) => {
                            return root.updateDrag(tileId, pointerLocalX, pointerLocalY);
                        }
                        onDragFinished: tileId => {
                            return root.finishDrag(tileId);
                        }
                        onDragCanceled: tileId => {
                            return root.cancelDrag(tileId);
                        }
                    }
                }
            }
        }
    }
}
