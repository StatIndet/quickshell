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
    property real panelPadding: Appearance.spacing.panelPadding
    property real sectionSpacing: 16
    property real headerIconSize: 22
    property real headerTitleSize: 18
    property real headerTitleLeftMargin: 10

    
    // 剥离背景色与边框，让底部固定的液态遮罩透出来！
    color: "transparent"
    border.color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.panelPadding
        spacing: root.sectionSpacing

        RowLayout {
            Layout.fillWidth: true
            Text { text: root.icon; font.family: "Material Symbols Outlined"; font.pixelSize: root.headerIconSize; color: Appearance.colors.colPrimary }
            Text { text: root.title; font.bold: true; font.pixelSize: root.headerTitleSize; color: Appearance.colors.colOnLayer2; Layout.fillWidth: true; Layout.leftMargin: root.headerTitleLeftMargin }
            
            RowLayout { id: headerToolsLayout; spacing: 12 }
        }

        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true; Layout.fillHeight: true
        }
    }
}
