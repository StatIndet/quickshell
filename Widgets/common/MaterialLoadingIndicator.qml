import QtQuick
import qs.Common

Item {
    id: root

    property bool running: visible
    property bool contained: true
    property color containerColor: Appearance.colors.colPrimaryContainer
    property color indicatorColor: Appearance.colors.colOnPrimaryContainer
    property string accessibleName: "正在加载"
    property real animationProgress: 0

    readonly property var phaseStops: [0, 0.14, 0.27, 0.4, 0.54, 0.65, 0.78, 0.89, 1]
    readonly property var rotationStops: [0, 32, 106, 172, 288, 366, 548, 648, 720]
    readonly property var scaleStops: [1, 0.96, 1.02, 0.94, 1, 0.98, 0.91, 0.97, 1]

    implicitWidth: contained ? 64 : 48
    implicitHeight: implicitWidth

    Accessible.name: accessibleName

    function segmentForProgress(progress) {
        for (let index = 0; index < phaseStops.length - 1; index += 1) {
            if (progress < phaseStops[index + 1])
                return index;
        }
        return phaseStops.length - 2;
    }

    function localProgress(progress, segment) {
        const start = phaseStops[segment];
        const end = phaseStops[segment + 1];
        return Math.max(0, Math.min(1, (progress - start) / (end - start)));
    }

    function easedProgress(progress, segment) {
        const value = localProgress(progress, segment);

        switch (segment % 4) {
        case 0:
            return 1 - Math.pow(1 - value, 3);
        case 1:
            return value < 0.5
                ? 4 * value * value * value
                : 1 - Math.pow(-2 * value + 2, 3) / 2;
        case 2:
            return value * value * (3 - 2 * value);
        default:
            return value < 0.5
                ? 16 * Math.pow(value, 5)
                : 1 - Math.pow(-2 * value + 2, 5) / 2;
        }
    }

    function interpolatedStopValue(values) {
        const segment = segmentForProgress(animationProgress);
        const progress = easedProgress(animationProgress, segment);
        return values[segment] + (values[segment + 1] - values[segment]) * progress;
    }

    Rectangle {
        anchors.fill: parent
        visible: root.contained
        radius: Appearance.rounding.full
        color: root.containerColor
    }

    Item {
        id: shapeHost

        anchors.centerIn: parent
        width: root.contained ? 44 : 40
        height: width
        rotation: root.interpolatedStopValue(root.rotationStops)
        scale: root.interpolatedStopValue(root.scaleStops)

        Canvas {
            id: shapeCanvas

            anchors.fill: parent
            antialiasing: true

            function polarPoint(angle, radius, scaleX, scaleY, angularOffset) {
                const rotatedAngle = angle + angularOffset;
                return {
                    "x": Math.cos(rotatedAngle) * radius * scaleX,
                    "y": Math.sin(rotatedAngle) * radius * scaleY
                };
            }

            function burstPoint(angle, lobes, innerRadius, outerRadius, angularOffset) {
                const wave = 0.5 + 0.5 * Math.cos(lobes * angle);
                const radius = innerRadius
                    + (outerRadius - innerRadius) * Math.pow(wave, 1.7);
                return polarPoint(angle, radius, 1, 1, angularOffset);
            }

            function scallopPoint(angle, lobes, baseRadius, amplitude, angularOffset) {
                const radius = baseRadius + amplitude * Math.cos(lobes * angle);
                return polarPoint(angle, radius, 1, 1, angularOffset);
            }

            function roundedPolygonPoint(angle, sides, angularOffset) {
                const halfSector = Math.PI / sides;
                const sector = halfSector * 2;
                const shifted = angle - angularOffset + halfSector;
                const localAngle = ((shifted % sector) + sector) % sector - halfSector;
                const polygonRadius = 0.91 * Math.cos(halfSector) / Math.cos(localAngle);
                const radius = 0.84 + (polygonRadius - 0.84) * 0.82;
                return polarPoint(angle, radius, 1, 1, 0);
            }

            function ellipsePoint(angle, scaleX, scaleY, angularOffset) {
                return polarPoint(angle, 1, scaleX, scaleY, angularOffset);
            }

            function statePoint(state, angle) {
                switch (state) {
                case 0:
                case 8:
                    return burstPoint(angle, 12, 0.7, 0.94, Math.PI / 24);
                case 1:
                    return scallopPoint(angle, 8, 0.82, 0.075, Math.PI / 16);
                case 2:
                    return roundedPolygonPoint(angle, 5, -Math.PI / 2);
                case 3:
                    return ellipsePoint(angle, 0.95, 0.72, 0);
                case 4:
                    return burstPoint(angle, 9, 0.72, 0.93, Math.PI / 18);
                case 5:
                    return scallopPoint(angle, 4, 0.79, 0.14, Math.PI / 4);
                case 6:
                    return ellipsePoint(angle, 0.96, 0.58, Math.PI / 10);
                case 7:
                    return scallopPoint(angle, 10, 0.8, 0.1, Math.PI / 20);
                default:
                    return statePoint(0, angle);
                }
            }

            onPaint: {
                const context = getContext("2d");
                context.reset();

                const segment = root.segmentForProgress(root.animationProgress);
                const progress = root.easedProgress(root.animationProgress, segment);
                const centerX = width / 2;
                const centerY = height / 2;
                const radius = Math.min(width, height) / 2;
                const pointCount = 144;

                context.fillStyle = root.indicatorColor;
                context.beginPath();

                for (let index = 0; index <= pointCount; index += 1) {
                    const angle = index / pointCount * Math.PI * 2;
                    const fromPoint = statePoint(segment, angle);
                    const toPoint = statePoint(segment + 1, angle);
                    const x = centerX + (fromPoint.x + (toPoint.x - fromPoint.x) * progress) * radius;
                    const y = centerY + (fromPoint.y + (toPoint.y - fromPoint.y) * progress) * radius;

                    if (index === 0)
                        context.moveTo(x, y);
                    else
                        context.lineTo(x, y);
                }

                context.closePath();
                context.fill();
            }
        }
    }

    NumberAnimation on animationProgress {
        from: 0
        to: 1
        duration: 4800
        loops: Animation.Infinite
        running: root.running
    }

    onAnimationProgressChanged: shapeCanvas.requestPaint()
    onIndicatorColorChanged: shapeCanvas.requestPaint()
    onWidthChanged: shapeCanvas.requestPaint()
    onHeightChanged: shapeCanvas.requestPaint()
    Component.onCompleted: shapeCanvas.requestPaint()
}
