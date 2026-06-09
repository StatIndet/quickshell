import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common

Item {
    id: root

    property var screen: null
    
    // 维持 36 的高度
    implicitHeight: 36
    implicitWidth: layout.width + 16

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Appearance.colors.colLayer0
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

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8 
        
        // 直接调用同目录下的组件，无需 import
        Network {
            screen: root.screen
        }
        Bluetooth {
            screen: root.screen
        }
        Brightness {
            screen: root.screen
        }
        Volume {
            screen: root.screen
        }
        Microphone {
            screen: root.screen
        }
        SettingsButton {
            screen: root.screen
        }
        PowerButton {}
    }
}
