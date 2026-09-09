import QtQuick
import qs.Common

MouseArea {
    id: root

    required property Flickable flickable
    property int orientation: Qt.Vertical
    property real mouseStep: 120
    property real pixelMultiplier: 3

    // Stay on the viewport and behind its contents so nested views and controls
    // get first refusal. Do not scroll this input area with the contentItem.
    parent: flickable
    anchors.fill: parent
    z: -1
    acceptedButtons: Qt.NoButton
    scrollGestureEnabled: true

    readonly property bool horizontal: orientation === Qt.Horizontal
    readonly property real minimum: horizontal ? flickable.originX - flickable.leftMargin : flickable.originY
                                                 - flickable.topMargin
    readonly property real maximum: Math.max(minimum, horizontal ? flickable.originX + flickable.contentWidth
                                                                   - flickable.width + flickable.rightMargin :
                                                                   flickable.originY
                                                                   + flickable.contentHeight
                                                                   - flickable.height
                                                                   + flickable.bottomMargin)
    property real destination: 0
    property real position: 0
    property bool writingPosition: false

    function currentPosition() {
        return horizontal ? flickable.contentX : flickable.contentY;
    }

    function clamp(value) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function stop() {
        scrollAnimation.stop();
    }

    function constrainAnimation() {
        if (!scrollAnimation.running)
            return;
        const boundedDestination = clamp(destination);
        stop();
        position = clamp(currentPosition());
        destination = boundedDestination;
        scrollAnimation.to = destination;
        scrollAnimation.start();
    }

    function handleWheel(event) {
        event.accepted = false;
        if (!enabled || !flickable.interactive || flickable.dragging)
            return;

        // Pixel deltas are already distances. Small angle deltas are fractional
        // mouse notches, not evidence that the device is a touchpad.
        const pixelInput = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0;
        const vector = pixelInput ? event.pixelDelta : event.angleDelta;
        const amount = horizontal ? (vector.x || vector.y) : vector.y;
        const delta = -amount * (pixelInput ? pixelMultiplier : mouseStep / 120);
        if (!isFinite(delta) || delta === 0)
            return;

        const current = currentPosition();
        // Reverse immediately rather than first finishing the previous direction.
        const base = scrollAnimation.running && delta * (destination - current) > 0 ? destination : current;
        const next = clamp(base + delta);
        if (next === clamp(base)) {
            // Consume remaining ticks while still approaching the edge. Once
            // there, leave outward input available to the enclosing view.
            event.accepted = scrollAnimation.running && current !== next;
            return;
        }

        stop();
        flickable.cancelFlick();
        destination = next;
        position = current;
        if (pixelInput) {
            // Preserve the platform's continuous gesture and momentum stream.
            position = next;
        } else {
            scrollAnimation.to = next;
            scrollAnimation.start();
        }
        event.accepted = true;
    }

    onWheel: event => handleWheel(event)
    onEnabledChanged: if (!enabled)
                          stop()
    onOrientationChanged: stop()
    onMinimumChanged: constrainAnimation()
    onMaximumChanged: constrainAnimation()
    onPositionChanged: {
        writingPosition = true;
        if (horizontal)
            flickable.contentX = position;
        else
            flickable.contentY = position;
        writingPosition = false;
    }

    NumberAnimation {
        id: scrollAnimation
        target: root
        property: "position"
        alwaysRunToEnd: false
        duration: Appearance.animation.scroll.duration
        easing.type: Appearance.animation.scroll.type
        easing.bezierCurve: Appearance.animation.scroll.bezierCurve
    }

    Connections {
        target: root.flickable
        function onContentXChanged() {
            if (root.horizontal && !root.writingPosition)
                root.stop();
        }
        function onContentYChanged() {
            if (!root.horizontal && !root.writingPosition)
                root.stop();
        }
        function onDraggingChanged() {
            if (root.flickable.dragging)
                root.stop();
        }
        function onInteractiveChanged() {
            if (!root.flickable.interactive)
                root.stop();
        }
    }
}
