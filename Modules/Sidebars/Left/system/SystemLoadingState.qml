import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common

Item {
    id: root

    property string message: "正在连接系统监测服务"

    implicitHeight: 240

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.medium

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: root.visible
            Material.accent: Appearance.colors.colPrimary
            Accessible.name: root.message
        }

        Text {
            text: root.message
            color: Appearance.colors.colOnSurface
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeBodyLarge
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: "首个有效快照到达后显示实时指标"
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeBodySmall
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
