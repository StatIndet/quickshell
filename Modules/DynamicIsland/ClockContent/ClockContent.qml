import QtQuick
import qs.Common

Item {
    id: root
    property var player

    property string dateStr: ""
    property string timeStr: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let d = new Date()
            root.dateStr = d.toLocaleString(Qt.locale("zh_CN"), "M月d日 ddd")
            root.timeStr = d.toLocaleString(Qt.locale("zh_CN"), "HH:mm")
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 10

        // 左侧日期
        Text {
            text: root.dateStr
            color: Appearance.colors.colPrimary
            font.family: Sizes.fontFamily
            font.pixelSize: 13
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "|"
            color: Appearance.colors.colOutlineVariant
            font.family: Sizes.fontFamily
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }

        // 右侧时间
        Text {
            text: root.timeStr
            color: Appearance.colors.colPrimary
            font.family: Sizes.fontFamily
            font.pixelSize: 22
            font.weight: Font.Black
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
