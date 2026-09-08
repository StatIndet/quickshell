import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components

MenuItem {
    id: root

    property string iconName: ""
    property bool destructive: false
    readonly property color foreground: !enabled ? Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38) :
                                                   destructive ? Appearance.m3colors.m3error :
                                                                 Appearance.colors.colOnSurface

    implicitHeight: visible ? 48 : 0
    leftPadding: 12
    rightPadding: 12
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    indicator: null
    arrow: null

    background: Rectangle {
        radius: Appearance.rounding.small
        color: root.checked ? Appearance.m3colors.m3secondaryContainer : "transparent"
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.foreground
            opacity: root.down ? Appearance.interaction.pressedStateLayerOpacity : root.highlighted
                                 || root.activeFocus ? Appearance.interaction.focusStateLayerOpacity :
                                                       root.hovered
                                                       ? Appearance.interaction.hoverStateLayerOpacity : 0
        }
    }

    contentItem: RowLayout {
        spacing: 12
        MaterialSymbol {
            visible: root.iconName !== ""
            text: root.iconName
            iconSize: 20
            color: root.foreground
        }
        Text {
            Layout.fillWidth: true
            text: root.text
            textFormat: Text.PlainText
            font.family: Fonts.ui
            font.pixelSize: Typography.labelLarge.pixelSize
            font.weight: Typography.labelLarge.weight
            color: root.foreground
            elide: Text.ElideRight
        }
        MaterialSymbol {
            visible: root.checkable
            opacity: root.checked ? 1 : 0
            text: "check"
            iconSize: 20
            color: root.foreground
        }
    }
}
