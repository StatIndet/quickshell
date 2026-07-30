import QtQuick
import qs.Common

Item {
    id: root

    property real contentTop: 0
    property real viewportContentY: 0
    property real viewportHeight: 0
    property bool activationEnabled: true
    property int staggerIndex: 0
    property real entryTravel: 120

    readonly property bool hasRevealed: revealStarted
    readonly property bool contentAnimationActive:
        activationEnabled && animationStarted
            && nearViewport
    readonly property int entryDelay: Math.max(0, staggerIndex) * 200
    readonly property int entryDuration: Math.max(250, 500 - Math.max(0, staggerIndex) * 50)
    readonly property bool layoutReady: width > 0 && height > 0 && contentTop > 0
    readonly property real revealDepth: Math.min(height, Math.max(0, entryTravel))
    readonly property bool thresholdCrossed: activationEnabled
                                                 && layoutReady
                                                 && viewportHeight > 0
                                                 && contentTop + revealDepth <= viewportContentY + viewportHeight
    readonly property real viewportOverscan: 96
    readonly property bool nearViewport:
        viewportHeight <= 0
        || (contentTop + height >= viewportContentY - viewportOverscan
            && contentTop <= viewportContentY + viewportHeight
                + viewportOverscan)

    property bool animationStarted: false
    property bool revealStarted: false
    property real visualOpacity: 0
    property real entryOffset: entryTravel
    property real entryScale: 1.025

    default property alias content: visualLayer.data

    function maybeReveal() {
        if (thresholdCrossed && !revealStarted) {
            revealStarted = true
            entryAnimation.restart()
        }
    }

    function settleReveal() {
        entryAnimation.stop()
        if (!revealStarted)
            return

        animationStarted = true
        visualOpacity = 1
        entryOffset = 0
        entryScale = 1
    }

    onThresholdCrossedChanged: maybeReveal()
    onActivationEnabledChanged: {
        if (activationEnabled)
            maybeReveal()
        else
            settleReveal()
    }
    Component.onCompleted: Qt.callLater(maybeReveal)

    Item {
        id: visualLayer
        anchors.fill: parent
        opacity: root.visualOpacity
        visible: root.nearViewport || entryAnimation.running

        transform: [
            Translate {
                y: root.entryOffset
            },
            Scale {
                origin.x: visualLayer.width / 2
                origin.y: visualLayer.height / 2
                xScale: root.entryScale
                yScale: root.entryScale
            }
        ]
    }

    SequentialAnimation {
        id: entryAnimation

        PauseAnimation {
            duration: root.entryDelay
        }

        ScriptAction {
            script: root.animationStarted = true
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "visualOpacity"
                from: 0
                to: 1
                duration: root.entryDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Animations.curves.expressiveDefaultEffects
            }

            NumberAnimation {
                target: root
                property: "entryOffset"
                from: root.entryTravel
                to: 0
                duration: root.entryDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Animations.curves.expressiveDefaultSpatial
            }

            NumberAnimation {
                target: root
                property: "entryScale"
                from: 1.025
                to: 1
                duration: root.entryDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Animations.curves.standardDecel
            }
        }

        ScriptAction {
            script: {
                root.visualOpacity = 1
                root.entryOffset = 0
                root.entryScale = 1
            }
        }
    }
}
