import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string screenName: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.spacing.panelPadding
        spacing: Appearance.spacing.panelPadding

        RowLayout {
            Layout.fillWidth: true
            
            Layout.preferredHeight: 50 
            Layout.maximumHeight: 50 
            Layout.alignment: Qt.AlignTop
            
            spacing: 15

            Repeater {
                model: [
                    { id: "info", icon: "info", label: "Info" },
                    { id: "sys", icon: "monitoring", label: "System" },
                    { id: "weather", icon: "cloud", label: "Weather" }
                ]
                
                delegate: Item {
                    id: tabBtn
                    Layout.fillWidth: true
                    Layout.fillHeight: true 
                    
                    property bool isActive: WidgetState.leftSidebarView === modelData.id
                    property bool isHovered: hoverArea.containsMouse
                    
                    property color contentColor: isActive ? Appearance.colors.colOnLayer0 : (isHovered ? Appearance.colors.colOnLayer0 : Qt.rgba(Appearance.colors.colOnLayer0.r, Appearance.colors.colOnLayer0.g, Appearance.colors.colOnLayer0.b, 0.45))

                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -4
                        spacing: 4 
                        
                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: 20
                            fill: tabBtn.isActive ? 1 : 0
                            color: tabBtn.contentColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        Text {
                            text: modelData.label
                            font.family: "LXGW WenKai GB Screen"
                            font.bold: tabBtn.isActive
                            font.pixelSize: 13 
                            color: tabBtn.contentColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tabBtn.isActive ? 40 : 0
                        height: 3
                        radius: 1.5
                        color: Appearance.colors.colOnLayer0
                        opacity: tabBtn.isActive ? 1.0 : 0.0
                        
                        Behavior on width { 
                            NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.5 } 
                        }
                        Behavior on opacity { 
                            NumberAnimation { duration: 200 } 
                        }
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WidgetState.leftSidebarView = modelData.id
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true 
            color: "transparent"
            radius: Appearance.rounding.large

            InfoView {
                anchors.fill: parent
                visible: WidgetState.leftSidebarView === "info"
                screenName: root.screenName
            }

            SystemView {
                anchors.fill: parent
                visible: WidgetState.leftSidebarView === "sys"
            }

            WeatherView {
                anchors.fill: parent
                visible: WidgetState.leftSidebarView === "weather"
            }
        }
    }
}
