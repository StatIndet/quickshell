import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var cursorThemes: []
    property string currentCursorTheme: ""
    property int fieldWidth: 240

    signal accepted(string value)

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(58, labelColumn.implicitHeight + 16)

    RowLayout {
        anchors.fill: parent
        spacing: 16

        Column {
            id: labelColumn

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                width: parent.width
                text: "光标主题"
                color: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamily
                font.pixelSize: 15
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: "选择当前系统使用的光标主题"
                color: Appearance.colors.colSubtext
                font.family: Sizes.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        SearchSelectMenuField {
            Layout.preferredWidth: root.fieldWidth
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            options: root.cursorThemes
            value: root.currentCursorTheme
            placeholder: "选择光标主题"
            textRole: "label"
            valueRole: "value"
            onAccepted: value => root.accepted(value)
        }
    }
}
