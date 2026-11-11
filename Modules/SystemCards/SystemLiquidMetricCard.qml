import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components

Item {
    id: root

    required property string iconName
    required property string valueText
    required property string supportingText
    required property real level
    property bool valueAvailable: true
    property string accessibilityName: ""
    property color shapeColor: Appearance.colors.colPrimaryContainer
    property color liquidColor: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.62)
    property color contentColor: Appearance.colors.colOnPrimaryContainer
    readonly property real targetLevel: root.valueAvailable ? Math.max(0, Math.min(1, root.level)) : 0
    property real animatedLevel: targetLevel
    readonly property string metricFontFamily: Fonts.expressive
    readonly property var metricFontAxes: Fonts.familyAvailable(Fonts.bundledFamilyName) && Fonts.expressive
                                          === Fonts.bundledFamilyName ? ({
                                                                             "ROND": 25,
                                                                             "wdth": 62
                                                                         }) : ({})

    Accessible.name: root.accessibilityName

    Behavior on animatedLevel {
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveSlowSpatial.bezierCurve
        }
    }

    Item {
        id: shapeFrame

        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.extraLarge
            color: root.shapeColor
        }

        Rectangle {
            id: vesselMask

            anchors.fill: parent
            radius: Appearance.rounding.extraLarge
            color: "white"
            visible: false
            layer.enabled: true
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: vesselMask
            }

            Shape {
                id: liquidFill

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: Math.min(parent.height + 8, parent.height * root.animatedLevel + 8)
                visible: root.animatedLevel > 0
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    id: liquidPath

                    strokeWidth: 0
                    fillColor: root.liquidColor
                    startX: 0
                    startY: 4

                    PathSvg {
                        path: {
                            const width = shapeFrame.width;
                            const height = Math.max(8, liquidFill.height);
                            const amplitude = Math.min(3.5, shapeFrame.height * 0.035);
                            const waveLength = width / 4;
                            const half = waveLength / 2;
                            let result = "M 0," + amplitude + " ";
                            for (let index = 0; index < 4; index += 1) {
                                const x = index * waveLength;
                                result += "Q " + (x + half / 2) + ",0 " + (x + half) + "," + amplitude + " ";
                                result += "Q " + (x + half + half / 2) + "," + (amplitude * 2) + " " + (x
                                                                                                        + waveLength)
                                        + "," + amplitude + " ";
                            }
                            return result + "L " + width + "," + height + " L 0," + height + " Z";
                        }
                    }
                }
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: Appearance.spacing.small
            }
            spacing: -3

            Item {
                Layout.fillHeight: true
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: root.iconName
                color: root.contentColor
                iconSize: Typography.headlineSmall.pixelSize + 4
                fill: 1
            }

            Text {
                Layout.fillWidth: true
                text: root.valueText
                color: root.contentColor
                renderType: Text.NativeRendering
                font {
                    family: root.metricFontFamily
                    pixelSize: Typography.headlineMedium.pixelSize
                    weight: Font.DemiBold
                    variableAxes: root.metricFontAxes
                }
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.supportingText
                color: root.contentColor
                font.family: Fonts.expressive
                font.pixelSize: Typography.labelSmall.pixelSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
