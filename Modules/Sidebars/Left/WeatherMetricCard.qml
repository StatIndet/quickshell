import QtQuick
import QtQuick.Layouts
import qs.Common

Rectangle {
    id: root

    property string icon: "info"
    property string label: ""
    property string value: "--"
    property string detail: ""
    property color accent: Appearance.colors.colSecondary

    radius: 24
    color: Appearance.colors.colLayer1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            radius: 21
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.accent
                font.family: "Material Symbols Outlined"
                font.pixelSize: 22
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: root.label
                color: Appearance.colors.colOnSurfaceVariant
                font.family: "LXGW WenKai GB Screen"
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.value
                color: Appearance.colors.colOnSurface
                font.family: "JetBrainsMono Nerd Font"
                font.bold: true
                font.pixelSize: 14
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.detail
                visible: root.detail.length > 0
                color: Appearance.colors.colOutline
                font.family: "LXGW WenKai GB Screen"
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
