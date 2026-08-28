import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    required property var targetScreen
    readonly property real buttonSize: Math.max(72, Math.min(128, (width - 112 - actionRow.spacing * 5) / 6))

    screen: targetScreen
    visible: PowerMenuService.active && targetScreen && targetScreen.name === PowerMenuService.targetScreenName
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.namespace: "clavis-shell-power-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    Item {
        id: interactionArea

        anchors.fill: parent
        focus: root.visible
        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Escape:
                PowerMenuService.close();
                break;
            case Qt.Key_L:
                PowerMenuService.trigger("lock");
                break;
            case Qt.Key_E:
                PowerMenuService.trigger("logout");
                break;
            case Qt.Key_U:
                PowerMenuService.trigger("suspend");
                break;
            case Qt.Key_S:
                PowerMenuService.trigger("poweroff");
                break;
            case Qt.Key_H:
                PowerMenuService.trigger("hibernate");
                break;
            case Qt.Key_R:
                PowerMenuService.trigger("reboot");
                break;
            default:
                return ;
            }
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: PowerMenuService.close()
        }

        Rectangle {
            id: menuBackground

            anchors.centerIn: parent
            width: actionRow.implicitWidth + 56
            height: actionRow.implicitHeight + 56
            radius: Appearance.rounding.extraLarge
            color: BlurService.backgroundColor(Appearance.colors.colLayer0)

            MouseArea {
                anchors.fill: parent
            }

            RowLayout {
                id: actionRow

                anchors.centerIn: parent
                spacing: 16

                Repeater {
                    model: [{
                        "action": "lock",
                        "icon": "lock",
                        "label": qsTr("锁屏")
                    }, {
                        "action": "logout",
                        "icon": "logout",
                        "label": qsTr("退出")
                    }, {
                        "action": "suspend",
                        "icon": "bedtime",
                        "label": qsTr("挂起")
                    }, {
                        "action": "poweroff",
                        "icon": "power_settings_new",
                        "label": qsTr("关机")
                    }, {
                        "action": "hibernate",
                        "icon": "mode_night",
                        "label": qsTr("休眠")
                    }, {
                        "action": "reboot",
                        "icon": "restart_alt",
                        "label": qsTr("重启")
                    }]

                    delegate: Rectangle {
                        id: actionButton

                        required property var modelData

                        Layout.preferredWidth: root.buttonSize
                        Layout.preferredHeight: root.buttonSize
                        radius: Appearance.rounding.large
                        color: actionMouse.pressed ? Appearance.colors.colPrimaryActive : (actionMouse.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer1)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 60

                                MaterialSymbol {
                                    id: actionIcon

                                    anchors.centerIn: parent
                                    text: actionButton.modelData.icon
                                    iconSize: 54
                                    fill: 0
                                    color: actionMouse.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                    scale: actionMouse.pressed ? 50 / 54 : (actionMouse.containsMouse ? 1 : 44 / 54)
                                    transformOrigin: Item.Center
                                    smooth: true
                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.mipmap: true

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Appearance.animation.expressiveSlowEffects.duration
                                            easing.type: Appearance.animation.expressiveSlowEffects.type
                                            easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                                        }
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Appearance.animation.expressiveFastEffects.duration
                                            easing.type: Appearance.animation.expressiveFastEffects.type
                                            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                                        }
                                    }

                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: actionButton.modelData.label
                                color: actionMouse.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                font.family: Fonts.ui
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }

                        }

                        MouseArea {
                            id: actionMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerMenuService.trigger(actionButton.modelData.action)
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.expressiveFastEffects.duration
                                easing.type: Appearance.animation.expressiveFastEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                            }

                        }

                    }

                }

            }

        }

        CompositorBlurRegion {
            targetWindow: root
            backgroundItem: menuBackground
            radius: menuBackground.radius
        }

    }

    mask: Region {
        item: interactionArea
    }

}
