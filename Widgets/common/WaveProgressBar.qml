import QtQuick

Item {
    id: root

    // === 必需属性 ===
    required property real progress       // 0.0~1.0 当前进度
    required property color waveColor     // 波浪/已播放颜色
    required property color trackColor    // 未播放轨道颜色

    // === 可选属性 ===
    property bool isPlaying: false        // 控制波浪动画运行
    property real waveAmplitude: 2.5      // 波浪振幅
    property real waveFrequency: 0.12     // 波浪频率
    property real trackHeight: 6          // 轨道高度
    property real trackRadius: trackHeight / 2
    property real progressGap: 10         // 已播放与未播放轨道间的缺口
    property real seekMargin: 10          // seek 区域外扩边距
    property real fadeLength: 30
    property real secondaryWaveFrequencyMultiplier: 1.5
    property real secondaryWaveAmplitude: 0.3
    property real waveBias: 1.3
    property int phaseDuration: 1200
    property int smoothingDuration: 400
    property real smoothingVelocity: 500

    // === 信号 ===
    signal seekRequested(real position)   // 拖动释放时发出 0~1 比例

    // === 只读：是否正在拖动 ===
    readonly property bool pressed: seekMa.pressed

    // === 当前可视进度 X 坐标（供外部读取） ===
    readonly property real visualX: _visualX

    implicitHeight: 36

    // --- 内部状态 ---
    property real _targetX: root.progress * root.width
    property real _activeX: seekMa.pressed ? Math.max(0, Math.min(seekMa.mouseX, root.width)) : _targetX
    property real _visualX: _activeX
    readonly property bool _hasProgressSplit: _visualX > 0 && _visualX < width
    readonly property real _playedEndX: _hasProgressSplit ? Math.max(0, _visualX - progressGap / 2) : Math.max(
                                                                0, Math.min(_visualX, width))
    readonly property real _remainingStartX: _hasProgressSplit ? Math.min(width, _visualX + progressGap / 2) :
                                                                 Math.max(0, Math.min(_visualX, width))

    Behavior on _visualX {
        enabled: root.visible && !seekMa.pressed
        SmoothedAnimation {
            velocity: root.smoothingVelocity
            duration: root.smoothingDuration
        }
    }

    // --- 未播放轨道：从缺口右侧开始，左端保持半圆形 ---
    Rectangle {
        x: root._remainingStartX
        width: Math.max(0, parent.width - x)
        anchors.verticalCenter: parent.verticalCenter
        height: root.trackHeight
        radius: root.trackRadius
        color: root.trackColor
        visible: width > 0
    }

    // --- 波浪 Canvas ---
    Canvas {
        id: waveCanvas
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root._playedEndX
        visible: width > 0

        property real phase: 0

        NumberAnimation on phase {
            loops: Animation.Infinite
            from: 0
            to: Math.PI * 2
            duration: root.phaseDuration
            easing.type: Easing.Linear
            running: root.isPlaying
        }

        onPhaseChanged: requestPaint()
        onAvailableChanged: {
            if (available)
                requestPaint();
        }
        onVisibleChanged: {
            if (visible)
                requestPaint();
        }

        Connections {
            target: root
            function on_VisualXChanged() {
                waveCanvas.requestPaint();
            }
            // Theme colors may arrive after the first paint, even while paused.
            function onWaveColorChanged() {
                waveCanvas.requestPaint();
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            let trackH = root.trackHeight;
            let radius = root.trackRadius;
            let centerY = height / 2;
            let w = width;

            if (w <= 0)
                return;

            if (w < radius * 2) {
                ctx.beginPath();
                ctx.arc(w / 2, centerY, w / 2, 0, Math.PI * 2);
                ctx.fillStyle = String(root.waveColor);
                ctx.fill();
                return;
            }

            const endCenterX = w - radius;

            ctx.beginPath();
            ctx.moveTo(endCenterX, centerY + trackH / 2);
            ctx.lineTo(radius, centerY + trackH / 2);
            ctx.arc(radius, centerY, radius, Math.PI / 2, Math.PI * 1.5);

            let freq = root.waveFrequency;
            let maxAmp = root.waveAmplitude;
            let fadeLen = root.fadeLength;

            for (let x = radius; x <= endCenterX; x++) {
                let leftDist = x - radius;
                let rightDist = endCenterX - x;
                let envelope = 1.0;

                if (leftDist < fadeLen) {
                    envelope = Math.sin((leftDist / fadeLen) * (Math.PI / 2));
                }
                if (rightDist < fadeLen) {
                    let envRight = Math.sin((rightDist / fadeLen) * (Math.PI / 2));
                    if (envRight < envelope) {
                        envelope = envRight;
                    }
                }

                let wave1 = Math.sin(x * freq - phase);
                let wave2 = Math.sin(x * freq * root.secondaryWaveFrequencyMultiplier - phase * 2.0)
                    * root.secondaryWaveAmplitude;
                let combined = (wave1 + wave2 + root.waveBias) / (2 * root.waveBias);

                if (combined < 0)
                    combined = 0;
                if (combined > 1)
                    combined = 1;

                let y = (centerY - trackH / 2) - (combined * maxAmp * envelope);
                ctx.lineTo(x, y);
            }

            ctx.arc(endCenterX, centerY, radius, -Math.PI / 2, Math.PI / 2);
            ctx.closePath();
            ctx.fillStyle = String(root.waveColor);
            ctx.fill();
        }
    }

    // --- Seek 交互区 ---
    MouseArea {
        id: seekMa
        anchors.fill: parent
        anchors.margins: -root.seekMargin
        cursorShape: Qt.PointingHandCursor

        onReleased: mouse => {
            let clampedX = Math.max(0, Math.min(mouse.x, root.width));
            root.seekRequested(clampedX / root.width);
        }
    }
}
