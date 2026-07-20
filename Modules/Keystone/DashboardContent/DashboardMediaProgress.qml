import QtQuick
import qs.Common

// Adapted from Caelestia Shell's CircularProgress and WavyLine (GPL-3.0).
Item {
    id: root

    required property real progress
    required property bool playing

    property bool active: true
    property color foregroundColor: Appearance.colors.colPrimary
    property color trackColor: Appearance.colors.colSecondaryContainer
    property real lineWidth: 8
    property real spacing: 4
    property real waveFrequency: 8
    property real amplitudeMultiplier: 0.5
    property int phaseDuration: 2000
    property real phase: 0
    property real visualProgress: Math.max(1 / 360, Math.min(1, isNaN(progress) ? 0 : progress))

    readonly property real size: Math.min(width, height)
    readonly property real arcRadius: Math.max(1,
        (size - lineWidth * (1 + amplitudeMultiplier * 2)) / 2)
    readonly property real gapAngle: (spacing + lineWidth) / arcRadius
    readonly property real remainingSweepDegrees: Math.max(1 / 360,
        180 * (1 - visualProgress) - gapAngle * 180 / Math.PI)

    implicitWidth: 222
    implicitHeight: 222

    Behavior on visualProgress {
        NumberAnimation {
            duration: Appearance.animation.standardLarge.duration
            easing.type: Appearance.animation.standardLarge.type
            easing.bezierCurve: Appearance.animation.standardLarge.bezierCurve
        }
    }

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: root.phaseDuration
        easing.type: Easing.Linear
        loops: Animation.Infinite
        running: true
        paused: !root.active || !root.playing
    }

    Canvas {
        id: progressCanvas

        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const centerX = width / 2;
            const centerY = height / 2;
            const radius = root.arcRadius;
            const startAngle = -Math.PI;
            const fullAngle = Math.PI;
            const drawAngle = fullAngle * root.visualProgress;
            const remainingStart = startAngle + drawAngle + root.gapAngle;
            const remainingEnd = startAngle + fullAngle;

            ctx.lineWidth = root.lineWidth;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            if (remainingStart < remainingEnd) {
                ctx.beginPath();
                ctx.strokeStyle = String(root.trackColor);
                ctx.arc(centerX, centerY, radius, remainingStart, remainingEnd, false);
                ctx.stroke();
            }

            if (drawAngle <= 0)
                return;

            const amplitude = root.lineWidth * root.amplitudeMultiplier;
            const phaseRadians = root.phase * Math.PI * 2;
            const arcLength = radius * fullAngle;
            const sampleCount = Math.max(64, Math.ceil(radius * drawAngle));
            const stepAngle = drawAngle / sampleCount;

            ctx.beginPath();
            ctx.strokeStyle = String(root.foregroundColor);

            for (let i = 0; i <= sampleCount; ++i) {
                const theta = startAngle + i * stepAngle;
                const distance = i * stepAngle * radius;
                const waveAngle = root.waveFrequency * Math.PI * 2 * distance / arcLength
                    + phaseRadians;
                const waveRadius = radius + amplitude * Math.sin(waveAngle);
                const x = centerX + waveRadius * Math.cos(theta);
                const y = centerY + waveRadius * Math.sin(theta);

                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }

            ctx.stroke();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root

            function onVisualProgressChanged() { progressCanvas.requestPaint(); }
            function onPhaseChanged() { progressCanvas.requestPaint(); }
            function onForegroundColorChanged() { progressCanvas.requestPaint(); }
            function onTrackColorChanged() { progressCanvas.requestPaint(); }
            function onLineWidthChanged() { progressCanvas.requestPaint(); }
            function onSpacingChanged() { progressCanvas.requestPaint(); }
            function onWaveFrequencyChanged() { progressCanvas.requestPaint(); }
            function onAmplitudeMultiplierChanged() { progressCanvas.requestPaint(); }
        }
    }

    Rectangle {
        width: Math.min(4, root.lineWidth)
        height: width
        radius: width / 2
        color: root.foregroundColor
        opacity: Math.min(1, root.remainingSweepDegrees)
        antialiasing: true
        x: root.width / 2 + root.arcRadius - width / 2
        y: root.height / 2 - height / 2

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }
        }
    }
}
