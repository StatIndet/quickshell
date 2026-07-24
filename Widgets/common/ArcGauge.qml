import QtQuick
import qs.Common

Item {
    id: root

    // === 必需属性 ===
    required property real value          // 0.0~1.0 进度值
    required property string icon         // 中心图标文本
    required property color progressColor // 进度弧颜色
    required property color trackColor    // 剩余轨道颜色
    required property color handleColor   // handle 指针颜色
    required property color iconColor     // 中心图标颜色

    // === 可选属性 ===
    property string iconFont: "Material Symbols Outlined"
    property real iconSize: 10
    property real arcRadius: 10
    property real lineWidth: 3
    property real gapAngle: 45
    property real handleSpacing: 4
    property real handleInner: 1.5
    property real handleOuter: 3
    property bool showHandle: true
    property int animDuration: 200

    implicitWidth: 28
    implicitHeight: 28

    // --- 内部动画属性 ---
    property real _animAngle: root.value * (360 - 2 * root.gapAngle)

    Behavior on _animAngle {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();

            let centerX = width / 2;
            let centerY = height / 2;
            let radius = root.arcRadius;
            let lw = root.lineWidth;

            ctx.lineCap = "round";

            // 基础起始角：6 点钟方向 + gapAngle
            let baseStartAngle = (Math.PI / 2) + (root.gapAngle * Math.PI / 180);
            let progressAngleRad = root._animAngle * Math.PI / 180;
            // Round caps consume half a stroke at either end. Include a full
            // stroke width in the centre-line separation so handleSpacing is
            // the visible gap rather than being swallowed by those caps.
            let segmentGapRad = (lw + root.handleSpacing) / radius;

            // ① 进度弧
            let progressEndAngle = baseStartAngle + progressAngleRad;
            if (root._animAngle > 1 && progressEndAngle > (baseStartAngle + 0.01)) {
                ctx.strokeStyle = root.progressColor;
                ctx.lineWidth = lw;
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, baseStartAngle, progressEndAngle, false);
                ctx.stroke();
            }

            // ② Handle 指针
            if (root.showHandle && root._animAngle >= 0) {
                let handleAngle = baseStartAngle + progressAngleRad;
                let innerR = radius - root.handleInner;
                let outerR = radius + root.handleOuter;

                let innerX = centerX + innerR * Math.cos(handleAngle);
                let innerY = centerY + innerR * Math.sin(handleAngle);
                let outerX = centerX + outerR * Math.cos(handleAngle);
                let outerY = centerY + outerR * Math.sin(handleAngle);

                ctx.strokeStyle = root.handleColor;
                ctx.lineWidth = lw;
                ctx.beginPath();
                ctx.moveTo(innerX, innerY);
                ctx.lineTo(outerX, outerY);
                ctx.stroke();
            }

            // ③ 剩余轨道弧
            let remainingStart = baseStartAngle + progressAngleRad + segmentGapRad;
            let totalAngle = (360 - 2 * root.gapAngle) * Math.PI / 180;
            let remainingEnd = baseStartAngle + totalAngle;

            if (remainingStart < remainingEnd) {
                ctx.strokeStyle = root.trackColor;
                ctx.lineWidth = lw;
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, remainingStart, remainingEnd, false);
                ctx.stroke();
            }
        }
    }

    // 中心图标
    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: root.iconFont
        font.pixelSize: root.iconSize
        color: root.iconColor

        Behavior on color {
            ColorAnimation {
                duration: root.animDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    // --- 重绘触发器 ---
    onProgressColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onHandleColorChanged: canvas.requestPaint()
    onShowHandleChanged: canvas.requestPaint()
    onHandleSpacingChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    onArcRadiusChanged: canvas.requestPaint()
    onGapAngleChanged: canvas.requestPaint()
    on_AnimAngleChanged: canvas.requestPaint()
}
