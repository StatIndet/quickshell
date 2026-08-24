import QtQuick
import M3Shapes
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Modules.SystemCards
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
        if (SystemCardDragSession.active && SystemCardDragSession.tileId !== "" && ids.indexOf(SystemCardDragSession.tileId) === -1)
            ids.push(SystemCardDragSession.tileId);

        return ids;
    }
    readonly property var tileDefinitions: GridLayout.definitions(root.activeSidebarIds)
    readonly property int gridColumns: GridLayout.columnCount
    readonly property int gridRows: GridLayout.contentRowCount(root.committedLayout, root.activeSidebarIds)
    readonly property real gridGap: CardGeometry.cellGap
    readonly property int gridCellWidth: CardGeometry.baseCellWidth
    readonly property int gridCellHeight: CardGeometry.baseCellHeight
    readonly property int gridContentWidth: root.gridColumns * root.gridCellWidth + (root.gridColumns - 1) * root.gridGap
    readonly property int gridContentHeight: root.gridRows * root.gridCellHeight + (root.gridRows - 1) * root.gridGap
    readonly property var sidebarAnchors: {
        const result = {
        };
        root.activeSidebarIds.forEach(function(id) {
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
    property int targetColumn: -1
    property int targetRow: -1
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
        if ((!forceRefresh && root.preferencesApplied) || !UiPreferences.preferencesReady || root.draggingTileId.length > 0)
            return ;

        const hydrated = GridLayout.hydrateSaved(UiPreferences.drawerGridLayout, root.activeSidebarIds, root.sidebarAnchors);
        const normalized = GridLayout.serializeLayout(hydrated, root.activeSidebarIds);
        root.committedLayout = hydrated;
        root.preferencesApplied = true;
        if (JSON.stringify(normalized) !== JSON.stringify(UiPreferences.drawerGridLayout || {
        }))
            UiPreferences.setDrawerGridLayout(normalized);

    }

    function beginDrag(tileId, sourceItem, grabLocalX, grabLocalY, pointerLocalX, pointerLocalY) {
        if (root.draggingTileId.length > 0)
            root.cancelDrag();

        if (!SystemCardDragSession.begin(tileId, sourceItem, grabLocalX, grabLocalY))
            return ;

        root.draggingTileId = tileId;
        root.dragSourceItem = sourceItem;
        root.targetColumn = -1;
        root.targetRow = -1;
        root.dragTargetValid = false;
        root.desktopExtraction = false;
        dashboard.forceActiveFocus();
        root.updateDrag(tileId, pointerLocalX, pointerLocalY);
    }

    function promoteToPresentation(tileId, sourceItem, pointerLocalX, pointerLocalY) {
        const geometry = DesktopPresentationService.geometry(root.screenName);
        const sourceRect = DesktopPresentationService.mapItemRect(root.screenName, sourceItem);
        const mappedGrabPoint = DesktopPresentationService.mapItemPoint(root.screenName, sourceItem, SystemCardDragSession.grabLocalX, SystemCardDragSession.grabLocalY);
        const presentationPointer = DesktopPresentationService.mapItemPoint(root.screenName, sourceItem, pointerLocalX, pointerLocalY);
        if (!geometry || !sourceRect || !mappedGrabPoint || !presentationPointer) {
            console.warn("[SystemCards] presentation host unavailable", root.screenName, tileId);
            return false;
        }
        return SystemCardDragSession.promoteToPresentation(root.screenName, presentationPointer.x, presentationPointer.y, mappedGrabPoint.x - sourceRect.x, mappedGrabPoint.y - sourceRect.y, sourceRect.width, sourceRect.height, geometry.width, geometry.height);
    }

    function updateDrag(tileId, pointerLocalX, pointerLocalY) {
        if (tileId !== root.draggingTileId)
            return ;

        if (root.desktopExtraction) {
            const presentationPointer = DesktopPresentationService.mapItemPoint(root.screenName, root.dragSourceItem, pointerLocalX, pointerLocalY);
            if (presentationPointer)
                SystemCardDragSession.update(presentationPointer.x, presentationPointer.y);

            return ;
        }
        const sidebarPointer = root.dragSourceItem.mapToItem(null, pointerLocalX, pointerLocalY);
        if (!root.sidebarContainsPoint(sidebarPointer.x, sidebarPointer.y)) {
            if (!root.promoteToPresentation(tileId, root.dragSourceItem, pointerLocalX, pointerLocalY)) {
                root.cancelDrag(tileId);
                return ;
            }
            root.desktopExtraction = true;
            root.previewLayout = [];
            root.dragTargetValid = false;
            root.targetColumn = -1;
            root.targetRow = -1;
            return ;
        }
        const localPoint = dashboard.mapFromItem(root.dragSourceItem, pointerLocalX, pointerLocalY);
        const sourceOrigin = dashboard.mapFromItem(root.dragSourceItem, 0, 0);
        const initialGrabPoint = dashboard.mapFromItem(root.dragSourceItem, SystemCardDragSession.grabLocalX, SystemCardDragSession.grabLocalY);
        const grabVectorX = initialGrabPoint.x - sourceOrigin.x;
        const grabVectorY = initialGrabPoint.y - sourceOrigin.y;
        const definition = GridLayout.tileDefinitionFor(tileId);
        if (!definition)
            return ;

        const rawColumn = Math.round((localPoint.x - grabVectorX) / dashboard.columnStride);
        const rawRow = Math.round((localPoint.y - grabVectorY) / dashboard.rowStride);
        const anchor = GridLayout.clampAnchor(definition, rawColumn, rawRow);
        if (anchor.column === root.targetColumn && anchor.row === root.targetRow)
            return ;

        root.targetColumn = anchor.column;
        root.targetRow = anchor.row;
        const solved = GridLayout.moveLayout(root.committedLayout, tileId, anchor.column, anchor.row, root.activeSidebarIds);
        root.previewLayout = solved || [];
        root.dragTargetValid = solved !== null;
    }

    function finishDrag(tileId) {
        if (tileId !== root.draggingTileId)
            return ;

        if (root.desktopExtraction) {
            // Every user drag commits the top-left corner in the output-local
            // screen coordinate system. The ghost and DesktopCard therefore
            // share the same geometry without touching wallpaper transforms.
            const output = {
                "width": SystemCardDragSession.hostWidth,
                "height": SystemCardDragSession.hostHeight
            };
            const size = SystemCardService.cardSize(tileId);
            const screenX = Math.max(0, Math.min(Math.max(0, output.width - size.width), SystemCardDragSession.ghostX));
            const screenY = Math.max(0, Math.min(Math.max(0, output.height - size.height), SystemCardDragSession.ghostY));
            const normalized = Placement.normalizedPosition(screenX, screenY, output.width, output.height);
            if (!SystemCardDragSession.freezeGhost(screenX, screenY)) {
                SystemCardDragSession.cancel();
                root.resetDragState(false);
                return ;
            }
            if (!SystemCardDragSession.prepareVisualHandoff(tileId)) {
                SystemCardDragSession.cancel();
                root.resetDragState(false);
                return ;
            }
            // Resolve the drop against the live Desktop host before the
            // ownership transaction. The incoming card is authoritative at
            // the drop point; existing Desktop cards are the only cards that
            // may be displaced. This keeps Sidebar -> Desktop on the same
            // collision path as a free Desktop drag.
            const collisionRects = DesktopPresentationService.resolveDropCollision(root.screenName, tileId, screenX, screenY, size.width, size.height);
            const collisionPositions = [];
            if (Array.isArray(collisionRects))
                collisionRects.forEach(function(rect) {
                if (!rect || typeof rect.id !== "string")
                    return ;

                const point = Placement.normalizedPosition(rect.x, rect.y, output.width, output.height);
                collisionPositions.push({
                    "id": rect.id,
                    "xNorm": point.xNorm,
                    "yNorm": point.yNorm
                });
            });

            if (collisionPositions.length === 0)
                collisionPositions.push({
                "id": tileId,
                "xNorm": normalized.xNorm,
                "yNorm": normalized.yNorm
            });

            const committed = SystemCardService.transferToDesktop(tileId, root.screenName, normalized.xNorm, normalized.yNorm, collisionPositions, !SystemCardService.isFreeLayoutMode(SystemCardService.globalDesktopLayoutMode));
            const card = SystemCardService.card(tileId);
            if (!committed || !card || !card.enabled || card.container !== "desktop") {
                console.warn("[SystemCards] desktop transfer rejected", tileId);
                SystemCardDragSession.cancel();
                root.resetDragState(false);
                return ;
            }
            if (!SystemCardDragSession.markTransferCommitted(tileId)) {
                console.warn("[SystemCards] desktop transfer commit failed", tileId);
                SystemCardDragSession.cancel();
                root.resetDragState(false);
                return ;
            }
            SystemCardDragSession.requestVisualHandoffCheck(tileId);
            root.resetDragState(true);
            WidgetState.leftSidebarOpen = false;
            SystemCardDragSession.finishTransfer();
            return ;
        }
        if (root.dragTargetValid) {
            root.committedLayout = root.previewLayout;
            UiPreferences.setDrawerGridLayout(GridLayout.serializeLayout(root.committedLayout, root.activeSidebarIds));
            SystemCardService.setSidebarLayout(root.committedLayout);
        }
        root.resetDragState(false);
    }

    function cancelDrag(tileId) {
        if (tileId && tileId !== root.draggingTileId)
            return ;

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
        root.targetColumn = -1;
        root.targetRow = -1;
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
                    return ;
                }
            }
            root.applyStoredLayout(true);
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
            visible: !SystemMonitorService.hasData && !SystemMonitorService.error && !SystemMonitorService.reconnecting
            message: qsTr("正在连接 keytop")
        }

        SystemUnavailableState {
            visible: !SystemMonitorService.hasData && (SystemMonitorService.error || SystemMonitorService.reconnecting)
            title: SystemMonitorService.reconnecting ? qsTr("正在重新连接") : qsTr("系统监测暂不可用")
            message: SystemMonitorService.error ? qsTr("数据暂时缺失，页面将在后台退避重试。") : qsTr("连接中断后会自动恢复；已有数据不会被伪装成正常值。")
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
                const next = dashboardScroll.clampContentY(dashboardScroll.contentY + delta);
                dashboardScroll.scrollTargetY = next;
                dashboardScroll.contentY = next;
            }

            anchors.fill: parent
            visible: SystemMonitorService.hasData
            contentWidth: width
            contentHeight: Math.max(height, root.gridContentHeight)
            // This page scrolls through wheel/touchpad and keyboard input.
            // Flickable's direct mouse drag otherwise competes with the
            // DrawerGridTile DragHandler and interactive card controls.
            interactive: false
            fasterTouchpadScroll: true
            showVerticalScrollBar: contentHeight > height + 1
            activeFocusOnTab: contentHeight > height + 1
            Accessible.name: contentHeight > height + 1 ? qsTr("抽屉网格，可滚动并可拖动卡片") : qsTr("抽屉网格，可拖动卡片")
            Keys.onPressed: (event) => {
                if (root.draggingTileId.length > 0 && event.key === Qt.Key_Escape) {
                    root.cancelDrag();
                    event.accepted = true;
                    return ;
                }
                if (dashboardScroll.contentHeight <= dashboardScroll.height + 1)
                    return ;

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
                    return ;
                event.accepted = true;
            }

            Item {
                id: dashboard

                readonly property int cellWidth: root.gridCellWidth
                readonly property int cellHeight: root.gridCellHeight
                readonly property real columnStride: cellWidth + root.gridGap
                readonly property real rowStride: cellHeight + root.gridGap

                x: Math.max(0, Math.floor((dashboardScroll.width - root.gridContentWidth) / 2))
                width: root.gridContentWidth
                height: root.gridContentHeight
                focus: root.draggingTileId.length > 0
                Keys.onEscapePressed: (event) => {
                    if (root.draggingTileId.length === 0)
                        return ;

                    root.cancelDrag();
                    event.accepted = true;
                }

                Rectangle {
                    id: targetPreview

                    x: root.targetColumn * dashboard.columnStride
                    y: root.targetRow * dashboard.rowStride
                    width: {
                        const definition = GridLayout.tileDefinitionFor(root.draggingTileId);
                        return definition ? CardGeometry.widthForSpan(definition.columnSpan) : 0;
                    }
                    height: {
                        const definition = GridLayout.tileDefinitionFor(root.draggingTileId);
                        return definition ? CardGeometry.heightForSpan(definition.rowSpan) : 0;
                    }
                    visible: root.draggingTileId.length > 0 && !root.desktopExtraction && root.targetColumn >= 0 && root.targetRow >= 0
                    radius: Appearance.rounding.extraLarge
                    color: Appearance.applyAlpha(root.dragTargetValid ? Appearance.colors.colPrimary : Appearance.colors.colError, 0.14)
                    border.width: 2
                    border.color: root.dragTargetValid ? Appearance.colors.colPrimary : Appearance.colors.colError
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
                    id: tileRepeater

                    model: root.tileDefinitions

                    delegate: DrawerGridTile {
                        id: tile

                        required property var modelData
                        readonly property var definition: modelData
                        readonly property var placement: root.displayPlacement(tile.tileId)

                        tileId: definition.id
                        x: placement ? placement.column * dashboard.columnStride : 0
                        y: placement ? placement.row * dashboard.rowStride : 0
                        width: root.cardSize(tile.tileId).width
                        height: root.cardSize(tile.tileId).height
                        active: root.isForeground
                        dragging: root.draggingTileId === tile.tileId
                        z: dragging ? 30 : 1
                        onDragStarted: (tileId, sourceItem, grabLocalX, grabLocalY, pointerLocalX, pointerLocalY) => {
                            return root.beginDrag(tileId, sourceItem, grabLocalX, grabLocalY, pointerLocalX, pointerLocalY);
                        }
                        onDragMoved: (tileId, pointerLocalX, pointerLocalY) => {
                            return root.updateDrag(tileId, pointerLocalX, pointerLocalY);
                        }
                        onDragFinished: (tileId) => {
                            return root.finishDrag(tileId);
                        }
                        onDragCanceled: (tileId) => {
                            return root.cancelDrag(tileId);
                        }
                    }

                }

            }

        }

    }

}
