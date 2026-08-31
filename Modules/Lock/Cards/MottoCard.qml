import QtQuick
import QtQuick.Layouts
import qs.Common

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 160
    // 使用全局配置的颜色和圆角
    color: Appearance.colors.colLayer2
    radius: Metrics.lockCardRadius

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.lockCardPadding
        spacing: 0

        // 左上角引号
        Text {
            text: "“"
            // 使用次级文字颜色，或者用 primary 强调色
            color: Appearance.colors.colOnSurfaceVariant
            font.pixelSize: 60
            font.family: Fonts.ui
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.preferredHeight: 40
        }

        // 中间正文
        Text {
            text: qsTr("休息一下，\n马上回来。")
            color: Appearance.colors.colOnSurface
            font.family: Fonts.ui
            font.pixelSize: 26
            font.bold: true
            font.italic: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            lineHeight: 1.3
        }

        // 右下角引号
        Text {
            text: "”"
            color: Appearance.colors.colOnSurfaceVariant
            font.pixelSize: 60
            font.family: Fonts.ui
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            Layout.preferredHeight: 40
        }

    }

}
