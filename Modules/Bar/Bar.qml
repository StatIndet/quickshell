import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.ActiveWindow
import qs.Modules.Bar.Tray
import qs.Modules.Bar.PowerButton
import qs.Modules.Bar.SysMonitor
import qs.Modules.Bar.QuickSettings
import qs.Common

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: barWindow
        required property var modelData
        screen: modelData

        anchors { left: true; top: true; right: true }
        color: "transparent"
        
        property real barHeight: Sizes.barHeight
        
        // 高度不再受灵动岛影响
        implicitHeight: barWindow.barHeight
        
        exclusiveZone: barHeight
        
        WlrLayershell.layer: WlrLayer.Top

        mask: Region {
            Region { item: leftInputRegion }
            Region { item: rightInputRegion }
        }

        // --- 内容容器 ---
        Item {
            id: barContent

            anchors { top: parent.top; topMargin: -5; left: parent.left; right: parent.right }
            height: barWindow.barHeight 

            // --- 左侧组件 ---
            RowLayout {
                id: leftSection
                anchors { left: parent.left; leftMargin: 10; bottom: parent.bottom }
                width: implicitWidth
                height: implicitHeight
                spacing: 8

                Workspaces {}
                SidebarButton {}
                ActiveWindow {}
                
            }

            // --- 右侧组件 ---
            RowLayout {
                id: rightSection
                anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom }
                width: implicitWidth
                height: implicitHeight
                spacing: 8

                Tray { screen: barWindow.screen }
                SysMonitor { Layout.alignment: Qt.AlignVCenter }
                

                QuickSettings {
                    screen: barWindow.screen
                    Layout.alignment: Qt.AlignVCenter
                }
                
                
            }

            Item {
                id: leftInputRegion
                anchors.left: leftSection.left
                anchors.right: leftSection.right
                anchors.top: leftSection.top
                anchors.bottom: leftSection.bottom
            }

            Item {
                id: rightInputRegion
                anchors.left: rightSection.left
                anchors.right: rightSection.right
                anchors.top: rightSection.top
                anchors.bottom: rightSection.bottom
            }
        }
    }
}
