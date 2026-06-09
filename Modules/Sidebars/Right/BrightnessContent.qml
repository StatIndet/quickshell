import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

WidgetPanel {
    id: root
    title: "显示"
    icon: "brightness_6"
    closeAction: () => WidgetState.qsOpen = false

    property var screen: null
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    readonly property real brightnessValue: brightnessMonitor ? brightnessMonitor.brightness : Brightness.brightnessValue

    // Brightness card
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: brightnessContent.implicitHeight + 32
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: brightnessContent
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // Brightness header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "light_mode"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 24
                    color: Appearance.colors.colPrimary
                }

                Text {
                    text: "亮度"
                    font.bold: true
                    font.pixelSize: 15
                    color: Appearance.colors.colOnLayer2
                    Layout.fillWidth: true
                }

                Text {
                    text: Math.round(root.brightnessValue * 100) + "%"
                    font.bold: true
                    font.pixelSize: 15
                    color: Appearance.colors.colPrimary
                }
            }

            // Brightness slider
            Item {
                Layout.fillWidth: true
                height: 20

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.rgba(Appearance.colors.colOnLayer2.r, Appearance.colors.colOnLayer2.g, Appearance.colors.colOnLayer2.b, 0.1)

                    Rectangle {
                        height: parent.height
                        width: parent.width * root.brightnessValue
                        radius: 3
                        color: Appearance.colors.colPrimary
                    }
                }

                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: Appearance.colors.colPrimary
                    x: Math.max(0, Math.min(parent.width * root.brightnessValue - width / 2, parent.width - width))
                    anchors.verticalCenter: parent.verticalCenter
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function updateBrightness(mouse) {
                        let v = mouse.x / width;
                        if (v < 0) v = 0; if (v > 1) v = 1;
                        Brightness.setBrightnessForScreen(root.screen, v);
                    }
                    onPressed: (mouse) => updateBrightness(mouse)
                    onPositionChanged: (mouse) => { if (pressed) updateBrightness(mouse) }
                }
            }
        }
    }

    // Night Light card
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: nightContent.implicitHeight + 32
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: nightContent
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "wb_twilight"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 24
                    color: Wlsunset.gamma !== 100 ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }

                Text {
                    text: "夜间模式"
                    font.bold: true
                    font.pixelSize: 15
                    color: Appearance.colors.colOnLayer2
                    Layout.fillWidth: true
                }

                Text {
                    text: Wlsunset.gamma === 100 ? "已关闭" : Wlsunset.gamma + "%"
                    font.bold: true
                    font.pixelSize: 15
                    color: Wlsunset.gamma !== 100 ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }
            }

            // Night Light slider
            Item {
                Layout.fillWidth: true
                height: 20

                property real gammaNormalized: (Wlsunset.gamma - Wlsunset.gammaLowerLimit) / (100 - Wlsunset.gammaLowerLimit)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.rgba(Appearance.colors.colOnLayer2.r, Appearance.colors.colOnLayer2.g, Appearance.colors.colOnLayer2.b, 0.1)

                    Rectangle {
                        height: parent.height
                        width: parent.width * (1.0 - parent.parent.gammaNormalized)
                        radius: 3
                        color: Appearance.colors.colPrimary
                        anchors.right: parent.right
                    }
                }

                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: Appearance.colors.colPrimary
                    x: Math.max(0, Math.min((1.0 - parent.gammaNormalized) * parent.width - width / 2, parent.width - width))
                    anchors.verticalCenter: parent.verticalCenter
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function updateGamma(mouse) {
                        let v = 1.0 - (mouse.x / width);
                        if (v < 0) v = 0; if (v > 1) v = 1;
                        let gamma = v * (100 - Wlsunset.gammaLowerLimit) + Wlsunset.gammaLowerLimit;
                        Wlsunset.setGamma(Math.round(gamma));
                    }
                    onPressed: (mouse) => updateGamma(mouse)
                    onPositionChanged: (mouse) => { if (pressed) updateGamma(mouse) }
                }
            }

            // Quick toggle to disable
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 18
                color: Wlsunset.gamma === 100 ? Appearance.colors.colLayer2Active : "transparent"
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                Text {
                    anchors.centerIn: parent
                    text: Wlsunset.gamma === 100 ? "夜间模式已关闭" : "关闭夜间模式"
                    font.pixelSize: 13
                    color: Appearance.colors.colOnLayer2
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wlsunset.setGamma(100)
                }
            }
        }
    }

    // Appearance card
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: appearContent.implicitHeight + 32
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: appearContent
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: UiPreferences.darkMode ? "dark_mode" : "light_mode"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 24
                    color: Appearance.colors.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "外观"
                        font.bold: true
                        font.pixelSize: 15
                        color: Appearance.colors.colOnLayer2
                    }

                    Text {
                        text: UiPreferences.darkMode ? "深色模式" : "浅色模式"
                        font.pixelSize: 11
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                }

                // Toggle switch
                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: UiPreferences.darkMode ? Appearance.colors.colPrimary : "transparent"
                    border.width: UiPreferences.darkMode ? 0 : 2
                    border.color: Appearance.colors.colOutline
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Rectangle {
                        width: UiPreferences.darkMode ? 16 : 12
                        height: UiPreferences.darkMode ? 16 : 12
                        radius: width / 2
                        x: UiPreferences.darkMode ? parent.width - width - 4 : 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: UiPreferences.darkMode ? Appearance.colors.colOnPrimary : Appearance.colors.colOutline

                        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: UiPreferences.toggleDarkMode()
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
