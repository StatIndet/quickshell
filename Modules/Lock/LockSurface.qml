import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import qs.Common
import qs.Services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    property var context: null
    property var snapshotProvider: null
    property var snapshotResult: null
    property bool componentReady: false
    property bool snapshotResolved: false
    property bool startupStarted: false
    property bool isExiting: false
    property real morphProgress: 0
    property real containerScale: 0
    property real containerRotation: 180
    property real contentOpacity: 0
    property real contentScale: 0
    property real backgroundBlur: 0
    readonly property real targetHeight: Math.max(1, height * Sizes.lockHeightMult)
    readonly property real targetWidth: targetHeight * Sizes.lockRatio
    readonly property real compactSize: Math.min(Metrics.lockIconPanelSize, targetHeight)
    readonly property real compactRadius: compactSize / 4
    readonly property real panelRadius: Metrics.lockCardRadius * 1.5

    function resolveSnapshot() {
        if (!componentReady || snapshotResolved || !root.screen || !root.screen.name)
            return ;

        snapshotResult = snapshotProvider ? snapshotProvider.snapshot(root.screen) : null;
        snapshotResolved = true;
        maybeStartStartupAnimation();
    }

    function maybeStartStartupAnimation() {
        if (startupStarted || !snapshotResolved)
            return ;

        if (snapshotResult && snapshotImage.status !== Image.Ready && snapshotImage.status !== Image.Error)
            return ;

        if (snapshotResult && snapshotImage.status === Image.Error)
            console.warn("Unable to display pre-lock snapshot for output " + root.screen.name);

        startupStarted = true;
        startupAnim.start();
    }

    function focusAuth() {
        if (lockContent.opacity > 0)
            lockContent.forceAuthFocus();

    }

    function startExitAnimation() {
        if (isExiting)
            return ;

        startupAnim.stop();
        isExiting = true;
        exitAnim.start();
    }

    color: "transparent"
    onScreenChanged: resolveSnapshot()
    Component.onCompleted: {
        componentReady = true;
        resolveSnapshot();
    }

    Rectangle {
        id: immediateFallback

        anchors.fill: parent
        color: Appearance.colors.colLayer0Base
    }

    Image {
        id: snapshotImage

        anchors.fill: parent
        source: root.snapshotResult ? root.snapshotResult.url : ""
        fillMode: Image.Stretch
        asynchronous: false
        cache: false
        visible: source !== ""
        layer.enabled: true
        onStatusChanged: root.maybeStartStartupAnimation()

        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: root.backgroundBlur
            blurMax: 64
            blurMultiplier: 1
        }

    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.focusAuth()
    }

    Connections {
        function onUnlockFailed() {
            root.isExiting = false;
            root.focusAuth();
        }

        target: root.context
        ignoreUnknownSignals: true
    }

    Connections {
        function onUnlock() {
            root.startExitAnimation();
        }

        target: root.lock
    }

    ParallelAnimation {
        id: startupAnim

        running: false
        onFinished: root.focusAuth()

        NumberAnimation {
            target: root
            property: "backgroundBlur"
            to: 1
            duration: Appearance.animation.standardLarge.duration
            easing.type: Appearance.animation.standardLarge.type
            easing.bezierCurve: Appearance.animation.standardLarge.bezierCurve
        }

        SequentialAnimation {
            ParallelAnimation {
                NumberAnimation {
                    target: root
                    property: "containerScale"
                    to: 1
                    duration: Appearance.animation.expressiveFastSpatial.duration
                    easing.type: Appearance.animation.expressiveFastSpatial.type
                    easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                }

                NumberAnimation {
                    target: root
                    property: "containerRotation"
                    to: 360
                    duration: Appearance.animation.expressiveFastSpatial.duration
                    easing.type: Appearance.animation.standardAccel.type
                    easing.bezierCurve: Appearance.animation.standardAccel.bezierCurve
                }

            }

            ParallelAnimation {
                NumberAnimation {
                    target: root
                    property: "morphProgress"
                    to: 1
                    duration: Appearance.animation.expressiveDefaultSpatial.duration
                    easing.type: Appearance.animation.expressiveDefaultSpatial.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                }

                NumberAnimation {
                    target: lockIcon
                    property: "rotation"
                    to: 360
                    duration: Appearance.animation.standard.duration
                    easing.type: Appearance.animation.standardDecel.type
                    easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
                }

                NumberAnimation {
                    target: lockIcon
                    property: "opacity"
                    to: 0
                    duration: Appearance.animation.standard.duration
                    easing.type: Appearance.animation.standard.type
                    easing.bezierCurve: Appearance.animation.standard.bezierCurve
                }

                NumberAnimation {
                    target: root
                    property: "contentOpacity"
                    to: 1
                    duration: Appearance.animation.standard.duration
                    easing.type: Appearance.animation.standard.type
                    easing.bezierCurve: Appearance.animation.standard.bezierCurve
                }

                NumberAnimation {
                    target: root
                    property: "contentScale"
                    to: 1
                    duration: Appearance.animation.expressiveDefaultSpatial.duration
                    easing.type: Appearance.animation.expressiveDefaultSpatial.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                }

            }

        }

    }

    Rectangle {
        id: morphContainer

        anchors.centerIn: parent
        clip: true
        width: root.compactSize + (root.targetWidth - root.compactSize) * root.morphProgress
        height: root.compactSize + (root.targetHeight - root.compactSize) * root.morphProgress
        radius: root.compactRadius + (root.panelRadius - root.compactRadius) * root.morphProgress
        rotation: root.containerRotation
        scale: root.containerScale
        color: BlurService.backgroundColor(Appearance.colors.colLayer0)
        layer.enabled: true

        Text {
            id: lockIcon

            anchors.centerIn: parent
            text: "lock"
            rotation: 180
            color: Appearance.colors.colOnSurface
            font.family: Fonts.materialSymbolsRounded
            font.pixelSize: root.compactSize * 0.56
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        LockContent {
            id: lockContent

            anchors.centerIn: parent
            width: root.targetWidth - Metrics.lockOuterPadding * 2
            height: root.targetHeight - Metrics.lockOuterPadding * 2
            context: root.context
            screenHeight: root.height
            opacity: root.contentOpacity
            scale: root.contentScale
            visible: opacity > 0 || root.morphProgress > 0.96
        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.colors.colShadow
            shadowBlur: 0.8
            shadowVerticalOffset: 8
        }

    }

    SequentialAnimation {
        id: exitAnim

        onFinished: {
            if (root.context)
                root.context.finishUnlock();
            else
                root.lock.locked = false;
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "morphProgress"
                to: 0
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
            }

            NumberAnimation {
                target: root
                property: "contentScale"
                to: 0
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
            }

            NumberAnimation {
                target: root
                property: "contentOpacity"
                to: 0
                duration: Appearance.animation.standardSmall.duration
                easing.type: Appearance.animation.standardSmall.type
                easing.bezierCurve: Appearance.animation.standardSmall.bezierCurve
            }

            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: Appearance.animation.standardLarge.duration
                easing.type: Appearance.animation.standardLarge.type
                easing.bezierCurve: Appearance.animation.standardLarge.bezierCurve
            }

            NumberAnimation {
                target: lockIcon
                property: "rotation"
                to: 360
                duration: Appearance.animation.standard.duration
                easing.type: Appearance.animation.standardDecel.type
                easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
            }

            NumberAnimation {
                target: root
                property: "backgroundBlur"
                to: 0
                duration: Appearance.animation.standardLarge.duration
                easing.type: Appearance.animation.standardLarge.type
                easing.bezierCurve: Appearance.animation.standardLarge.bezierCurve
            }

        }

        SequentialAnimation {
            PauseAnimation {
                duration: Animations.durations.small
            }

            NumberAnimation {
                target: morphContainer
                property: "opacity"
                to: 0
                duration: Appearance.animation.standard.duration
                easing.type: Appearance.animation.standard.type
                easing.bezierCurve: Appearance.animation.standard.bezierCurve
            }

        }

    }

}
