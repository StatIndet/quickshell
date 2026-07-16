import QtQuick
import qs.Common

Item {
    id: root

    clip: true

    property int currentIndex: 0
    readonly property int cardCount: 4
    readonly property real switchThreshold: width * 0.2

    property real cardOffset: 0
    property real wheelRemainder: 0
    property bool wheelUsesPixels: false
    property int pendingSteps: 0
    property int transitionDirection: 0

    function wrappedIndex(index) {
        return ((index % cardCount) + cardCount) % cardCount;
    }

    function relativeIndex(index) {
        let delta = wrappedIndex(index - currentIndex);
        if (delta > cardCount / 2)
            delta -= cardCount;
        return delta;
    }

    function cardX(index) {
        return relativeIndex(index) * width + cardOffset;
    }

    function queueStep(direction) {
        if (direction === 0)
            return;

        pendingSteps += direction;
        if (!settleAnimation.running && !carouselInput.dragActive)
            startQueuedStep();
    }

    function startQueuedStep() {
        if (pendingSteps === 0 || settleAnimation.running || carouselInput.dragActive)
            return;

        const direction = pendingSteps > 0 ? 1 : -1;
        pendingSteps -= direction;
        animateTo(-direction * width, direction);
    }

    function animateTo(targetOffset, direction) {
        transitionDirection = direction;

        if (Math.abs(cardOffset - targetOffset) < 0.5) {
            cardOffset = targetOffset;
            finishTransition();
            return;
        }

        settleAnimation.from = cardOffset;
        settleAnimation.to = targetOffset;
        settleAnimation.start();
    }

    function finishDrag() {
        if (Math.abs(cardOffset) >= switchThreshold) {
            const direction = cardOffset < 0 ? 1 : -1;
            animateTo(-direction * width, direction);
        } else {
            animateTo(0, 0);
        }
    }

    function finishTransition() {
        const direction = transitionDirection;
        if (direction !== 0)
            currentIndex = wrappedIndex(currentIndex + direction);

        cardOffset = 0;
        transitionDirection = 0;
        Qt.callLater(startQueuedStep);
    }

    component CarouselCard: Item {
        default property alias content: innerContainer.data

        Rectangle {
            id: cardBackground

            anchors.fill: parent
            anchors.margins: 10
            radius: 20
            color: Appearance.colors.colLayer0
        }

        Item {
            id: innerContainer

            anchors.fill: cardBackground
            anchors.margins: 14
        }
    }

    component PlaceholderText: Text {
        anchors.centerIn: parent
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Sizes.fontFamily
        font.pixelSize: 18
        font.bold: true
    }

    CarouselCard {
        width: root.width
        height: root.height
        x: root.cardX(0)

        ScheduleWidget {
            anchors.fill: parent
        }
    }

    CarouselCard {
        width: root.width
        height: root.height
        x: root.cardX(1)

        PlaceholderText {
            text: "音乐"
        }
    }

    CarouselCard {
        width: root.width
        height: root.height
        x: root.cardX(2)

        PlaceholderText {
            text: "天气"
        }
    }

    CarouselCard {
        width: root.width
        height: root.height
        x: root.cardX(3)

        PlaceholderText {
            text: "快捷设置"
        }
    }

    NumberAnimation {
        id: settleAnimation

        target: root
        property: "cardOffset"
        duration: Appearance.animation.standard.duration
        easing.type: Appearance.animation.standard.type
        easing.bezierCurve: Appearance.animation.standard.bezierCurve
        onStopped: root.finishTransition()
    }

    MouseArea {
        id: carouselInput

        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        preventStealing: true

        property bool dragActive: false
        property real pressX: 0

        onPressed: mouse => {
            dragActive = !settleAnimation.running;
            pressX = mouse.x;
            mouse.accepted = true;
        }

        onPositionChanged: mouse => {
            if (!dragActive)
                return;

            const delta = mouse.x - pressX;
            root.cardOffset = Math.max(-root.width, Math.min(delta, root.width));
        }

        onReleased: mouse => {
            if (dragActive)
                root.finishDrag();
            dragActive = false;
            mouse.accepted = true;
        }

        onCanceled: {
            if (dragActive)
                root.animateTo(0, 0);
            dragActive = false;
        }

        onWheel: event => {
            const angleDelta = event.angleDelta.y !== 0
                               ? event.angleDelta.y
                               : event.angleDelta.x;
            const usesPixels = angleDelta === 0;
            const delta = usesPixels
                          ? (event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.pixelDelta.x)
                          : angleDelta;
            const threshold = usesPixels ? 48 : 120;

            if (delta === 0)
                return;

            if (root.wheelUsesPixels !== usesPixels || root.wheelRemainder * delta < 0)
                root.wheelRemainder = 0;
            root.wheelUsesPixels = usesPixels;
            root.wheelRemainder += delta;

            while (Math.abs(root.wheelRemainder) >= threshold) {
                const wheelDirection = root.wheelRemainder > 0 ? 1 : -1;
                root.wheelRemainder -= wheelDirection * threshold;
                root.queueStep(wheelDirection > 0 ? -1 : 1);
            }

            event.accepted = true;
        }
    }
}
