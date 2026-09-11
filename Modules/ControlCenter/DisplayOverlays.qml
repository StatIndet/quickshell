import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Components
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
                border.width: Metrics.spacingXXS
                border.color: Appearance.colors.colPrimary
            }
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: Metrics.spacingXL
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(marker.width - Metrics.spacingXL * 2, labelContent.implicitWidth
                                + Metrics.spacingL * 2)
                height: labelContent.implicitHeight + Metrics.spacingM * 2
                radius: Appearance.rounding.full
                color: Appearance.m3colors.m3secondaryContainer
                RowLayout {
                    id: labelContent
                    anchors.centerIn: parent
                    width: parent.width - Metrics.spacingL * 2
                    spacing: Metrics.spacingS
                    MaterialSymbol {
                        text: "monitor"
                        iconSize: Metrics.iconM
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    Text {
                        Layout.fillWidth: true
                        text: marker.screen ? marker.screen.name : ""
                        elide: Text.ElideRight
                        font.family: Typography.titleMedium.family
                        font.pixelSize: Typography.titleMedium.pixelSize
                        font.weight: Typography.titleMedium.weight
                        color: Appearance.colors.colOnSecondaryContainer
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
        WlrLayershell.namespace: "clavis-shell-display-confirmation"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        implicitWidth: Math.min(440, screen ? screen.width : 440)
        implicitHeight: content.implicitHeight + Metrics.spacingXL * 2
        CompositorBlurRegion {
            targetWindow: confirmation
            backgroundItem: confirmationBackground
            radius: confirmationBackground.radius
        }
        Rectangle {
            id: confirmationBackground
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: BlurService.backgroundColor(Appearance.m3colors.m3surfaceContainerHigh)
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
