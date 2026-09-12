import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.audio
import qs.Widgets.common

WidgetPanel {
    id: root

    title: qsTr("Microphone")
    icon: "mic"
    showBackButton: true
    backAction: () => WidgetState.quickSettingsView = "settings"

    property bool foreground: false
    property bool isActive: foreground && WidgetState.quickSettingsView === "microphone"
    property bool inputDevicesExpanded: false
    readonly property bool showInputDevices: root.inputDevicesExpanded
    readonly property string stateMessage: {
        if (Volume.lastError.length > 0)
            return Volume.lastError;
        if (!Volume.ready)
            return qsTr("Connecting to the PipeWire audio service");
        if (Volume.inputDevices.length === 0 && !Volume.inputAvailable)
            return qsTr("No microphone devices detected");
        return "";
    }

    onIsActiveChanged: {
        if (!isActive)
            inputDevicesExpanded = false;
    }

    headerTools: IconButton {
        controlSize: 40
        iconName: "open_in_new"
        iconSize: 20
        iconColor: Appearance.colors.colOnLayer2
        accessibleName: qsTr("Open advanced sound settings")
        hoverStateLayerColor: Appearance.colors.colLayer2Hover
        pressedStateLayerColor: Appearance.colors.colLayer2Active
        onClicked: Volume.openMixer()
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.small

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: Volume.ready ? 0 : 4
            opacity: Volume.ready ? 0 : 1
            indeterminate: true
            Material.accent: Appearance.colors.colPrimary

            Behavior on Layout.preferredHeight {
                ElementMoveAnimation {}
            }
            Behavior on opacity {
                ElementMoveAnimation {}
            }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.stateMessage.length > 0
            tone: Volume.lastError.length > 0 ? "error" : "info"
            iconName: !Volume.ready ? "hourglass_top" : Volume.lastError.length > 0 ? "error" : "info"
            message: root.stateMessage
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: microphoneContent.implicitHeight

            ColumnLayout {
                id: microphoneContent

                width: parent.width - Appearance.spacing.small
                spacing: Appearance.spacing.small

                SettingsSection {
                    Layout.fillWidth: true
                    visible: Volume.ready && (Volume.inputDevices.length > 0 || Volume.inputAvailable)
                    title: qsTr("Input")

                    VolumeSlider {
                        Layout.fillWidth: true
                        visible: Volume.inputAvailable
                        title: Volume.sourceName || qsTr("Default input")
                        iconName: "mic"
                        volume: Volume.sourceVolume
                        muted: Volume.sourceMuted
                        available: Volume.inputAvailable
                        showMuteButton: false
                        onVolumeMoved: value => Volume.setSourceVolume(value)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 40
                        visible: Volume.inputDevices.length > 1 || !Volume.inputAvailable

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Input devices")
                            color: Appearance.colors.colOnLayer1
                            font.family: Fonts.ui
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        IconButton {
                            selected: root.inputDevicesExpanded
                            iconName: "expand_more"
                            iconSize: 22
                            iconColor: Appearance.colors.colOnLayer2
                            selectedIconColor: Appearance.colors.colOnSecondaryContainer
                            selectedContainerColor: Appearance.colors.colSecondaryContainer
                            selectedHoverStateLayerColor: Appearance.colors.colSecondaryContainerHover
                            selectedPressedStateLayerColor: Appearance.colors.colSecondaryContainerActive
                            iconRotation: root.inputDevicesExpanded ? 180 : 0
                            accessibleName: root.inputDevicesExpanded ? qsTr("Collapse input devices") : qsTr(
                                                                            "Expand input devices")
                            hoverStateLayerColor: Appearance.colors.colLayer2Hover
                            pressedStateLayerColor: Appearance.colors.colLayer2Active
                            onClicked: root.inputDevicesExpanded = !root.inputDevicesExpanded

                            Behavior on iconRotation {
                                ElementMoveAnimation {}
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.showInputDevices ? inputDeviceList.targetHeight : 0
                        opacity: root.showInputDevices ? 1 : 0
                        clip: true

                        Behavior on Layout.preferredHeight {
                            ElementMoveAnimation {}
                        }
                        Behavior on opacity {
                            ElementMoveAnimation {}
                        }

                        StyledListView {
                            id: inputDeviceList

                            readonly property real baseContentHeight: count * 56 + Math.max(0, count - 1)
                                                                      * spacing
                            readonly property real targetHeight: Math.min(Sizes.sidebarScrollableListMaxHeight,
                                                                          Math.max(baseContentHeight,
                                                                                   contentHeight))

                            anchors.fill: parent
                            spacing: Appearance.spacing.xSmall
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: root.showInputDevices && contentHeight > height
                            model: Volume.inputDevices

                            delegate: SettingsRow {
                                required property var modelData

                                width: ListView.view.width
                                iconName: Volume.nodeIconName(modelData)
                                title: Volume.nodeDisplayName(modelData)
                                interactive: !Volume.isDefaultInput(modelData)
                                highlighted: Volume.isDefaultInput(modelData)
                                onClicked: Volume.setDefaultInput(modelData)
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.spacing.small
                }
            }
        }
    }
}
