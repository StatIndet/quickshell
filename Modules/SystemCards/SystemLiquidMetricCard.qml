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
    property bool active: true
    property string accessibilityName: ""
    property color shapeColor: Appearance.colors.colPrimaryContainer
    property color liquidColor: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.62)
    property color contentColor: Appearance.colors.colOnPrimaryContainer
    readonly property real targetLevel: root.valueAvailable ? Math.max(0, Math.min(1, root.level)) : 0
    property real animatedLevel: targetLevel
    // Taper at the endpoints so empty/full values have no residual crest or gap.
    readonly property real waveAmplitude: Math.min(10, height * 0.06) * Math.max(0, Math.min(1, animatedLevel
                                                                                             / 0.08, (1
                                                                                                      - animatedLevel)
                                                                                             / 0.08))
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

            // Two broad wave fronts drift at different speeds, inspired by
            // https://codepen.io/stonelee/pen/ZEzqGNZ. Only their transforms
            // animate; the periodic paths do not need rebuilding every frame.
            OceanWave {
                y: shapeFrame.height * (1 - root.animatedLevel) - amplitude
                wavelength: Math.max(1, shapeFrame.width * 1.65)
                amplitude: root.waveAmplitude
                fillDepth: shapeFrame.height + amplitude * 2
                waveColor: root.liquidColor
                opacity: 0.45
                phaseOffset: 0.35
                cycleDuration: 10000
                reverse: true
                flowing: root.active && root.visible && root.valueAvailable
                visible: root.animatedLevel > 0
            }

            OceanWave {
                y: shapeFrame.height * (1 - root.animatedLevel) - amplitude
                wavelength: Math.max(1, shapeFrame.width * 1.35)
                amplitude: root.waveAmplitude * 0.7
                fillDepth: shapeFrame.height + amplitude * 2
                waveColor: root.liquidColor
                cycleDuration: 6000
                flowing: root.active && root.visible && root.valueAvailable
                visible: root.animatedLevel > 0
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

    component OceanWave: Shape {
        id: wave

        required property real wavelength
        required property real amplitude
        required property real fillDepth
        required property color waveColor
        required property int cycleDuration
        property bool flowing: true
        property bool reverse: false
        property real phaseOffset: 0
        property real phase: 0

        x: -(phase + phaseOffset) * wavelength
        width: wavelength * 3
        height: fillDepth
        preferredRendererType: Shape.CurveRenderer

        NumberAnimation on phase {
            from: wave.reverse ? 1 : 0
            to: wave.reverse ? 0 : 1
            duration: wave.cycleDuration
            loops: Animation.Infinite
            running: true
            paused: !wave.flowing || !wave.visible || wave.amplitude <= 0
            easing.type: Easing.Linear
        }

        ShapePath {
            strokeWidth: 0
            fillColor: wave.waveColor

            PathSvg {
                path: {
                    const length = wave.wavelength;
                    const amplitude = wave.amplitude;
                    let result = "M 0," + amplitude + " ";
                    // Three identical periods cover the card at every phase;
                    // wrapping by one wavelength makes each loop seamless.
                    for (let index = 0; index < 3; index += 1) {
                        const x = index * length;
                        result += "Q " + (x + length * 0.25) + "," + (-amplitude) + " " + (x + length * 0.5)
                                + "," + amplitude + " ";
                        result += "Q " + (x + length * 0.75) + "," + (amplitude * 3) + " " + (x + length)
                                + "," + amplitude + " ";
                    }
                    return result + "L " + wave.width + "," + wave.fillDepth + " L 0," + wave.fillDepth
                            + " Z";

                }
            }
        }
    }
}
