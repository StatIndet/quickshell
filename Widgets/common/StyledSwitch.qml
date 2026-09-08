import QtQuick
import QtQuick.Controls
import qs.Common
import QtQuick.Shapes

Switch {
    id: root

    property real scale: 0.75
    property color activeColor: Appearance.colors.colPrimary
    property color inactiveColor: Appearance.colors.colSurfaceContainerHighest

    implicitWidth: 52 * root.scale
    implicitHeight: 32 * root.scale

    background: Rectangle {
        width: parent.width
        height: parent.height
        radius: Appearance.rounding.full
        color: root.checked ? root.activeColor : root.inactiveColor
        border.width: 2 * root.scale
        border.color: root.checked ? root.activeColor : Appearance.colors.colOutline

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }
        }
    }

    indicator: Rectangle {
        width: (root.pressed || root.down) ? (28 * root.scale) : root.checked ? (24 * root.scale) : (16
                                                                                                     * root.scale)
        height: (root.pressed || root.down) ? (28 * root.scale) : root.checked ? (24 * root.scale) : (16
                                                                                                      * root.scale)
        radius: Appearance.rounding.full
        color: root.checked ? Appearance.colors.colOnPrimary : Appearance.colors.colOutline
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.checked ? ((root.pressed || root.down) ? (22 * root.scale) : 24
                                                                          * root.scale) : ((root.pressed
                                                                                            || root.down) ? (
                                                                                                                2 * root.scale) :
                                                                                                            8 * root.scale)

        Shape {
            anchors.centerIn: parent
            width: 18 * root.scale
            height: 18 * root.scale
            preferredRendererType: Shape.CurveRenderer
            opacity: root.checked ? 1 : 0
            Accessible.ignored: true

            // An 18-unit check, independent of font metrics and optical sizing.
            ShapePath {
                strokeColor: "transparent"
                fillColor: root.activeColor
                scale: Qt.size(root.scale, root.scale)
                PathSvg {
                    path: "M 6.75 12.1275 L 3.6225 9 L 2.5575 10.0575 L 6.75 14.25 L 15.75 5.25 L 14.6925 4.1925 Z"
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                    easing.type: Appearance.animation.expressiveEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                }
            }
        }

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }
        }
    }
}
