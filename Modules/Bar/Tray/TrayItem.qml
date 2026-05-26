import QtQuick
import Quickshell
import qs.Common
import qs.Widgets.common

MouseArea {
    id: root
    required property var modelData 
    
    // 保持 20x20 的尺寸，完美适配 36px 高度的药丸背景
    implicitWidth: 20
    implicitHeight: 20
    
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    function closeMenu() {
        if (trayMenu.visible) {
            trayMenu.visible = false
        }
    }

    function closeOtherMenus() {
        var siblings = root.parent.children
        for (var i = 0; i < siblings.length; i++) {
            var sibling = siblings[i]
            if (sibling === root) continue
            if (typeof sibling.closeMenu === "function") {
                sibling.closeMenu()
            }
        }
    }

    onClicked: (event) => {
        if (event.button === Qt.LeftButton) {
            modelData.activate();
            trayMenu.visible = false;
        } else if (event.button === Qt.RightButton) {
            if (!trayMenu.visible) {
                closeOtherMenus()
                trayMenu.visible = true
            } else {
                trayMenu.visible = false
            }
        }
    }

    TrayMenu {
        id: trayMenu
        
        rootMenuHandle: root.modelData.menu
        trayName: root.modelData.tooltipTitle || root.modelData.id || "Menu"
        
        anchor.item: root
        anchor.rect.y: (root.mapToItem(null, 0, 0).y > 500) ? -trayMenu.implicitHeight - 5 : root.height + 5
        anchor.rect.x: 0
    }

    Image {
        id: content
        anchors.fill: parent
        
        source: {
            const raw = root.modelData.icon;
            if (raw.indexOf("spotify") !== -1) {
                return "image://icon/spotify";
            }
            return raw;
        }
        
        cache: true
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        
        // 保留这两个属性：抗锯齿和平滑缩放，让原彩图标也保持边缘清晰
        smooth: true
        mipmap: true 
        
        // 微小的交互细节：平时稍微降低一点点透明度融入背景，鼠标悬浮时恢复 100% 亮度
        opacity: root.containsMouse ? 1.0 : 0.85
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    PopupToolTip {
        extraVisibleCondition: root.containsMouse
        text: root.modelData.tooltipTitle || root.modelData.id || "托盘"
    }
}
