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
    Layout.preferredHeight: 58

    RowLayout {
        anchors.fill: parent
        spacing: 16

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: qsTr("Cursor theme")
            color: Appearance.colors.colOnSurface
            font.family: Fonts.ui
            font.pixelSize: 15
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        SearchSelectMenuField {
            Layout.preferredWidth: root.fieldWidth
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            options: root.cursorThemes
            value: root.currentCursorTheme
            placeholder: qsTr("Choose cursor theme")
            textRole: "label"
            valueRole: "value"
            onAccepted: value => root.accepted(value)
        }
    }
}
