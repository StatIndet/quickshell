import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services

Flickable {
    id: root

    clip: true
    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds

    property bool smoothWheelEnabled: PersonalizationConfig.scrollSmoothEnabled
    property bool showVerticalScrollBar: true
    property real scrollTargetY: 0
    property real mouseScrollFactor: PersonalizationConfig.scrollMouseFactor
    property real touchpadScrollFactor: PersonalizationConfig.scrollTouchpadFactor
    property real mouseScrollDeltaThreshold: PersonalizationConfig.scrollMouseDeltaThreshold

    function maxContentY() {
        return Math.max(0, root.contentHeight - root.height);
    }

    function clampContentY(value) {
        return Math.max(0, Math.min(value, root.maxContentY()));
    }

    function wheelDeltaY(wheelEvent) {
        if (wheelEvent.pixelDelta.y !== 0)
            return -wheelEvent.pixelDelta.y;

        if (wheelEvent.angleDelta.y === 0)
            return 0;

        const normalizedDelta = wheelEvent.angleDelta.y / Math.max(1, root.mouseScrollDeltaThreshold);
        const factor = Math.abs(wheelEvent.angleDelta.y) >= root.mouseScrollDeltaThreshold
                       ? root.mouseScrollFactor
                       : root.touchpadScrollFactor;
        return -normalizedDelta * factor;
    }

    function handleWheel(wheelEvent) {
        const delta = root.wheelDeltaY(wheelEvent);
        if (delta === 0)
            return;

        const base = scrollAnimation.running ? root.scrollTargetY : root.contentY;
        root.scrollTargetY = root.clampContentY(base + delta);
        root.contentY = root.scrollTargetY;
        wheelEvent.accepted = true;
    }

    ScrollBar.vertical: StyledScrollBar {
        policy: root.showVerticalScrollBar ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.smoothWheelEnabled
        acceptedButtons: Qt.NoButton
        onWheel: wheelEvent => root.handleWheel(wheelEvent)
    }

    Behavior on contentY {
        enabled: root.smoothWheelEnabled
        NumberAnimation {
            id: scrollAnimation
            alwaysRunToEnd: true
            duration: Appearance.animation.scroll.duration
            easing.type: Appearance.animation.scroll.type
            easing.bezierCurve: Appearance.animation.scroll.bezierCurve
        }
    }

    onContentYChanged: {
        if (!scrollAnimation.running)
            root.scrollTargetY = root.contentY;
    }

    onContentHeightChanged: {
        root.scrollTargetY = root.clampContentY(root.scrollTargetY);
        if (root.contentY > root.maxContentY())
            root.contentY = root.maxContentY();
    }
}
