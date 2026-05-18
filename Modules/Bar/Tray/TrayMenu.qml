import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects  // 引入现代 Qt 6 特效库
import Quickshell
import qs.Common 

PopupWindow {
    id: root

    property var rootMenuHandle: null
    property string trayName: ""
    
    implicitWidth: 240
    implicitHeight: Math.min(600, mainLayout.implicitHeight + 20)
    color: "transparent"
    
    onVisibleChanged: {
        if (visible) {
            menuStack.clear()
        }
    }

    // --- 1. 状态堆栈 ---
    ListModel {
        id: menuStack
    }

    property var currentSubMenuHandle: {
        if (menuStack.count === 0) return null
        return menuStack.get(menuStack.count - 1).handle
    }

    // --- 2. 双通道数据源 ---
    QsMenuOpener {
        id: rootOpener
        menu: root.rootMenuHandle
    }

    QsMenuOpener {
        id: subOpener
        menu: root.currentSubMenuHandle
    }

    // --- 3. 隐形数据激活器 (Hydrator) ---
    QsMenuAnchor {
        id: hydrator
        anchor.window: root
        anchor.item: mainLayout
        // 设为当前窗口中心，防止 Wayland 强制推到屏幕左上角
        anchor.rect.x: root.width / 2
        anchor.rect.y: root.height / 2
        // 设为极小尺寸
        anchor.rect.width: 1
        anchor.rect.height: 1
    }

    // --- 4. 导航逻辑 ---
    function navigateToSubmenu(menuHandle, menuText) {
        if (!menuHandle) return

        menuStack.append({ "handle": menuHandle, "title": menuText })

        try {
            // 1. 标准 API 调用
            if (typeof menuHandle.aboutToShow === "function") menuHandle.aboutToShow()
            if (typeof menuHandle.updateLayout === "function") menuHandle.updateLayout()
            
            // 2. 暴力激活 (瞬时开关)
            hydrator.menu = menuHandle
            hydrator.open()
            
            // 【Bug 修复核心】：引入 Qt.callLater 延迟关闭
            // 确保 DBus 有足够的时间将子菜单数据发送过来，防止 NetworkManager 等组件卡在 Loading...
            Qt.callLater(() => {
                // 安全检查：确保关闭的是同一个菜单的 Hydrator
                if (hydrator.menu === menuHandle) {
                    hydrator.close()
                }
            })
            
        } catch (e) {
            console.warn("Hydrator error:", e)
        }
    }

    function navigateBack() {
        if (menuStack.count > 0) {
            menuStack.remove(menuStack.count - 1, 1)
        }
    }

    // --- 界面渲染 ---
    Rectangle {
        anchors.fill: parent
        // [背景] 深色容器背景
        color: Appearance.m3colors.m3surfaceContainer
        radius: 12
        border.width: 1
        // [边框] 使用 Outline 颜色
        border.color: Appearance.m3colors.m3outlineVariant
        clip: true 

        ColumnLayout {
            id: mainLayout
            width: parent.width
            spacing: 0

            // --- 标题栏 ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "transparent"
                
                // 标题文本
                Text {
                    text: (menuStack.count === 0) ? (root.trayName || "Menu") : menuStack.get(menuStack.count - 1).title
                    anchors.centerIn: parent
                    font.bold: true
                    color: Appearance.colors.colPrimary
                    font.pixelSize: 15
                    width: parent.width - 60
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                // 返回按钮
                Rectangle {
                    visible: menuStack.count > 0
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 6
                    color: backMa.containsMouse ? Appearance.colors.colSecondaryContainer : "transparent"

                    Text {
                        text: "⬅" 
                        anchors.centerIn: parent
                        color: Appearance.colors.colOnSecondaryContainer
                        font.bold: true
                    }

                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateBack()
                    }
                }
                
                // 分割线
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Appearance.colors.colPrimary
                    opacity: 0.2
                }
            }

            // --- 列表内容 ---
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 6 
                spacing: 4        
                
                property var currentModel: (menuStack.count === 0) ?
                                         (rootOpener.children ? rootOpener.children.values : []) : 
                                         (subOpener.children ? subOpener.children.values : [])

                Text {
                    visible: (!parent.currentModel || parent.currentModel.length === 0)
                    text: (menuStack.count > 0) ? "Loading..." : "No Items"
                    color: Appearance.colors.colSecondary
                    font.italic: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.margins: 10
                }

                Repeater {
                    model: parent.currentModel

                    delegate: Rectangle {
                        id: menuItem
                        property bool isSeparator: (modelData.isSeparator === true || modelData.text === "")
                        property bool hasSubMenu: (modelData.hasChildren === true)
                        property var effectiveHandle: (modelData.menu) ? modelData.menu : modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: isSeparator ? 9 : 36 
                        radius: 8
                        
                        // [交互] 悬停背景
                        color: (itemMa.containsMouse && !isSeparator) ? Appearance.colors.colSecondaryContainer : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        // 分割线
                        Rectangle {
                            visible: parent.isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 20
                            height: 1
                            color: Appearance.colors.colOutlineVariant
                            opacity: 0.5
                        }

                        // 内容行
                        RowLayout {
                            visible: !parent.isSeparator
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // 1. 图标 (染色处理)
                            Item {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                visible: (modelData.icon || "") !== ""
                                
                                Image {
                                    id: iconRaw
                                    anchors.fill: parent
                                    source: modelData.icon || ""
                                    visible: false 
                                    fillMode: Image.PreserveAspectFit
                                }
                                
                                // [优化] 使用 MultiEffect 替换老旧的 ColorOverlay
                                MultiEffect {
                                    source: iconRaw
                                    anchors.fill: iconRaw
                                    visible: iconRaw.status === Image.Ready
                                    colorization: 1.0 
                                    colorizationColor: itemMa.containsMouse ?
                                        Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSecondary
                                }
                            }

                            // 2. 勾选状态
                            Text {
                                visible: modelData.toggleState === 1
                                text: "✔"
                                color: Appearance.colors.colPrimary
                                font.bold: true
                            }

                            // 3. 文本
                            Text {
                                text: modelData.text || ""
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                color: {
                                    if (modelData.enabled === false) return Appearance.colors.colOutline;
                                    if (itemMa.containsMouse) return Appearance.colors.colOnSecondaryContainer;
                                    return Appearance.colors.colOnSurface;
                                }
                                font.pixelSize: 14
                                font.weight: itemMa.containsMouse ? Font.DemiBold : Font.Normal
                            }

                            // 4. 子菜单箭头
                            Text {
                                visible: hasSubMenu
                                text: "›"
                                font.pixelSize: 20
                                font.bold: true
                                color: itemMa.containsMouse ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colTertiary
                            }
                        }

                        MouseArea {
                            id: itemMa
                            visible: !parent.isSeparator
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: modelData.enabled !== false

                            onClicked: {
                                if (hasSubMenu) {
                                    root.navigateToSubmenu(effectiveHandle, modelData.text)
                                } else {
                                    modelData.triggered()
                                    root.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
