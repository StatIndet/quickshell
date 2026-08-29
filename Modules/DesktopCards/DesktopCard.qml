import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common
import qs.Services
import qs.Modules.SystemCards
import "./DesktopCardLayout.js" as DesktopCardLayout

Item {
    id: root

    required property string tileId
    required property Item hostItem
    property bool active: true
    property bool dragging: false
    property var placementController: null
    property real dragX: 0
    property real dragY: 0
    property real rawDragX: 0
    property real rawDragY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    readonly property var cardState: SystemCardService.cards[root.tileId] || null
    readonly property bool canDrag: root.active && root.hostItem !== null && SystemCardService.isFreeLayoutMode(SystemCardService.globalDesktopLayoutMode)

    function updateDragPosition(x, y) {
        root.rawDragX = Number(x);
        root.rawDragY = Number(y);
        const point = PersonalizationConfig.desktopCardGridSnapEnabled ? DesktopCardLayout.snapPoint(root.rawDragX, root.rawDragY, root.width, root.height, root.hostItem.width, root.hostItem.height) : {
            "x": root.rawDragX,
            "y": root.rawDragY
        };
        root.dragX = point.x;
        root.dragY = point.y;
        if (root.placementController && typeof root.placementController.updateCardDrag === "function")
            root.placementController.updateCardDrag(root.dragX, root.dragY);

    }

    Accessible.role: Accessible.Pane
    Accessible.name: SystemCardService.cardName(root.tileId)
    scale: root.dragging ? 1.025 : 1

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        visible: cardContent.shellManagedSurface
        color: BlurService.solidBackgroundColor(Appearance.m3colors.m3surfaceContainerHigh)
    }

    SystemCardContent {
        id: cardContent

        anchors.fill: parent
        tileId: root.tileId
        active: true
        useShellManagedSurface: true
    }

    HoverHandler {
        cursorShape: !root.canDrag ? Qt.ArrowCursor : dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    DragHandler {
        id: dragHandler

        property bool started: false

        function hostPoint() {
            return root.mapToItem(root.hostItem, centroid.position.x, centroid.position.y);
        }

        function screenBounds() {
            return {
                "width": Math.max(1, Number(root.hostItem.width) || 1),
                "height": Math.max(1, Number(root.hostItem.height) || 1)
            };
        }

        target: null
        enabled: root.canDrag
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
        onActiveChanged: {
            if (active) {
                started = true;
                const point = dragHandler.hostPoint();
                const visibleTopLeft = root.mapToItem(root.hostItem, 0, 0);
                if (root.placementController && typeof root.placementController.beginCardDrag === "function") {
                    const presented = root.placementController.beginCardDrag();
                    if (presented) {
                        visibleTopLeft.x = Number(presented.x);
                        visibleTopLeft.y = Number(presented.y);
                    }
                }
                root.dragOffsetX = point.x - visibleTopLeft.x;
                root.dragOffsetY = point.y - visibleTopLeft.y;
                root.dragging = true;
                root.updateDragPosition(visibleTopLeft.x, visibleTopLeft.y);
            } else if (started) {
                started = false;
                const bounds = dragHandler.screenBounds();
                let positions = [];
                if (root.placementController && typeof root.placementController.finishCardDrag === "function")
                    positions = root.placementController.finishCardDrag(root.dragX, root.dragY);

                if (Array.isArray(positions) && positions.length > 0) {
                    SystemCardService.setDesktopScreenPositions(positions, !SystemCardService.isFreeLayoutMode(SystemCardService.globalDesktopLayoutMode));
                } else {
                    const xNorm = root.dragX / bounds.width;
                    const yNorm = root.dragY / bounds.height;
                    SystemCardService.setDesktopScreenPosition(root.tileId, xNorm, yNorm, !SystemCardService.isFreeLayoutMode(SystemCardService.globalDesktopLayoutMode));
                }
                root.dragging = false;
                if (root.placementController && typeof root.placementController.completeCardDrag === "function")
                    root.placementController.completeCardDrag();

            }
        }
        onCentroidChanged: {
            if (!active)
                return ;

            const point = dragHandler.hostPoint();
            const bounds = dragHandler.screenBounds();
            const x = Math.max(0, Math.min(bounds.width - root.width, point.x - root.dragOffsetX));
            const y = Math.max(0, Math.min(bounds.height - root.height, point.y - root.dragOffsetY));
            root.updateDragPosition(x, y);
        }
        onCanceled: {
            const visibleTopLeft = root.mapToItem(root.hostItem, 0, 0);
            started = false;
            root.dragging = false;
            if (root.placementController && typeof root.placementController.cancelCardDrag === "function")
                root.placementController.cancelCardDrag(visibleTopLeft.x, visibleTopLeft.y);

        }
    }

    MouseArea {
        id: contextPointer

        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        hoverEnabled: true
        onPressed: menu.open()
    }

    Menu {
        id: menu

        Material.theme: Material.System
        Material.accent: Appearance.colors.colPrimary

        MenuItem {
            text: qsTr("收回到侧边栏")
            onTriggered: SystemCardService.setContainer(root.tileId, "sidebar", "")
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
        }

    }

}
