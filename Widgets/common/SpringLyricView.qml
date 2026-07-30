import QtQuick

Item {
    id: root

    property var lyrics: null
    property int activeLine: 0
    property real playbackSeconds: 0

    property real alignPosition: 0.35
    property real lineGap: 22
    property real defaultLineHeight: 34
    property int renderBefore: 5
    property int renderAfter: 6
    property int seekJumpThreshold: 4

    property color activeColor: "white"
    property color inactiveColor: "#99ffffff"
    property int fontSize: 18
    property string fontFamily: "LXGW WenKai GB Screen"
    property bool fontBold: true
    property int horizontalAlignment: Text.AlignLeft
    property int wrapMode: Text.WordWrap
    property real activeOpacity: 1.0
    property real nearbyOpacity: 0.58
    property real distantOpacity: 0.24
    property real currentScale: 1.0
    property real inactiveScale: 0.97

    property real tiltAngle: 0

    property real positionMass: 0.9
    property real baseStiffness: 90
    property real baseDamping: 15
    property real minDynamicStiffness: 170
    property real maxDynamicStiffness: 220
    property real dampingMultiplier: 2.2
    property real minIntervalMs: 100
    property real maxIntervalMs: 800
    property real lineDelay: 0.05
    property real delayDecay: 1.05
    property real settlePosition: 0.04
    property real settleVelocity: 0.04

    readonly property int lyricCount: !root.lyrics ? 0 : (root.lyrics.count !== undefined ? root.lyrics.count : root.lyrics.length)

    property real _currentStiffness: baseStiffness
    property real _currentDamping: baseDamping
    property bool _animating: false

    clip: true

    onWidthChanged: scheduleLayout(true)
    onHeightChanged: scheduleLayout(true)

    function clampIndex(index) {
        if (root.lyricCount <= 0)
            return 0;
        return Math.max(0, Math.min(root.lyricCount - 1, Math.floor(index)));
    }

    function lyricAt(index) {
        if (!root.lyrics || index < 0 || index >= root.lyricCount)
            return null;
        if (root.lyrics.get)
            return root.lyrics.get(index);
        return root.lyrics[index];
    }

    function lyricTime(index) {
        let line = root.lyricAt(index);
        if (!line || line.time === undefined)
            return 0;
        let value = Number(line.time);
        return isNaN(value) ? 0 : value;
    }

    function lineHeight(index) {
        let item = lyricRepeater.itemAt(index);
        if (!item)
            return root.defaultLineHeight;
        return Math.max(root.defaultLineHeight, item.lineHeight);
    }

    function targetCenterForLine(index, activeIndex) {
        let center = root.height * root.alignPosition;

        if (index > activeIndex) {
            center += root.lineHeight(activeIndex) / 2 + root.lineGap;
            for (let i = activeIndex + 1; i < index; i++)
                center += root.lineHeight(i) + root.lineGap;
            center += root.lineHeight(index) / 2;
        } else if (index < activeIndex) {
            center -= root.lineHeight(activeIndex) / 2 + root.lineGap;
            for (let i = activeIndex - 1; i > index; i--)
                center -= root.lineHeight(i) + root.lineGap;
            center -= root.lineHeight(index) / 2;
        }

        return center;
    }

    function targetYForLine(index, activeIndex) {
        return root.targetCenterForLine(index, activeIndex) - root.lineHeight(index) / 2;
    }

    function opacityForDistance(distance) {
        if (distance === 0)
            return root.activeOpacity;
        if (distance <= 2)
            return root.nearbyOpacity;
        return root.distantOpacity;
    }

    function updateDynamicMotion(index) {
        let currentTime = root.lyricTime(index);
        let prevTime = root.lyricTime(index - 1);
        let interval = (index > 0 && currentTime > prevTime) ? (currentTime - prevTime) * 1000 : 0;

        if (interval <= 0) {
            root._currentStiffness = root.baseStiffness;
            root._currentDamping = root.baseDamping;
            return;
        }

        let clamped = Math.max(root.minIntervalMs, Math.min(root.maxIntervalMs, interval));
        let ratio = 1 - (clamped - root.minIntervalMs) / (root.maxIntervalMs - root.minIntervalMs);
        ratio = Math.pow(ratio, 0.2);
        root._currentStiffness = root.minDynamicStiffness + ratio * (root.maxDynamicStiffness - root.minDynamicStiffness);
        root._currentDamping = Math.sqrt(root._currentStiffness) * root.dampingMultiplier;
    }

    function scheduleLayout(immediate) {
        Qt.callLater(function() {
            root.layoutLines(immediate);
        });
    }

    function resetToLine(index) {
        let next = root.clampIndex(index);
        root.activeLine = next;
        root.updateDynamicMotion(next);
        root.layoutLines(true);
    }

    function syncToLine(index, seconds, immediate) {
        if (root.lyricCount <= 0)
            return;

        let next = root.clampIndex(index);
        let jumped = Math.abs(next - root.activeLine) > root.seekJumpThreshold;
        let force = immediate || jumped;
        root.playbackSeconds = seconds;

        if (next === root.activeLine && !force)
            return;

        root.activeLine = next;
        root.updateDynamicMotion(next);
        root.layoutLines(force);
    }

    function layoutLines(immediate) {
        let count = lyricRepeater.count;
        if (count <= 0) {
            root._animating = false;
            return;
        }

        let activeIndex = root.clampIndex(root.activeLine);
        let firstVisible = Math.max(0, activeIndex - root.renderBefore);
        let lastVisible = Math.min(count - 1, activeIndex + root.renderAfter);

        for (let i = 0; i < count; i++) {
            if (i >= firstVisible && i <= lastVisible)
                continue;

            let hiddenItem = lyricRepeater.itemAt(i);
            if (!hiddenItem)
                continue;

            hiddenItem.assignTarget(root.targetYForLine(i, activeIndex), root.inactiveScale, 0, 0, true);
        }

        let delay = 0;
        let baseDelay = immediate ? 0 : root.lineDelay;

        for (let j = firstVisible; j <= lastVisible; j++) {
            let item = lyricRepeater.itemAt(j);
            if (!item)
                continue;

            let distance = Math.abs(j - activeIndex);
            let targetY = root.targetYForLine(j, activeIndex);
            let targetScale = j === activeIndex ? root.currentScale : root.inactiveScale;
            let targetOpacity = root.opacityForDistance(distance);
            let itemDelay = immediate ? 0 : delay;

            item.assignTarget(targetY, targetScale, targetOpacity, itemDelay, immediate);

            if (targetY >= 0 && !immediate) {
                delay += baseDelay;
                if (j >= activeIndex)
                    baseDelay /= root.delayDecay;
            }
        }

        root._animating = !immediate;
    }

    function stepValue(position, velocity, target, stiffness, damping, mass, dt) {
        let displacement = position - target;
        let acceleration = (-stiffness * displacement - damping * velocity) / mass;
        velocity += acceleration * dt;
        position += velocity * dt;
        return [position, velocity];
    }

    function advance(deltaSeconds) {
        let count = lyricRepeater.count;
        let running = false;

        for (let i = 0; i < count; i++) {
            let item = lyricRepeater.itemAt(i);
            if (item && item.advance(deltaSeconds))
                running = true;
        }

        root._animating = running;
    }

    Timer {
        interval: 16
        repeat: true
        running: root.visible && root._animating
        onTriggered: root.advance(interval / 1000)
    }

    Item {
        id: content
        anchors.fill: parent

        transform: Rotation {
            origin.x: 0
            origin.y: content.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.tiltAngle
        }

        Repeater {
            id: lyricRepeater
            model: root.lyrics
            onCountChanged: root.scheduleLayout(true)

            delegate: Item {
                id: lyricItem

                required property int index
                required property string text

                property real lineHeight: Math.max(root.defaultLineHeight, lyricText.implicitHeight)
                property real targetY: root.targetYForLine(index, root.activeLine)
                property real pendingY: targetY
                property real visualY: targetY
                property real velocityY: 0
                property real targetScale: root.inactiveScale
                property real pendingScale: targetScale
                property real visualScale: targetScale
                property real velocityScale: 0
                property real shownOpacity: 0
                property real targetOpacity: 0
                property real pendingDelay: 0
                property bool hasPendingTarget: false

                readonly property int distance: Math.abs(index - root.activeLine)
                readonly property bool current: index === root.activeLine

                width: root.width
                height: lineHeight
                x: 0
                y: visualY
                z: root.renderAfter + root.renderBefore - distance
                scale: visualScale
                opacity: shownOpacity
                transformOrigin: Item.Left
                visible: distance <= Math.max(root.renderBefore, root.renderAfter) || shownOpacity > 0.01

                function assignTarget(nextY, nextScale, nextOpacity, delay, immediate) {
                    pendingY = nextY;
                    pendingScale = nextScale;
                    targetOpacity = nextOpacity;
                    pendingDelay = Math.max(0, delay);
                    hasPendingTarget = true;

                    if (immediate) {
                        targetY = pendingY;
                        targetScale = pendingScale;
                        visualY = targetY;
                        visualScale = targetScale;
                        velocityY = 0;
                        velocityScale = 0;
                        shownOpacity = targetOpacity;
                        pendingDelay = 0;
                        hasPendingTarget = false;
                    }
                }

                function applyPendingTarget() {
                    if (!hasPendingTarget)
                        return;
                    targetY = pendingY;
                    targetScale = pendingScale;
                    hasPendingTarget = false;
                }

                function advance(dt) {
                    let activeMotion = false;

                    if (pendingDelay > 0) {
                        pendingDelay -= dt;
                        activeMotion = true;
                        if (pendingDelay > 0)
                            return activeMotion;
                    }

                    applyPendingTarget();

                    let yResult = root.stepValue(visualY, velocityY, targetY, root._currentStiffness, root._currentDamping, root.positionMass, dt);
                    visualY = yResult[0];
                    velocityY = yResult[1];

                    let scaleResult = root.stepValue(visualScale, velocityScale, targetScale, 85, 17, 1, dt);
                    visualScale = scaleResult[0];
                    velocityScale = scaleResult[1];

                    shownOpacity += (targetOpacity - shownOpacity) * Math.min(1, dt * 12);

                    let ySettled = Math.abs(visualY - targetY) < root.settlePosition && Math.abs(velocityY) < root.settleVelocity;
                    let scaleSettled = Math.abs(visualScale - targetScale) < 0.001 && Math.abs(velocityScale) < 0.001;
                    let opacitySettled = Math.abs(shownOpacity - targetOpacity) < 0.01;

                    if (ySettled) {
                        visualY = targetY;
                        velocityY = 0;
                    }
                    if (scaleSettled) {
                        visualScale = targetScale;
                        velocityScale = 0;
                    }
                    if (opacitySettled)
                        shownOpacity = targetOpacity;

                    return !ySettled || !scaleSettled || !opacitySettled || hasPendingTarget;
                }

                Text {
                    id: lyricText
                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    text: lyricItem.text
                    color: lyricItem.current ? root.activeColor : root.inactiveColor
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.bold: root.fontBold
                    horizontalAlignment: root.horizontalAlignment
                    wrapMode: root.wrapMode
                    elide: Text.ElideNone
                }
            }
        }
    }
}
