import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property int currentIndex: 0
    property var screen: null
    readonly property int cardCount: 3
    readonly property real switchThreshold: width * 0.2
    readonly property real glassAlpha: BlurService.enabled ? Math.min(PersonalizationConfig.shellBackgroundOpacity, 0.68) : 1
    readonly property var blurBackgroundItems: [
        weatherCard.glassBackgroundItem,
        quickSettingsPage.glassBackgroundItem,
        pomodoroPage.glassBackgroundItem
    ]
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
            return ;

        pendingSteps += direction;
        if (!settleAnimation.running && !carouselInput.dragActive)
            startQueuedStep();

    }

    function startQueuedStep() {
        if (pendingSteps === 0 || settleAnimation.running || carouselInput.dragActive)
            return ;

        const direction = pendingSteps > 0 ? 1 : -1;
        pendingSteps -= direction;
        animateTo(-direction * width, direction);
    }

    function animateTo(targetOffset, direction) {
        transitionDirection = direction;
        if (Math.abs(cardOffset - targetOffset) < 0.5) {
            cardOffset = targetOffset;
            finishTransition();
            return ;
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

    clip: true

    CarouselCard {
        id: weatherCard

        width: root.width
        height: root.height
        x: root.cardX(0)
        contentMargin: 0

        DashboardWeatherCard {
            anchors.fill: parent
            active: root.visible && root.currentIndex === 0
        }

    }

    CarouselCard {
        id: quickSettingsPage

        width: root.width
        height: root.height
        x: root.cardX(1)
        contentMargin: 0

        DashboardQuickSettingsCard {
            id: quickSettingsCard

            anchors.fill: parent
            screen: root.screen
        }

    }

    CarouselCard {
        id: pomodoroPage

        width: root.width
        height: root.height
        x: root.cardX(2)
        contentMargin: 0

        DashboardPomodoroCard {
            anchors.fill: parent
            active: root.visible && root.currentIndex === 2
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

        property bool dragActive: false
        property real pressX: 0

        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        preventStealing: true
        onPressed: (mouse) => {
            dragActive = !settleAnimation.running;
            pressX = mouse.x;
            mouse.accepted = true;
        }
        onPositionChanged: (mouse) => {
            if (!dragActive)
                return ;

            const delta = mouse.x - pressX;
            root.cardOffset = Math.max(-root.width, Math.min(delta, root.width));
        }
        onReleased: (mouse) => {
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
        onWheel: (event) => {
            if (root.currentIndex === 1) {
                const point = quickSettingsCard.mapFromItem(root, event.x, event.y);
                if (quickSettingsCard.capturesWheelAt(point.x, point.y)) {
                    event.accepted = false;
                    return ;
                }
            }
            const angleDelta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            const usesPixels = angleDelta === 0;
            const delta = usesPixels ? (event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.pixelDelta.x) : angleDelta;
            const threshold = usesPixels ? 48 : 120;
            if (delta === 0)
                return ;

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

    component CarouselCard: Item {
        id: cardRoot

        default property alias content: innerContainer.data
        property real contentMargin: 14
        readonly property Item glassBackgroundItem: glassBackground

        Rectangle {
            id: glassBackground

            anchors.fill: parent
            anchors.margins: 10
            radius: 20
            color: Appearance.applyAlpha(Appearance.colors.colLayer0, root.glassAlpha)
        }

        Item {
            id: innerContainer

            anchors.fill: parent
            anchors.margins: 10 + cardRoot.contentMargin
        }

    }

}
