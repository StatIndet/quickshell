import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root
    

    property int sidebarWidth: 420
    property int gap: 24 
    property int gooeyRadius: 36  
    readonly property int panelTopMargin: Sizes.barHeight
    readonly property int sidebarY: gap
    readonly property bool contentActive: WidgetState.qsOpen || qsShadow.x < root.offScreenX
    readonly property bool inputActive: WidgetState.qsOpen || qsShadow.x < root.offScreenX - 0.5

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-unified-sidebar"
    WlrLayershell.keyboardFocus: WidgetState.qsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    screen: Brightness.getScreenByName(WidgetState.qsScreenName) || Brightness.activeScreen || Quickshell.screens[0]

    anchors { right: true; top: true; bottom: true }
    margins { top: root.panelTopMargin }
    
    implicitWidth: 600
    visible: root.inputActive
    color: "transparent"

    property int qsTargetHeight: 640
    property int targetX: 600 - sidebarWidth - gap
    property int offScreenX: 600

    Connections {
        target: WidgetState

        function onQsOpenChanged() {
            if (WidgetState.qsOpen)
                keyGateway.forceActiveFocus();
        }
    }

    Item {
        id: hitBoxRegion
        x: qsShadow.x
        y: root.sidebarY
        width: root.inputActive ? sidebarWidth : 0
        height: root.inputActive ? root.qsTargetHeight : 0
    }

    // 展开时 mask 覆盖整个窗口以捕获外部点击
    mask: Region {
        x: 0; y: 0
        width: root.width
        height: root.height
        regions: [
            Region { item: hitBoxRegion }
        ]
    }

    Item {
        id: renderCanvas
        width: parent.width + 100 
        height: parent.height
        x: 0; y: 0

        Item {
            id: rawShapes
            anchors.fill: parent
            visible: false

            Rectangle {
                id: qsShadow
                width: root.sidebarWidth
                height: root.qsTargetHeight
                y: root.sidebarY
                x: WidgetState.qsOpen ? root.targetX : root.offScreenX
                radius: Appearance.rounding.large
                color: "black" 
                Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }
            }

            Rectangle {
                id: offscreenWall
                width: 100; height: parent.height; x: root.offScreenX; color: "black"
            }
        }

        GaussianBlur {
            id: blurredShapes
            anchors.fill: parent; source: rawShapes
            radius: root.gooeyRadius
            samples: 1 + root.gooeyRadius * 2
            visible: false 
        }

        Rectangle { 
            id: solidBg; anchors.fill: parent; 
            color: Appearance.colors.colLayer0;
            visible: false 
        }

        ThresholdMask {
            id: gooeyLayer
            anchors.fill: parent; source: solidBg; maskSource: blurredShapes
            threshold: 0.51; spread: 0.02
        }
    }

    Item {
        id: keyGateway
        anchors.fill: parent
        focus: WidgetState.qsOpen

        Keys.onEscapePressed: (event) => {
            WidgetState.closeAllPopups();
            event.accepted = true;
        }

        // 点击外部关闭侧边栏
        MouseArea {
            anchors.fill: parent
            enabled: WidgetState.qsOpen
            onClicked: WidgetState.qsOpen = false
        }

        Item {
            width: qsShadow.width; height: qsShadow.height
            x: qsShadow.x; y: qsShadow.y; clip: true

            // 阻止点击事件穿透到外部 MouseArea
            MouseArea {
                anchors.fill: parent
                onClicked: {} // 消费点击事件，不传播
            }

            Loader {
                anchors.fill: parent
                active: root.contentActive
                sourceComponent: quickSettingsComponent
            }
        }
    }

    Component {
        id: quickSettingsComponent

        QuickSettings {
            screen: root.screen
            anchors.fill: parent
        }
    }
}
