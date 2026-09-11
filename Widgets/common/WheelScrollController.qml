import QtQuick
import qs.Common

MouseArea {
    id: root

    required property Flickable flickable
    property int orientation: Qt.Vertical
    property real mouseStep: 120
    property real pixelMultiplier: 3

    // Keep wheel input behind content, but inside the contentItem subtree so
    // it is visited before Flickable's own wheel handler. A negative-z sibling
    // of contentItem sits behind Flickable and never receives accepted events.
    // Offset with the scroll position to keep this area on the viewport.
    parent: flickable.contentItem
    x: flickable.contentX
    y: flickable.contentY
    width: flickable.width
    height: flickable.height
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

    // Observe Flickable state through bindings. In Qt 6.11.2, asynchronous page
    // creation crashed in connectSignalsToMethods() with a null JavaScript method.
    // Property handlers avoid that Connections initialization path.
    readonly property real observedContentX: flickable ? flickable.contentX : 0
    readonly property real observedContentY: flickable ? flickable.contentY : 0
    readonly property bool observedDragging: flickable ? flickable.dragging : false
    readonly property bool observedInteractive: flickable ? flickable.interactive : false

    onObservedContentXChanged: {
        if (horizontal && !writingPosition)
            stop();
    }
    onObservedContentYChanged: {
        if (!horizontal && !writingPosition)
            stop();
    }
    onObservedDraggingChanged: {
        if (observedDragging)
            stop();
    }
    onObservedInteractiveChanged: {
        if (!observedInteractive)
            stop();
    }
}
