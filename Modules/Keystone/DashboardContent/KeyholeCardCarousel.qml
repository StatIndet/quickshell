import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Services

Item {
    id: root

    property int currentIndex: 0
    property var screen: null
    readonly property var cardIds: PersonalizationConfig.keystoneKeyholeCards
    readonly property int cardCount: cardIds.length
    readonly property string currentCardId: cardCount > 0 ? String(cardIds[currentIndex] || "") : ""
    readonly property real switchThreshold: width * 0.2
    readonly property real glassAlpha: BlurService.enabled ? Math.min(PersonalizationConfig.shellBackgroundOpacity, 0.68) : 1
    readonly property var blurBackgroundItems: {
        const items = [];
        for (let index = 0; index < cardRepeater.count; index += 1) {
            const card = cardRepeater.itemAt(index);
            if (card)
                items.push(card.glassBackgroundItem);

        }
        return items;
    }
    property real cardOffset: 0
    property real wheelRemainder: 0
    property bool wheelUsesPixels: false
    property int pendingSteps: 0
    property int transitionDirection: 0

    function wrappedIndex(index) {
        if (cardCount === 0)
            return 0;

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
        if (direction === 0 || cardCount < 2)
            return ;

        pendingSteps += direction;
        if (!settleAnimation.running && !carouselInput.dragActive)
            startQueuedStep();

    }

    function startQueuedStep() {
        if (cardCount < 2 || pendingSteps === 0 || settleAnimation.running || carouselInput.dragActive)
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
        if (cardCount < 2) {
            cardOffset = 0;
            return ;
        }
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

    function resetCarousel() {
        settleAnimation.stop();
        currentIndex = 0;
        cardOffset = 0;
        wheelRemainder = 0;
        pendingSteps = 0;
        transitionDirection = 0;
    }

    function quickSettingsCard() {
        for (let index = 0; index < cardRepeater.count; index += 1) {
            const card = cardRepeater.itemAt(index);
            if (card && card.cardId === "quickSettings")
                return card.quickSettingsItem;

        }
        return null;
    }

    clip: true
    layer.enabled: true
    onCardIdsChanged: resetCarousel()

    Repeater {
        id: cardRepeater

        model: root.cardIds

        delegate: CarouselCard {
            id: cardDelegate

            required property int index
            required property string modelData
            readonly property string cardId: modelData
            readonly property bool cardActive: root.visible && root.currentIndex === index
            readonly property var quickSettingsItem: quickSettingsLoader.item

            width: root.width
            height: root.height
            x: root.cardX(index)
            contentMargin: 0

            Loader {
                anchors.fill: parent
                active: cardDelegate.cardId === "weather"

                sourceComponent: DashboardWeatherCard {
                    active: cardDelegate.cardActive
                }

            }

            Loader {
                id: quickSettingsLoader

                anchors.fill: parent
                active: cardDelegate.cardId === "quickSettings"

                sourceComponent: DashboardQuickSettingsCard {
                    screen: root.screen
                }

            }

            Loader {
                anchors.fill: parent
                active: cardDelegate.cardId === "pomodoro"

                sourceComponent: DashboardPomodoroCard {
                    active: cardDelegate.cardActive
                }

            }

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
        enabled: root.cardCount > 1
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
            const quickSettings = root.currentCardId === "quickSettings" ? root.quickSettingsCard() : null;
            if (quickSettings) {
                const point = quickSettings.mapFromItem(root, event.x, event.y);
                if (quickSettings.capturesWheelAt(point.x, point.y)) {
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

    layer.effect: OpacityMask {

        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: 24
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
