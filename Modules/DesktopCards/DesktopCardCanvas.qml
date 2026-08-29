import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "./DesktopCardLayout.js" as DesktopCardLayout
import "../SystemCards/SystemCardPlacement.js" as Placement

Item {
    id: root

    required property var scene
    required property string screenName
    property Item hostItem: root
    property Item inputSlot0: null
    property Item inputSlot1: null
    property Item inputSlot2: null
    property Item inputSlot3: null
    property Item inputSlot4: null
    property Item inputSlot5: null
    property Item inputSlot6: null
    property Item inputSlot7: null
    property Item inputSlot8: null
    property Item inputSlot9: null
    property Item inputSlot10: null
    readonly property var systemCardBlurExclusionItems: {
        const exclusions = [];
        for (let index = 0; index < cardRepeater.count; ++index) {
            const item = cardRepeater.itemAt(index);
            // Keep the metadata-backed subtraction regions alive across
            // cold-start CardState hydration. Region handles visibility and
            // zero-sized inactive slots itself.
            if (item && item.excludeHostBlur)
                exclusions.push(item);

        }
        return exclusions;
    }
    property var collisionPreviewPositions: ({
    })
    property string collisionDraggedId: ""
    readonly property var screenNames: {
        const result = [];
        for (let index = 0; index < Quickshell.screens.length; index += 1) result.push(String(Quickshell.screens[index].name))
        return result;
    }
    readonly property var desktopIds: {
        const cards = SystemCardService.cards;
        return cards ? SystemCardService.desktopIdsForScreen(root.screenName, root.screenNames) : [];
    }
    readonly property bool allActiveCardsPresented: {
        for (let index = 0; index < cardRepeater.count; index += 1) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active && !item.positionInitialized)
                return false;

        }
        return true;
    }
    readonly property bool screenTransitionActive: {
        for (let index = 0; index < cardRepeater.count; index += 1) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active && item.screenTransitionActive)
                return true;

        }
        return false;
    }
    readonly property bool anyCardDragging: {
        for (let index = 0; index < cardRepeater.count; index += 1) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active && item.dragging)
                return true;

        }
        return false;
    }
    readonly property bool externalCardDragging: SystemCardDragSession.presentationActive && SystemCardDragSession.screenName === root.screenName && SystemCardDragSession.presentationGhostRect.valid
    readonly property var activeDragRect: {
        if (root.collisionDraggedId !== "") {
            for (let index = 0; index < cardRepeater.count; index += 1) {
                const item = cardRepeater.itemAt(index);
                if (item && item.active && item.tileId === root.collisionDraggedId)
                    return item.visualRect();

            }
        }
        if (root.externalCardDragging) {
            const ghost = SystemCardDragSession.presentationGhostRect;
            const point = PersonalizationConfig.desktopCardGridSnapEnabled ? DesktopCardLayout.snapPoint(ghost.x, ghost.y, ghost.width, ghost.height, root.width, root.height) : {
                "x": ghost.x,
                "y": ghost.y
            };
            return {
                "x": point.x,
                "y": point.y,
                "width": ghost.width,
                "height": ghost.height
            };
        }
        return null;
    }

    signal delegateReady(string tileId)
    signal handoffReady(string tileId)
    signal screenTransitionsFinished()

    function inputItemAt(index) {
        return cardRepeater.itemAt(index);
    }

    function updateInputSlots() {
        root.inputSlot0 = root.inputItemAt(0);
        root.inputSlot1 = root.inputItemAt(1);
        root.inputSlot2 = root.inputItemAt(2);
        root.inputSlot3 = root.inputItemAt(3);
        root.inputSlot4 = root.inputItemAt(4);
        root.inputSlot5 = root.inputItemAt(5);
        root.inputSlot6 = root.inputItemAt(6);
        root.inputSlot7 = root.inputItemAt(7);
        root.inputSlot8 = root.inputItemAt(8);
        root.inputSlot9 = root.inputItemAt(9);
        root.inputSlot10 = root.inputItemAt(10);
    }

    function currentCollisionCards() {
        const cards = [];
        for (let index = 0; index < cardRepeater.count; index += 1) {
            const item = cardRepeater.itemAt(index);
            if (!item || !item.active)
                continue;

            const rect = item.visualRect();
            cards.push({
                "id": item.tileId,
                "x": rect.x,
                "y": rect.y,
                "width": rect.width,
                "height": rect.height
            });
        }
        return cards;
    }

    function beginCollisionPreview(tileId) {
        root.collisionDraggedId = String(tileId);
        root.collisionPreviewPositions = ({
        });
    }

    function updateCollisionPreview(tileId, x, y) {
        if (String(tileId) !== root.collisionDraggedId)
            return ;

        const source = root.currentCollisionCards();
        const dragged = source.find((item) => {
            return item.id === String(tileId);
        });
        if (!dragged)
            return ;

        const resolved = DesktopCardLayout.resolveDraggedCollision(source, tileId, {
            "x": Number(x),
            "y": Number(y),
            "width": dragged.width,
            "height": dragged.height
        }, root.width, root.height, PersonalizationConfig.desktopCardGridSnapEnabled);
        const preview = {
        };
        resolved.forEach(function(item) {
            if (item.id !== String(tileId))
                preview[item.id] = {
                "x": item.x,
                "y": item.y
            };

        });
        root.collisionPreviewPositions = preview;
    }

    function finishCollisionPreview(tileId, x, y) {
        if (String(tileId) !== root.collisionDraggedId)
            return [];

        root.updateCollisionPreview(tileId, x, y);
        const source = root.currentCollisionCards();
        const dragged = source.find((item) => {
            return item.id === String(tileId);
        });
        if (!dragged)
            return [];

        const resolved = DesktopCardLayout.resolveDraggedCollision(source, tileId, {
            "x": Number(x),
            "y": Number(y),
            "width": dragged.width,
            "height": dragged.height
        }, root.width, root.height, PersonalizationConfig.desktopCardGridSnapEnabled);
        return resolved.map(function(item) {
            return {
                "id": item.id,
                "xNorm": Placement.normalizedPosition(item.x, item.y, root.width, root.height).xNorm,
                "yNorm": Placement.normalizedPosition(item.x, item.y, root.width, root.height).yNorm
            };
        });
    }

    // Resolve an external Sidebar drop against the current visual Desktop
    // rectangles.  The incoming card is authoritative; only existing cards
    // may be displaced.  This is deliberately the same resolver used by a
    // Desktop free drag.
    function resolveExternalDrop(tileId, x, y, width, height) {
        const source = root.currentCollisionCards();
        source.push({
            "id": String(tileId),
            "x": Number(x),
            "y": Number(y),
            "width": Number(width),
            "height": Number(height)
        });
        return DesktopCardLayout.resolveDraggedCollision(source, String(tileId), {
            "x": Number(x),
            "y": Number(y),
            "width": Number(width),
            "height": Number(height)
        }, root.width, root.height, PersonalizationConfig.desktopCardGridSnapEnabled);
    }

    function resolveCurrentCollisionLayout(preferredId) {
        return DesktopCardLayout.resolveAllCollisions(root.currentCollisionCards(), String(preferredId || ""), root.width, root.height, DesktopCardLayout.desktopCardGap, PersonalizationConfig.desktopCardGridSnapEnabled);
    }

    function completeCollisionPreview() {
        root.collisionDraggedId = "";
        root.collisionPreviewPositions = ({
        });
    }

    function prepareScreenLayoutTransition(placements) {
        if (!Array.isArray(placements))
            return false;

        let prepared = false;
        placements.forEach(function(placement) {
            let item = null;
            for (let index = 0; index < cardRepeater.count; index += 1) {
                const candidate = cardRepeater.itemAt(index);
                if (candidate && candidate.tileId === String(placement.id)) {
                    item = candidate;
                    break;
                }
            }
            if (!item || !item.active)
                return ;

            const target = Placement.screenPoint(placement.xNorm, placement.yNorm, root.width, root.height, item.size.width, item.size.height);
            prepared = item.prepareScreenTransition(target.x, target.y) || prepared;
        });
        return prepared;
    }

    function startScreenLayoutTransition() {
        for (let index = 0; index < cardRepeater.count; index += 1) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active && item.screenTransitionActive)
                item.startScreenTransition();

        }
    }

    function isActive(id) {
        return root.desktopIds.indexOf(String(id)) !== -1;
    }

    function screenPositionFor(state, size) {
        return Placement.screenPoint(state.desktop.screen.xNorm, state.desktop.screen.yNorm, root.width, root.height, size.width, size.height);
    }

    function wallpaperPositionFor(state, size) {
        if (!root.scene)
            return {
            "x": 0,
            "y": 0
        };

        return Placement.wallpaperPoint(state.desktop.wallpaper.xNorm, state.desktop.wallpaper.yNorm, root.scene.canvasWidth, root.scene.canvasHeight, size.width, size.height);
    }

    // Convert the currently displayed screen rect to the normalized screen
    // state in one batch. This is the only operation used when switching an
    // automatic wallpaper layout back to free mode.
    function promoteCardsToScreen() {
        if (root.width <= 1 || root.height <= 1)
            return ;

        const positions = [];
        for (let index = 0; index < cardRepeater.count; ++index) {
            const item = cardRepeater.itemAt(index);
            if (!item || !item.active)
                continue;

            if (item.placementSpace === Placement.wallpaper && !root.scene)
                continue;

            const point = item.captureVisualScreenPosition();
            positions.push({
                "id": item.tileId,
                "xNorm": Placement.normalizedPosition(point.x, point.y, root.width, root.height).xNorm,
                "yNorm": Placement.normalizedPosition(point.x, point.y, root.width, root.height).yNorm
            });
        }
        SystemCardService.setDesktopScreenPositions(positions);
        for (let index = 0; index < cardRepeater.count; ++index) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active)
                item.finishScreenPromotion();

        }
    }

    // Automatic solving writes wallpaper targets first. Screen-placed cards
    // then animate from their visible screen rect into the live wallpaper
    // projection. The slot's target is evaluated every frame, so parallax can
    // continue while the space migration is in progress.
    function startAutomaticTransitions() {
        if (!SystemCardService.isWallpaperLayoutMode(SystemCardService.globalDesktopLayoutMode))
            return ;

        for (let index = 0; index < cardRepeater.count; ++index) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active)
                item.beginWallpaperTransition();

        }
    }

    // The canvas is always the output-local screen coordinate system. A
    // wallpaper transform is an input to wallpaper-anchored slots; it never
    // moves this item or creates a second handoff coordinate system.
    x: 0
    y: 0
    Component.onCompleted: root.updateInputSlots()

    DesktopCardGridOverlay {
        anchors.fill: parent
        active: (root.anyCardDragging || root.externalCardDragging) && PersonalizationConfig.desktopCardGridVisibleWhileDragging
        highlightRect: root.activeDragRect
    }

    Repeater {
        id: cardRepeater

        model: SystemCardService.cardIds
        onItemAdded: root.updateInputSlots()
        onItemRemoved: root.updateInputSlots()

        delegate: Item {
            id: slot

            required property string modelData
            readonly property string tileId: modelData
            readonly property var cardState: SystemCardService.cards[slot.tileId] || null
            readonly property bool active: root.isActive(slot.tileId) && cardState !== null && cardState.enabled
            readonly property bool excludeHostBlur: SystemCardService.cardExcludesHostBlur(slot.tileId)
            readonly property var size: SystemCardService.cardSize(slot.tileId)
            readonly property string placementSpace: active && cardState.desktop ? String(cardState.desktop.placementSpace || "screen") : Placement.screen
            readonly property var screenTarget: active ? root.screenPositionFor(cardState, size) : ({
                "x": 0,
                "y": 0
            })
            readonly property var wallpaperTarget: active ? root.wallpaperPositionFor(cardState, size) : ({
                "x": 0,
                "y": 0
            })
            property real layoutWallpaperX: wallpaperTarget.x
            property real layoutWallpaperY: wallpaperTarget.y
            property bool positionInitialized: false
            property bool handoffReadySent: false
            property bool wallpaperTransitionActive: false
            property real wallpaperTransitionProgress: 0
            property real transitionStartX: 0
            property real transitionStartY: 0
            property bool screenTransitionActive: false
            property real screenTransitionProgress: 0
            property real screenTransitionStartX: 0
            property real screenTransitionStartY: 0
            property real screenTransitionTargetX: 0
            property real screenTransitionTargetY: 0
            readonly property bool dragging: cardLoader.item && cardLoader.item.dragging
            readonly property var collisionPreviewPosition: root.collisionPreviewPositions[slot.tileId] || null
            readonly property real projectedWallpaperX: slot.layoutWallpaperX + Number(root.scene ? root.scene.animatedOffsetX : 0)
            readonly property real projectedWallpaperY: slot.layoutWallpaperY + Number(root.scene ? root.scene.animatedOffsetY : 0)
            readonly property bool positionReady: slot.active && root.width > 1 && root.height > 1 && cardLoader.item !== null
            readonly property bool waitingForVisualHandoff: slot.active && SystemCardDragSession.visualHandoffPending && SystemCardDragSession.tileId === slot.tileId
            readonly property real visualScreenX: slot.dragging ? cardLoader.item.dragX : slot.collisionPreviewPosition !== null ? slot.collisionPreviewPosition.x : slot.screenTransitionActive ? Placement.interpolate(slot.screenTransitionStartX, slot.screenTransitionTargetX, slot.screenTransitionProgress) : slot.wallpaperTransitionActive ? Placement.interpolate(slot.transitionStartX, slot.projectedWallpaperX, slot.wallpaperTransitionProgress) : slot.placementSpace === Placement.screen ? slot.screenTarget.x : slot.projectedWallpaperX
            readonly property real visualScreenY: slot.dragging ? cardLoader.item.dragY : slot.collisionPreviewPosition !== null ? slot.collisionPreviewPosition.y : slot.screenTransitionActive ? Placement.interpolate(slot.screenTransitionStartY, slot.screenTransitionTargetY, slot.screenTransitionProgress) : slot.wallpaperTransitionActive ? Placement.interpolate(slot.transitionStartY, slot.projectedWallpaperY, slot.wallpaperTransitionProgress) : slot.placementSpace === Placement.screen ? slot.screenTarget.y : slot.projectedWallpaperY

            function visualRect() {
                return {
                    "x": slot.visualScreenX,
                    "y": slot.visualScreenY,
                    "width": slot.width,
                    "height": slot.height
                };
            }

            function captureVisualScreenPosition() {
                return {
                    "x": slot.visualScreenX,
                    "y": slot.visualScreenY
                };
            }

            function finishScreenPromotion() {
                slot.wallpaperTransitionActive = false;
                wallpaperTransition.stop();
                slot.wallpaperTransitionProgress = 0;
                slot.screenTransitionActive = false;
                screenTransition.stop();
                slot.screenTransitionProgress = 0;
            }

            function beginCardDrag() {
                const point = slot.captureVisualScreenPosition();
                // Desktop dragging is enabled only in free mode. It must
                // not silently change global policy or migrate an automatic
                // card between coordinate spaces.
                slot.wallpaperTransitionActive = false;
                wallpaperTransition.stop();
                slot.wallpaperTransitionProgress = 0;
                root.beginCollisionPreview(slot.tileId);
                return point;
            }

            function updateCardDrag(x, y) {
                root.updateCollisionPreview(slot.tileId, x, y);
            }

            function finishCardDrag(x, y) {
                return root.finishCollisionPreview(slot.tileId, x, y);
            }

            function completeCardDrag() {
                root.completeCollisionPreview();
            }

            function cancelCardDrag() {
                root.completeCollisionPreview();
                SystemCardService.requestDesktopLayout();
            }

            function prepareScreenTransition(targetX, targetY) {
                const currentX = slot.visualScreenX;
                const currentY = slot.visualScreenY;
                if (Math.abs(currentX - Number(targetX)) <= 0.5 && Math.abs(currentY - Number(targetY)) <= 0.5) {
                    slot.screenTransitionActive = false;
                    return false;
                }
                slot.screenTransitionStartX = currentX;
                slot.screenTransitionStartY = currentY;
                slot.screenTransitionTargetX = Number(targetX);
                slot.screenTransitionTargetY = Number(targetY);
                slot.screenTransitionProgress = 0;
                slot.screenTransitionActive = true;
                return true;
            }

            function startScreenTransition() {
                if (slot.screenTransitionActive)
                    screenTransition.restart();

            }

            function finishScreenTransition() {
                if (!slot.screenTransitionActive)
                    return ;

                slot.screenTransitionProgress = 1;
                slot.screenTransitionActive = false;
                slot.screenTransitionProgress = 0;
                if (!root.screenTransitionActive)
                    root.screenTransitionsFinished();

            }

            function beginWallpaperTransition() {
                if (!slot.active || slot.placementSpace !== Placement.screen || slot.waitingForVisualHandoff || slot.wallpaperTransitionActive)
                    return false;

                slot.transitionStartX = slot.visualScreenX;
                slot.transitionStartY = slot.visualScreenY;
                slot.wallpaperTransitionProgress = 0;
                slot.wallpaperTransitionActive = true;
                wallpaperTransition.restart();
                return true;
            }

            function finishWallpaperTransition() {
                if (!slot.wallpaperTransitionActive)
                    return ;

                slot.wallpaperTransitionProgress = 1;
                // The last animated frame already projects the wallpaper
                // target. Commit the new space only after that frame exists.
                SystemCardService.setPlacementSpace(slot.tileId, Placement.wallpaper);
                slot.wallpaperTransitionActive = false;
                slot.wallpaperTransitionProgress = 0;
            }

            function prepareHandoff() {
                const ghost = SystemCardDragSession.presentationGhostRect;
                if (!ghost || !ghost.valid || slot.placementSpace !== Placement.screen)
                    return false;

                const actual = slot.visualRect();
                const matches = Math.abs(actual.x - ghost.x) <= 1 && Math.abs(actual.y - ghost.y) <= 1 && Math.abs(actual.width - ghost.width) <= 1 && Math.abs(actual.height - ghost.height) <= 1;
                if (!matches) {
                    console.warn("[DesktopCards] screen handoff geometry mismatch", slot.tileId, "ghost=" + ghost.x + "," + ghost.y, "desktop=" + actual.x + "," + actual.y);
                    return false;
                }
                slot.handoffReadySent = true;
                return true;
            }

            function presentIfReady() {
                if (!slot.positionReady)
                    return ;

                if (!slot.positionInitialized) {
                    slot.positionInitialized = true;
                    root.delegateReady(slot.tileId);
                }
                if (slot.waitingForVisualHandoff && SystemCardDragSession.transferCommitted && !slot.handoffReadySent && slot.prepareHandoff())
                    root.handoffReady(slot.tileId);

            }

            x: slot.visualScreenX
            y: slot.visualScreenY
            width: active ? size.width : 0
            height: active ? size.height : 0
            visible: active && !slot.waitingForVisualHandoff
            onActiveChanged: {
                wallpaperTransition.stop();
                screenTransition.stop();
                slot.wallpaperTransitionActive = false;
                slot.wallpaperTransitionProgress = 0;
                slot.screenTransitionActive = false;
                slot.screenTransitionProgress = 0;
                slot.handoffReadySent = false;
                slot.positionInitialized = false;
                if (active)
                    slot.presentIfReady();

            }
            onPositionReadyChanged: slot.presentIfReady()
            onPlacementSpaceChanged: slot.presentIfReady()
            Component.onCompleted: slot.presentIfReady()

            Connections {
                function onHandoffCheckRequested(tileId) {
                    if (String(tileId) === slot.tileId)
                        slot.presentIfReady();

                }

                target: SystemCardDragSession
            }

            Loader {
                id: cardLoader

                anchors.fill: parent
                active: slot.active
                onItemChanged: slot.presentIfReady()

                sourceComponent: Component {
                    DesktopCard {
                        anchors.fill: parent
                        tileId: slot.tileId
                        hostItem: root.hostItem
                        placementController: slot
                    }

                }

            }

            NumberAnimation {
                id: wallpaperTransition

                target: slot
                property: "wallpaperTransitionProgress"
                from: 0
                to: 1
                duration: Appearance.animation.desktopCardReflow.duration
                easing.type: Appearance.animation.desktopCardReflow.type
                easing.bezierCurve: Appearance.animation.desktopCardReflow.bezierCurve
                onStopped: slot.finishWallpaperTransition()
            }

            NumberAnimation {
                id: screenTransition

                target: slot
                property: "screenTransitionProgress"
                from: 0
                to: 1
                duration: Appearance.animation.desktopCardReflow.duration
                easing.type: Appearance.animation.desktopCardReflow.type
                easing.bezierCurve: Appearance.animation.desktopCardReflow.bezierCurve
                onStopped: slot.finishScreenTransition()
            }

            Behavior on x {
                enabled: slot.positionInitialized && slot.active && !slot.dragging && slot.collisionPreviewPosition !== null

                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve: Appearance.animation.desktopCardReflow.bezierCurve
                }

            }

            Behavior on y {
                enabled: slot.positionInitialized && slot.active && !slot.dragging && slot.collisionPreviewPosition !== null

                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve: Appearance.animation.desktopCardReflow.bezierCurve
                }

            }

            Behavior on layoutWallpaperX {
                enabled: slot.positionInitialized && slot.active && slot.placementSpace === Placement.wallpaper && !slot.wallpaperTransitionActive && !slot.dragging

                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve: Appearance.animation.desktopCardReflow.bezierCurve
                }

            }

            Behavior on layoutWallpaperY {
                enabled: slot.positionInitialized && slot.active && slot.placementSpace === Placement.wallpaper && !slot.wallpaperTransitionActive && !slot.dragging

                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve: Appearance.animation.desktopCardReflow.bezierCurve
                }

            }

        }

    }

    Connections {
        function onCardStateChanged() {
            Qt.callLater(root.updateInputSlots);
        }

        target: SystemCardService
    }

}
