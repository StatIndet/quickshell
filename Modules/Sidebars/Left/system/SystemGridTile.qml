import QtQuick
import qs.Common

Item {
    id: root

    required property string tileId
    property Component sourceComponent
    property bool dragging: false
    property bool motionEnabled: true
    readonly property Item contentItem: cardLoader.item

    signal dragStarted(
        string tileId,
        Item sourceItem,
        real pointerX,
        real pointerY
    )
    signal dragMoved(string tileId, real pointerX, real pointerY)
    signal dragFinished(string tileId)
    signal dragCanceled(string tileId)

    Accessible.role: Accessible.Pane

    Behavior on x {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve:
                Appearance.animation.expressiveSlowSpatial.bezierCurve
        }
    }

    Behavior on y {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve:
                Appearance.animation.expressiveSlowSpatial.bezierCurve
        }
    }

    Behavior on width {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve:
                Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    Behavior on height {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve:
                Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    Loader {
        id: cardLoader

        anchors.fill: parent
        sourceComponent: root.sourceComponent
    }

    HoverHandler {
        cursorShape: dragHandler.active
            ? Qt.ClosedHandCursor
            : Qt.OpenHandCursor
    }

    DragHandler {
        id: dragHandler

        target: null
        acceptedButtons: Qt.LeftButton
        grabPermissions:
            PointerHandler.CanTakeOverFromAnything
            | PointerHandler.ApprovesTakeOverByAnything

        property bool started: false

        onActiveChanged: {
            if (active) {
                started = true;
                const point = root.mapToItem(
                    root.parent,
                    centroid.position.x,
                    centroid.position.y
                );
                root.dragStarted(
                    root.tileId,
                    root,
                    point.x,
                    point.y
                );
            } else if (started) {
                started = false;
                root.dragFinished(root.tileId);
            }
        }

        onCentroidChanged: {
            if (!active)
                return;
            const point = root.mapToItem(
                root.parent,
                centroid.position.x,
                centroid.position.y
            );
            root.dragMoved(root.tileId, point.x, point.y);
        }

        onCanceled: {
            started = false;
            root.dragCanceled(root.tileId);
        }
    }
}
