import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components

Button {
    id: root

    property string buttonIcon: ""
    property string buttonText: ""
    property bool toggled: false
    readonly property real baseWidth: contentItem.implicitWidth + 46
    readonly property real targetRadius: down ? Appearance.rounding.small : height / 2
    readonly property bool tabbedTo: activeFocus
        && (focusReason === Qt.TabFocusReason || focusReason === Qt.BacktabFocusReason)

    implicitHeight: 36
    implicitWidth: down ? baseWidth + 6 : baseWidth
    leftInset: 0
    rightInset: 0
    topInset: 0
    bottomInset: 0
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Material.elevation: 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.clickBounce.duration
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
    }

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        RowLayout {
            id: contentRow

            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                visible: root.buttonIcon !== ""
                text: root.buttonIcon
                iconSize: 22
                color: root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
            }

            Text {
                Layout.preferredHeight: 24
                visible: root.buttonText !== ""
                text: root.buttonText
                verticalAlignment: Text.AlignVCenter
                font.family: Sizes.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
            }
        }
    }

    background: Rectangle {
        id: buttonBackground

        property real animatedRadius: root.targetRadius

        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight
        radius: animatedRadius
        color: root.toggled
            ? (root.down ? Appearance.colors.colPrimaryActive
                : root.hovered ? Appearance.colors.colPrimaryHover
                : Appearance.colors.colPrimary)
            : (root.down ? Appearance.colors.colLayer2Active
                : root.hovered ? Appearance.colors.colLayer2Hover
                : Appearance.colors.colLayer2)
        border.width: root.tabbedTo ? 2 : 0
        border.color: Appearance.colors.colSecondary

        Behavior on animatedRadius {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }
        }
    }
}
