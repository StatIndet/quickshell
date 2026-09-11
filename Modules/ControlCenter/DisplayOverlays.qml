import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: marker
            required property var modelData
            screen: modelData
            visible: DisplayConfigService.identify
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "clavis-display-identify"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            mask: Region {}
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: Metrics.spacingXS
                border.color: Appearance.colors.colPrimary
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: label.implicitWidth + Metrics.spacingXL * 2
                    height: label.implicitHeight + Metrics.spacingL * 2
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colPrimary
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: marker.screen.name
                        font.family: Fonts.ui
                        font.pixelSize: Typography.headlineSmall.pixelSize
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }
    PanelWindow {
        id: confirmation
        screen: Quickshell.screens.length ? Quickshell.screens[0] : null
        visible: DisplayConfigService.confirming
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "clavis-display-confirmation"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        implicitWidth: Math.min(440, screen ? screen.width : 440)
        implicitHeight: content.implicitHeight + Metrics.spacingXL * 2
        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colors.colSurfaceContainer
            border.width: Metrics.dividerWidth
            border.color: Appearance.colors.colOutline
            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: DisplayConfigService.revert()
                Keys.onReturnPressed: DisplayConfigService.keep()
                ColumnLayout {
                    id: content
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Metrics.spacingXL
                    }
                    spacing: Metrics.spacingL
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Keep display changes?")
                        wrapMode: Text.Wrap
                        font.family: Fonts.ui
                        font.pixelSize: Typography.titleLarge.pixelSize
                        color: Appearance.colors.colOnSurface
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Reverting in %n second(s)", "", DisplayConfigService.remaining)
                        wrapMode: Text.Wrap
                        font.family: Fonts.ui
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingS
                        ActionButton {
                            text: qsTr("Revert")
                            onClicked: DisplayConfigService.revert()
                        }
                        ActionButton {
                            text: qsTr("Keep Changes")
                            filled: true
                            onClicked: DisplayConfigService.keep()
                        }
                    }
                }
            }
        }
    }
}
