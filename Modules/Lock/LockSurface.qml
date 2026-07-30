import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import qs.Common
import qs.Services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    property var context: null
    property bool isExiting: false
    property real morphProgress: 0
    property real containerScale: 0
    property real containerRotation: 180
    property real contentOpacity: 0
    property real contentScale: 0
    property real backgroundBlur: 0
    property bool startupStarted: false
    property bool startupFallbackElapsed: false

    // Fit the lock panel against both screen axes.  The old 70%-of-height
    // calculation clipped the three-column layout on fractional-scale screens.
    readonly property real availableWidth: Math.max(1, width - Sizes.lockOuterPadding * 2)
    readonly property real availableHeight: Math.max(1, height - Sizes.lockOuterPadding * 2)
    readonly property real targetWidth: Math.min(availableWidth, availableHeight * Sizes.lockRatio)
    readonly property real targetHeight: Math.min(availableHeight, targetWidth / Sizes.lockRatio)
    readonly property real compactSize: Math.min(Sizes.lockIconPanelSize, targetHeight)
    readonly property real compactRadius: compactSize / 4
    readonly property real panelRadius: Sizes.lockCardRadiusLarge * 1.5
    readonly property string snapshotSource: LockSnapshot.snapshotUrl(root.screen)
    readonly property bool snapshotReady: snapshotSource !== "" && desktopSnapshotFallback.status === Image.Ready
    readonly property bool canStartStartupAnimation: snapshotReady || startupFallbackElapsed

    color: "transparent"

    onCanStartStartupAnimationChanged: maybeStartStartupAnimation()

    Component.onCompleted: maybeStartStartupAnimation()

    function focusAuth() {
        if (lockContent.opacity > 0)
            lockContent.forceAuthFocus();
    }

    function maybeStartStartupAnimation() {
        if (startupStarted || !canStartStartupAnimation)
            return;

        startupStarted = true;
        startupAnim.start();
    }

    function startExitAnimation() {
        if (isExiting)
            return;

        startupAnim.stop();
        isExiting = true;
        exitAnim.start();
    }

    Rectangle {
        id: immediateFallback
        anchors.fill: parent
        color: Appearance.colors.colLayer0Base
    }

    Image {
        id: desktopSnapshotFallback
        anchors.fill: parent
        source: root.snapshotSource
        fillMode: Image.Stretch
        asynchronous: false
        cache: false
        visible: root.snapshotSource !== ""

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: root.backgroundBlur
            blurMax: 64
            blurMultiplier: 1
        }

        onStatusChanged: root.maybeStartStartupAnimation()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.focusAuth()
    }

    Connections {
        target: root.context
        ignoreUnknownSignals: true

        function onUnlockFailed() {
            root.isExiting = false;
            root.focusAuth();
        }
    }

    Connections {
        target: root.lock

        function onUnlock() {
            root.startExitAnimation();
        }
    }

    Timer {
        id: startupFallbackTimer
        interval: 160
        running: true
        repeat: false
        onTriggered: root.startupFallbackElapsed = true
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
        color: BlurService.backgroundColor(
            Appearance.colors.colLayer0)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.colors.colShadow
            shadowBlur: 0.8
            shadowVerticalOffset: 8
        }

        Text {
            id: lockIcon
            anchors.centerIn: parent
            text: "lock"
            rotation: 180
            color: Appearance.colors.colOnSurface
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.compactSize * 0.56
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        LockContent {
            id: lockContent
            anchors.centerIn: parent
            width: root.targetWidth - Sizes.lockOuterPadding * 2
            height: root.targetHeight - Sizes.lockOuterPadding * 2
            context: root.context
            // Size cards from the usable panel, not from the larger screen.
            screenHeight: height
            opacity: root.contentOpacity
            scale: root.contentScale
            visible: opacity > 0 || root.morphProgress > 0.96
        }
    }

    SequentialAnimation {
        id: exitAnim

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

        onFinished: {
            if (root.context)
                root.context.finishUnlock();
            else
                root.lock.locked = false;
        }
    }
}
