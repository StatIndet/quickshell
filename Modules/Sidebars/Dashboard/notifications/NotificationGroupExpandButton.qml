import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

RippleButton {
    id: root

    required property int count
    required property bool expanded
    property real fontSize: 12

    implicitHeight: fontSize + 8
    implicitWidth: Math.max(contentItem.implicitWidth + 10, 30)
    buttonRadius: Appearance.rounding.full
    buttonRadiusPressed: Appearance.rounding.full
    containerColor: Appearance.mix(Appearance.colors.colLayer2, Appearance.colors.colLayer2Hover, 0.5)
    stateLayerColor: Appearance.colors.colLayer2Hover
    pressedStateLayerColor: Appearance.colors.colLayer2Active
    rippleColor: Appearance.colors.colOnLayer2

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        RowLayout {
            id: contentRow

            anchors.centerIn: parent
            spacing: 2

            Text {
                visible: root.count > 1
                text: root.count
                font.family: Fonts.numeric
                font.pixelSize: root.fontSize
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer2
            }

            Text {
                text: "keyboard_arrow_down"
                font.family: Fonts.materialSymbolsRounded
                font.pixelSize: 18
                rotation: root.expanded ? 180 : 0
                color: Appearance.colors.colOnLayer2

                Behavior on rotation {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveDefaultEffects.duration
                        easing.type: Appearance.animation.expressiveDefaultEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                    }
                }
            }
        }
    }
}
