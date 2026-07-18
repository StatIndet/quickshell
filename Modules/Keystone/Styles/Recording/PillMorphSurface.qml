import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common

Item {
    id: root

    required property vector2d mainCenter
    required property vector2d mainSize
    required property real mainRadius
    required property vector2d satelliteCenter
    required property vector2d satelliteSize
    required property real satelliteRadius
    required property real blendRadius

    property color surfaceColor: Appearance.colors.colLayer0
    property real edgeSoftness: 0.8
    property bool shadowEnabled: true

    component MorphShader: ShaderEffect {
        anchors.fill: parent

        property vector2d resolution: Qt.vector2d(width, height)
        property color fillColor: root.surfaceColor
        property vector2d mainCenter: root.mainCenter
        property vector2d mainSize: root.mainSize
        property real mainRadius: root.mainRadius
        property vector2d satelliteCenter: root.satelliteCenter
        property vector2d satelliteSize: root.satelliteSize
        property real satelliteRadius: root.satelliteRadius
        property real blendRadius: root.blendRadius
        property real edgeSoftness: root.edgeSoftness

        fragmentShader: Qt.resolvedUrl(
            "../../../../assets/shaders/keystone/qsb/pill_morph.frag.qsb"
        )
    }

    MorphShader {
        id: shadowSource

        fillColor: "black"
        visible: false
    }

    DropShadow {
        anchors.fill: shadowSource
        source: shadowSource
        horizontalOffset: 0
        verticalOffset: 4
        radius: 10
        samples: 21
        color: Appearance.colors.colShadow
        opacity: root.shadowEnabled ? 1 : 0
        cached: false
    }

    MorphShader {}
}
