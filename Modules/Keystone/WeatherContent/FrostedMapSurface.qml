import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs.Common

Item {
    id: root

    property Item sourceItem: null
    property rect sourceRect: Qt.rect(0, 0, width, height)
    property bool backdropLive: true
    property real radius: Appearance.rounding.normal
    property real blurAmount: 0.58
    property color tint: Appearance.applyAlpha(
        Appearance.colors.colSurfaceContainerHighest,
        0.62
    )

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    ShaderEffectSource {
        id: backdropCapture

        anchors.fill: parent
        sourceItem: root.sourceItem
        sourceRect: root.sourceRect
        live: root.backdropLive
        recursive: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: backdropCapture
        visible: root.sourceItem !== null
        blurEnabled: visible
        blur: root.blurAmount
        blurMax: 32
        saturation: 0.08
        autoPaddingEnabled: false
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
    }
}
