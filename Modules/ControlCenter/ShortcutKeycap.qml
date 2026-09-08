import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Components
import "../../Common/ShortcutKeySymbols.js" as KeySymbols

Rectangle {
    id: root

    property string keyText: ""
    property string superStyle: PersonalizationConfig.superKeyStyle
    readonly property bool superKey: ["super", "win"].indexOf(keyText.toLowerCase()) !== -1
    readonly property bool logo: superKey && superStyle !== "text" && superStyle !== "command"

    readonly property string symbol: KeySymbols.forKey(keyText)

    implicitWidth: Math.max(30, (logo || symbol.length > 0) ? 32 : label.implicitWidth + 14)
    implicitHeight: 32
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
            visible: !root.logo && root.symbol.length === 0
            text: root.superKey ? (root.superStyle === "command" ? "⌘" : "Super") : root.keyText
            font.family: Fonts.mono
            font.pixelSize: 16
            color: Appearance.colors.colOnSurface
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.symbol.length > 0
            text: root.symbol
            iconSize: 20
            color: Appearance.colors.colOnSurface
        }
        Image {
            id: logoImage
            anchors.centerIn: parent
            width: 20
            height: 20
            visible: false
            source: root.logo ? Qt.resolvedUrl("../../assets/icons/keyboard/" + root.superStyle + ".svg") : ""
            sourceSize: Qt.size(20, 20)
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
