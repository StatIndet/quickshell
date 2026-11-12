import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Components

Item {
    id: root
    property bool flat: false

    property real value: 0
    property string icon: "monitoring"
    property color fillColor: BarColors.selected
    property color trackColor: BarColors.indicatorTrack
    property color iconColor: BarColors.onIndicator
    property real indicatorSize: 28
    property real iconSize: 15
    property bool showText: false
    property bool vertical: false
    property string displayText: ""
    property real labelSpacing: Sizes.barLabelSpacing
    property bool animationEnabled: true
    property int animationDuration: Appearance.animation.standardSmall.duration
    readonly property real normalizedValue: {
        const numeric = Number(root.value);
        if (!isFinite(numeric))
            return 0;

        return Math.max(0, Math.min(1, numeric));
    }
    property real degree: root.normalizedValue * 360
    readonly property real centerX: root.indicatorSize / 2
    readonly property real centerY: root.indicatorSize / 2
    readonly property real radius: root.indicatorSize / 2
    readonly property real displayTextWidth: displayTextMetrics.width

    implicitWidth: root.vertical ? Math.max(root.indicatorSize, root.showText ? root.displayTextWidth : 0) :
                                   root.indicatorSize + (root.showText ? root.labelSpacing
                                                                         + root.displayTextWidth : 0)
    implicitHeight: root.vertical ? root.indicatorSize + (root.showText ? root.labelSpacing
                                                                          + displayTextMetrics.height : 0) :
                                    Math.max(root.indicatorSize, root.showText ? displayTextMetrics.height :
                                                                                 0)

    Item {
        id: circleCanvas

        width: root.indicatorSize
        height: root.indicatorSize
        x: root.vertical ? (parent.width - width) / 2 : 0
        y: root.vertical ? 0 : (parent.height - height) / 2

        Rectangle {
            visible: !root.flat
            anchors.fill: parent
            radius: width / 2
            color: root.trackColor
        }

        Shape {
            anchors.fill: parent
            visible: !root.flat && root.degree > 0.01
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            ShapePath {
                id: sectorPath

                fillColor: root.fillColor
                strokeColor: root.fillColor
                strokeWidth: 0
                pathHints: ShapePath.PathSolid
                startX: root.centerX
                startY: root.centerY

                PathAngleArc {
                    moveToStart: false
                    centerX: root.centerX
                    centerY: root.centerY
                    radiusX: root.radius
                    radiusY: root.radius
                    startAngle: -90
                    sweepAngle: root.degree
                }

                PathLine {
                    x: sectorPath.startX
                    y: sectorPath.startY
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: root.icon
            iconSize: root.flat ? Sizes.barIconSize : root.iconSize
            color: root.flat ? BarColors.foreground : root.iconColor
            fill: 1
        }
    }

    TextMetrics {
        id: displayTextMetrics

        text: root.displayText
        font.family: Fonts.numeric
        font.pixelSize: Typography.labelLarge.pixelSize
        font.weight: Typography.labelLarge.weight
    }

    Text {
        text: root.displayText
        visible: root.showText
        color: BarColors.foreground
        font.family: Fonts.numeric
        font.pixelSize: Typography.labelLarge.pixelSize
        font.weight: Typography.labelLarge.weight

        anchors {
            left: root.vertical ? undefined : circleCanvas.right
            leftMargin: root.vertical ? 0 : root.labelSpacing
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            top: root.vertical ? circleCanvas.bottom : undefined
            topMargin: root.vertical ? root.labelSpacing : 0
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        }
    }

    Behavior on degree {
        enabled: root.animationEnabled && !root.flat

        NumberAnimation {
            duration: root.animationDuration
            easing.type: Appearance.animation.standardSmall.type
            easing.bezierCurve: Appearance.animation.standardSmall.bezierCurve
        }
    }
}
