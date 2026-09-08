import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

Rectangle {
    id: root

    property string keyText: ""
    property string superStyle: PersonalizationConfig.superKeyStyle
    readonly property bool superKey: ["super", "win"].indexOf(keyText.toLowerCase()) !== -1
    readonly property bool logo: superKey && superStyle !== "text"

    implicitWidth: Math.max(24, logo ? 26 : label.implicitWidth + 12)
    implicitHeight: 26
    radius: 5
    color: Appearance.colors.colOnSurface
    Accessible.role: Accessible.StaticText
    Accessible.name: superKey ? "Super" : keyText

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.bottomMargin: 3
        radius: 4
        color: Appearance.m3colors.m3surfaceContainerLow

        Text {
            id: label
            anchors.centerIn: parent
            visible: !root.logo
            text: root.superKey ? "Super" : root.keyText
            font.family: Fonts.mono
            font.pixelSize: 13
            color: Appearance.colors.colOnSurface
        }
        Image {
            id: logoImage
            anchors.centerIn: parent
            width: 16
            height: 16
            visible: false
            source: root.logo ? Qt.resolvedUrl("../../assets/icons/keyboard/" + root.superStyle + ".svg") : ""
            sourceSize: Qt.size(16, 16)
        }
        MultiEffect {
            anchors.fill: logoImage
            source: logoImage
            visible: root.logo
            colorization: 1
            colorizationColor: Appearance.colors.colOnSurface
        }
    }
}
