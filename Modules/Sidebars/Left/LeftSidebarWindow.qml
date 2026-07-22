import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets.common

PanelWindow {
    id: root
    

    property int sidebarWidth: 540
    property int gap: 24 
    property int gooeyRadius: 36  
    readonly property int sidebarY: Sizes.barHeight + gap
    readonly property int closedSlideOffset: -sidebarWidth - 100
    readonly property bool contentActive: WidgetState.leftSidebarOpen || animController.slideOffset > closedSlideOffset

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-unified-left-sidebar"
    WlrLayershell.keyboardFocus: WidgetState.leftSidebarOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors { left: true; top: true; bottom: true }
    
    implicitWidth: sidebarWidth + 100
    color: "transparent"

    readonly property int qsTargetHeight: root.height - sidebarY - gap

    Connections {
        target: WidgetState

        function onLeftSidebarOpenChanged() {
            if (WidgetState.leftSidebarOpen)
                keyGateway.forceActiveFocus();
        }
    }
    
    Item {
        id: animController
        property int slideOffset: -sidebarWidth - 80 

        state: WidgetState.leftSidebarOpen ? "open" : "closed"
        
        states: [
            State { name: "open"; PropertyChanges { target: animController; slideOffset: 0 } },
            State { name: "closed"; PropertyChanges { target: animController; slideOffset: root.closedSlideOffset } }
        ]

        Behavior on slideOffset {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutBack
                easing.overshoot: 0.3
            }
        }
    }

    Item {
        id: hitBoxRegion
        // 【修正】：鼠标事件判定区必须使用绝对屏幕坐标
        x: animController.slideOffset + root.gap 
        y: root.sidebarY
        width: sidebarWidth
        height: root.qsTargetHeight 
    }

    mask: Region { item: hitBoxRegion }

    Item {
        id: renderCanvas
        
        // ============================================================
        // 【核心绝杀】：将整个画布强行向左扯出屏幕 100 像素！
        // 让系统无法再丢弃死水墙，完美保留拉丝的基础！
        // ============================================================
        x: -100
        y: 0
        width: parent.width + 100 
        height: parent.height

        Item {
            id: rawShapes
            anchors.fill: parent
            visible: false

            Rectangle {
                id: qsShadow
                width: root.sidebarWidth
                height: root.qsTargetHeight
                
                // 【补偿】：由于画布向左偏移了 100，内部的 X 必须加上 100 才能回到原位
                x: (animController.slideOffset + root.gap) + 100
                y: root.sidebarY
                radius: Appearance.rounding.large
                color: "black" 
            }

            Rectangle {
                id: offscreenWall
                width: 100
                height: parent.height 
                // 【核心复活】：在这个偏移后的画布里，0 其实就是屏幕绝对坐标的 -100
                // 高斯模糊终于能抓到它了！
                x: 0 
                color: "black"
            }
        }

        GaussianBlur {
            id: blurredShapes
            anchors.fill: parent
            source: rawShapes
            radius: root.gooeyRadius
            samples: 1 + root.gooeyRadius * 2
            visible: false 
        }

        Rectangle { 
            id: solidBg
            anchors.fill: parent 
            color: Appearance.colors.colLayer0
            visible: false 
        }

        ThresholdMask {
            id: gooeyLayer
            anchors.fill: parent
            source: solidBg
            maskSource: blurredShapes
            threshold: 0.51
            spread: 0.02
        }
    }

    Item {
        id: keyGateway
        anchors.fill: parent
        focus: WidgetState.leftSidebarOpen

        Keys.onEscapePressed: (event) => {
            WidgetState.closeAllPopups();
            event.accepted = true;
        }

        Item {
            width: root.sidebarWidth
            height: root.qsTargetHeight
            // 【修正】：内容挂载区也必须使用绝对屏幕坐标
            x: animController.slideOffset + root.gap 
            y: root.sidebarY
            clip: true 

            Loader {
                anchors.fill: parent
                active: root.contentActive
                sourceComponent: leftSidebarContentComponent
            }
        }
    }

    Component {
        id: leftSidebarContentComponent

        LeftSidebarContent {
            anchors.fill: parent
            screenName: root.screen ? root.screen.name : ""
        }
    }
}
