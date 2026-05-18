import QtQuick
import QtQuick.Shapes
import qs.Common

Item {
    id: root

    property color waveColor: Appearance.colors.colPrimary
    property color trackColor: waveColor
    property real trackOpacity: 0.28
    property real wavePortion: 0.72
    property real lineWidth: Math.max(2, Math.min(5, height * 0.22))
    property real gap: Math.max(8, lineWidth * 2.4)
    property real waveAmplitude: Math.max(1.2, height * 0.16)
    property real cycles: 4.2
    property real step: Math.max(2, width / 44)
    property int phaseDuration: 1500
    property bool flowing: true
    property real endDotSize: Math.max(3, lineWidth * 0.8)
    property color endDotColor: waveColor

    implicitHeight: 18

    Item {
        id: waveContainer

        anchors.fill: parent

        property real wavePhase: 0
        readonly property real centerY: height / 2
        readonly property real startX: root.lineWidth / 2
        readonly property real endX: Math.max(startX, Math.min(width - root.lineWidth / 2, width * root.wavePortion))
        readonly property real trackStartX: Math.min(width - root.lineWidth / 2, endX + root.gap)
        readonly property real span: Math.max(1, endX - startX)
        readonly property string wavePath: buildWavePath()

        function waveY(x) {
            const t = Math.max(0, Math.min(1, (x - startX) / span));
            return centerY + Math.sin(t * Math.PI * 2 * root.cycles + wavePhase) * root.waveAmplitude;
        }

        function waveSlope(x) {
            const t = Math.max(0, Math.min(1, (x - startX) / span));
            const angle = t * Math.PI * 2 * root.cycles + wavePhase;
            const angleSlope = Math.PI * 2 * root.cycles / span;
            return root.waveAmplitude * Math.cos(angle) * angleSlope;
        }

        function buildWavePath() {
            if (endX <= startX || width <= 0 || height <= 0)
                return "";

            let path = "M " + startX.toFixed(2) + " " + waveY(startX).toFixed(2);
            const sampleStep = Math.max(1, root.step);

            for (let x = startX; x < endX; x += sampleStep) {
                const nextX = Math.min(endX, x + sampleStep);
                const y0 = waveY(x);
                const y1 = waveY(nextX);
                const dx = nextX - x;
                const c1x = x + dx / 3;
                const c1y = y0 + waveSlope(x) * dx / 3;
                const c2x = nextX - dx / 3;
                const c2y = y1 - waveSlope(nextX) * dx / 3;

                path += " C " + c1x.toFixed(2) + " " + c1y.toFixed(2)
                    + " " + c2x.toFixed(2) + " " + c2y.toFixed(2)
                    + " " + nextX.toFixed(2) + " " + y1.toFixed(2);
            }

            return path;
        }

        NumberAnimation on wavePhase {
            from: 0
            to: Math.PI * 2
            duration: root.phaseDuration
            loops: Animation.Infinite
            running: root.visible && root.flowing
        }

        Shape {
            anchors.fill: parent
            opacity: root.trackOpacity
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                strokeWidth: root.lineWidth
                strokeColor: root.trackColor
                fillColor: "transparent"
                startX: waveContainer.trackStartX
                startY: waveContainer.centerY

                PathLine {
                    x: waveContainer.width - root.lineWidth / 2
                    y: waveContainer.centerY
                }
            }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                strokeWidth: root.lineWidth
                strokeColor: root.waveColor
                fillColor: "transparent"

                PathSvg {
                    path: waveContainer.wavePath
                }
            }
        }

        Rectangle {
            width: root.endDotSize
            height: root.endDotSize
            radius: width / 2
            color: root.endDotColor
            opacity: 1
            antialiasing: true
            x: waveContainer.width - root.lineWidth / 2 - width / 2
            y: waveContainer.centerY - height / 2
        }
    }
}
