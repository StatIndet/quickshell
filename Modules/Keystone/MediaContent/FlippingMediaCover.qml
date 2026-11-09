import QtQuick

Item {
    id: root

    required property string artUrl
    required property string trackKey
    required property bool playing
    required property bool caelestia
    required property color accentColor
    property bool active: visible

    property bool initialized: false
    property string displayedTrack: ""
    property string frontArt: ""
    property string backArt: ""
    property bool awaitingArt: false
    property bool awaitingFlip: false
    property int nextDirection: 1
    property int flipDirection: 1
    property real angle: 0

    function expectDirection(direction) {
        nextDirection = direction;
        directionExpiry.restart();
    }

    function settle() {
        if (flip.running) {
            flip.stop();
            frontArt = backArt;
        }
        angle = 0;
    }

    function synchronize() {
        if (!initialized)
            return;
        if (!active || !displayedTrack || !trackKey) {
            settle();
            displayedTrack = trackKey;
            frontArt = artUrl;
            awaitingArt = false;
            awaitingFlip = false;
            nextDirection = 1;
            directionExpiry.stop();
            return;
        }
        if (displayedTrack !== trackKey) {
            settle();
            displayedTrack = trackKey;
            flipDirection = nextDirection;
            nextDirection = 1;
            directionExpiry.stop();
            awaitingFlip = true;
        }
        awaitingArt = true;
        applyArtwork();
    }

    function applyArtwork() {
        // A late image callback must not start a flip for an already superseded track.
        if (!awaitingArt || displayedTrack !== trackKey)
            return;
        if (artUrl && preload.status !== Image.Ready && preload.status !== Image.Error)
            return;
        awaitingArt = false;
        if (awaitingFlip) {
            awaitingFlip = false;
            backArt = artUrl;
            flip.restart();
        } else if (flip.running) {
            backArt = artUrl;
        } else {
            frontArt = artUrl;
        }
    }

    onTrackKeyChanged: updateTimer.restart()
    onArtUrlChanged: updateTimer.restart()
    onActiveChanged: updateTimer.restart()
    Component.onCompleted: {
        initialized = true;
        synchronize();
    }

    Timer {
        id: updateTimer
        interval: 40
        onTriggered: root.synchronize()
    }
    Timer {
        id: directionExpiry
        interval: 1500
        onTriggered: root.nextDirection = 1
    }
    Image {
        id: preload
        source: root.artUrl
        sourceSize: Qt.size(240, 240)
        asynchronous: true
        visible: false
        onStatusChanged: root.applyArtwork()
    }

    NumberAnimation {
        id: flip
        target: root
        property: "angle"
        from: 0
        to: root.flipDirection * 180
        duration: 620
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 0.65, 0.3, 1.12, 1, 1]
        onFinished: {
            root.frontArt = root.backArt;
            root.angle = 0;
        }
    }

    Flipable {
        id: card
        anchors.fill: parent
        transform: Rotation {
            origin.x: card.width / 2
            origin.y: card.height / 2
            axis.x: 0
            axis.y: 1
            axis.z: 0
            angle: root.angle
        }
        front: MediaCover {
            width: card.width
            height: card.height
            artUrl: root.frontArt
            playing: root.playing
            caelestia: root.caelestia
            accentColor: root.accentColor
            active: root.active && card.side === Flipable.Front
        }
        back: MediaCover {
            width: card.width
            height: card.height
            artUrl: root.backArt
            playing: root.playing
            caelestia: root.caelestia
            accentColor: root.accentColor
            active: root.active && card.side === Flipable.Back
        }
    }
}
