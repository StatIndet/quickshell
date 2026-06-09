import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var screen: null

    Item {
        anchors.fill: parent
        
        NetworkContent { 
            anchors.fill: parent 
            
            // ============================================================
            // 【核心修复】：将动画控制权收回到 QuickSettings 层
            // ============================================================
            opacity: WidgetState.qsView === "network" ? 1.0 : 0.0
            scale: WidgetState.qsView === "network" ? 1.0 : 0.95
            visible: opacity > 0
            
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
        }

        AudioContent {
            anchors.fill: parent

            // ============================================================
            // 【核心修复】：在这里独立控制混音器面板的显隐动画
            // ============================================================
            opacity: WidgetState.qsView === "audio" ? 1.0 : 0.0
            scale: WidgetState.qsView === "audio" ? 1.0 : 0.95
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
        }

        BluetoothContent {
            anchors.fill: parent

            opacity: WidgetState.qsView === "bluetooth" ? 1.0 : 0.0
            scale: WidgetState.qsView === "bluetooth" ? 1.0 : 0.95
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
        }

        SettingsContent {
            anchors.fill: parent
            screen: root.screen

            opacity: WidgetState.qsView === "settings" ? 1.0 : 0.0
            scale: WidgetState.qsView === "settings" ? 1.0 : 0.95
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
        }
    }
}
