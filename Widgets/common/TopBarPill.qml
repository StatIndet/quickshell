import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    default property alias contentData: contentViewport.data
    property bool animateResize: true
    // Keystone reuses these groups with its own fixed status-lane dimensions.
    property bool useBarDimensions: true
    readonly property real pillThickness: useBarDimensions ? PersonalizationConfig.barThickness :
                                                             Sizes.barPillThickness
    readonly property real pillPadding: useBarDimensions ? PersonalizationConfig.barInnerPadding :
                                                           Sizes.barPillHorizontalPadding

    // Animate the space consumed by the group and its neighbours together.
    property bool resizeAnimationReady: false
    Component.onCompleted: resizeAnimationReady = true

    data: [
        Item {
            id: contentViewport
            anchors.fill: parent
            clip: true
        }
    ]

    Behavior on implicitWidth {
        enabled: root.resizeAnimationReady && root.animateResize
        NumberAnimation {
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }
    }

    Behavior on implicitHeight {
        enabled: root.resizeAnimationReady && root.animateResize
        NumberAnimation {
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }
    }
}
