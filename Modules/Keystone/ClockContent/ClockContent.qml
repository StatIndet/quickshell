import QtQuick
import qs.Common 

Item {
    id: root
    property var player 

    property string dateStr: ""
    
    // 【核心变化1】把时间拆分成 4 个独立的整数型变量，绑定动画目标值
    property int h0: 0
    property int h1: 0
    property int m0: 0
    property int m1: 0

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let d = new Date()
            root.dateStr = d.toLocaleString(Qt.locale("en_US"), "ddd dd MMM")
            let hStr = d.getHours().toString().padStart(2, '0')
            let mStr = d.getMinutes().toString().padStart(2, '0')
            
            // 转换为整数，驱动数字翻页动画
            root.h0 = parseInt(hStr[0])
            root.h1 = parseInt(hStr[1])
            root.m0 = parseInt(mStr[0])
            root.m1 = parseInt(mStr[1])
        }
    }

    // ============================================================
    // 【核心变化2】定义可复用的滚动数字组件 (Qt 6 内联组件)
    // ============================================================
    component RollingDigit : Item {
        id: digitContainer
        property int targetDigit: 0
        property color digitColor: "white"
        property real digitRotation: 0
        property real digitOffset: 0
        
        width: digitText.implicitWidth
        height: 24  // 严格限制高度，形成视口
        clip: true  // 开启裁切，隐藏不在视口内的数字
        
        rotation: digitRotation
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: digitOffset

        Text {
            id: digitText
            // 一次性渲染 0-9，通过改变 y 坐标来实现滚动
            text: "0\n1\n2\n3\n4\n5\n6\n7\n8\n9"
            color: digitContainer.digitColor
            font.family: Sizes.fontFamily
            font.pixelSize: 22
            font.weight: Font.Black
            lineHeight: 24 // 必须与视口 height 相同
            lineHeightMode: Text.FixedHeight
            
            // 计算 y 轴偏移量
            y: -digitContainer.targetDigit * 24

            // 弹性动画，带来带有惯性回弹的机械翻页感
            Behavior on y {
                SpringAnimation { 
                    spring: 3.5 
                    damping: 0.75 
                    mass: 1.0 
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 10 
        
        // --- 左侧日期部分 ---
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

        // --- 右侧 Standby 滚动时钟 ---
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5 
            
            // 小时部分
            Row {
                spacing: -1 
                
                RollingDigit {
                    targetDigit: root.h0
                    digitColor: Appearance.colors.colInversePrimary 
                    digitRotation: -3 // 各自独立的倾斜角度
                    digitOffset: -2    // 各自独立的高低落差
                }
                RollingDigit {
                    targetDigit: root.h1
                    digitColor: Appearance.colors.colPrimary // 不透明的主题亮色
                    digitRotation: 3  
                    digitOffset: 1   
                }
            }

            // 冒号
            Column {
                spacing: 3 
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1 
                
                Rectangle { width: 4; height: 4; radius: 2; color: Appearance.colors.colOutlineVariant }
                Rectangle { width: 4; height: 4; radius: 2; color: Appearance.colors.colOutlineVariant }
            }

            // 分钟部分
            Row {
                spacing: 1 
                
                RollingDigit {
                    targetDigit: root.m0
                    digitColor: Appearance.colors.colInversePrimary
                    digitRotation: -2 
                    digitOffset: -1
                }
                RollingDigit {
                    targetDigit: root.m1
                    digitColor: Appearance.colors.colPrimary
                    digitRotation: 2
                    digitOffset: 1 
                }
            }
        }
    }
}
