import QtQuick
import QtQuick.Layouts
import qs.Common

Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    property alias headerTools: headerToolsLayout.data 
    default property alias content: contentLayout.data
    property var closeAction: () => {} 

    
    // 剥离背景色与边框，让底部固定的液态遮罩透出来！
    color: "transparent"
    border.color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.spacing.panelPadding
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Text { text: root.icon; font.family: "Material Symbols Outlined"; font.pixelSize: 22; color: Appearance.colors.colPrimary }
            Text { text: root.title; font.bold: true; font.pixelSize: 18; color: Appearance.colors.colOnLayer2; Layout.fillWidth: true; Layout.leftMargin: 10 }
            
            RowLayout { id: headerToolsLayout; spacing: 12 }
        }

        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true; Layout.fillHeight: true
        }
    }
}
