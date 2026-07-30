import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common 
import qs.Services

// 新增引入我们的 C++ 高性能监控库
import Clavis.Sysmon 1.0

Item {
    id: root

    property bool isHovered: mouseArea.containsMouse
    readonly property real cpuPowerWatts:
        Number(SystemMonitorService.cpu.powerWatts)
    readonly property real batteryPowerWatts:
        Number(SystemMonitorService.battery.powerWatts)
    readonly property real displayedPowerWatts:
        isFinite(cpuPowerWatts) && cpuPowerWatts > 0
            ? cpuPowerWatts
            : (isFinite(batteryPowerWatts) && batteryPowerWatts > 0
                ? batteryPowerWatts : NaN)

    Component.onCompleted: SystemMonitorService.acquire()
    Component.onDestruction: SystemMonitorService.release()
    
    implicitHeight: 36
    
    implicitWidth: {
        if (isHovered)
            return contentLayout.implicitWidth + 24;
        return ramGroup.implicitWidth + 24;
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: BlurService.backgroundColor(
            Appearance.colors.colLayer0)
        radius: height / 2 
        visible: false 
    }

    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Qt.alpha(Appearance.colors.colShadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
    }

    // （这里原本庞大的 Process 启动子线程和 SplitParser JSON 提取，以及循环调度的 Timer 已被彻底抹去）

    // ================= 布局内容 =================
    RowLayout {
        id: contentLayout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 12
        spacing: 12
        layoutDirection: Qt.RightToLeft

        // --- 1. RAM (常驻) ---
        RowLayout {
            id: ramGroup
            spacing: 4
            Text { 
                text: "" 
                color: Appearance.colors.colSecondary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }
            Text { 
                // 同时保全了原始流的传递。并在这里调取新的 ramUsedGB。toFixed(1) 可保留如 14.2G 格式：
                text: SysmonPlugin.ramUsedGB.toFixed(1) + "G"
                color: Appearance.colors.colOnSurface
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 13
            }
        }

        // --- 2. Disk (展开) ---
        RowLayout {
            id: gpuGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Text {
                text: "󰢮"
                color: Appearance.colors.colSecondary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }
            Text {
                text: Math.round(SysmonPlugin.gpuUsage) + "%"
                color: Appearance.colors.colOnSurface
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 13
            }
        }

        // --- 3. Power draw (expanded) ---
        RowLayout {
            id: powerGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            
            Text { 
                text: ""
                color: Appearance.colors.colPrimary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }
            Text { 
                text: isFinite(root.displayedPowerWatts)
                    ? root.displayedPowerWatts.toFixed(1) + "W"
                    : "--W"
                color: Appearance.colors.colOnSurface
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 13
            }
        }

        // --- 4. Temp (展开) ---
        RowLayout {
            id: tempGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            
            Text { 
                text: "" 
                color: Appearance.colors.colTertiary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }
            Text { 
                text: Math.round(SysmonPlugin.coreTemp) + "°C"
                color: Appearance.colors.colOnSurface
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 13
            }
        }

        // --- 5. CPU (展开) ---
        RowLayout {
            id: cpuGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            
            Text { 
                text: "" 
                color: Appearance.colors.colOnSurfaceVariant
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }
            Text { 
                text: Math.round(SysmonPlugin.cpuUsage) + "%"
                color: Appearance.colors.colOnSurface
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 13
            }
        }
    }

    // ================= 交互区域 =================
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true 
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            Quickshell.execDetached(["gnome-system-monitor"]);
        }
    }
}
