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

    title: qsTr("Sound")
    icon: "volume_up"
    showBackButton: true
    backAction: () => WidgetState.quickSettingsView = "settings"

    property bool foreground: false
    property bool isActive: foreground && WidgetState.quickSettingsView === "audio"
    property bool outputDevicesExpanded: false
    readonly property bool showOutputDevices: root.outputDevicesExpanded
    readonly property string stateMessage: {
        if (Volume.lastError.length > 0)
            return Volume.lastError;
        if (!Volume.ready)
            return qsTr("Connecting to the PipeWire audio service");
        if (Volume.outputDevices.length === 0 && !Volume.outputAvailable)
            return qsTr("No audio output devices detected");
        return "";
    }

    onIsActiveChanged: {
        if (!isActive)
            outputDevicesExpanded = false;
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
            contentHeight: audioContent.implicitHeight

            ColumnLayout {
                id: audioContent

                width: parent.width - Appearance.spacing.small
                spacing: Appearance.spacing.small

                SettingsSection {
                    Layout.fillWidth: true
                    visible: Volume.ready && (Volume.outputDevices.length > 0 || Volume.outputAvailable)
                    title: qsTr("Output")

                    VolumeSlider {
                        Layout.fillWidth: true
                        visible: Volume.outputAvailable
                        title: Volume.sinkName || qsTr("Default output")
                        iconName: Volume.nodeIconName(Volume.sink)
                        volume: Volume.sinkVolume
                        muted: Volume.sinkMuted
                        available: Volume.outputAvailable
                        showMuteButton: false
                        onVolumeMoved: value => Volume.setSinkVolume(value)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 40
                        visible: Volume.outputDevices.length > 1 || !Volume.outputAvailable

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Output devices")
                            color: Appearance.colors.colOnLayer1
                            font.family: Fonts.ui
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        IconButton {
                            selected: root.outputDevicesExpanded
                            iconName: "expand_more"
                            iconSize: 22
                            iconColor: Appearance.colors.colOnLayer2
                            selectedIconColor: Appearance.colors.colOnSecondaryContainer
                            selectedContainerColor: Appearance.colors.colSecondaryContainer
                            selectedHoverStateLayerColor: Appearance.colors.colSecondaryContainerHover
                            selectedPressedStateLayerColor: Appearance.colors.colSecondaryContainerActive
                            iconRotation: root.outputDevicesExpanded ? 180 : 0
                            accessibleName: root.outputDevicesExpanded ? qsTr("Collapse output devices") :
                                                                         qsTr("Expand output devices")
                            hoverStateLayerColor: Appearance.colors.colLayer2Hover
                            pressedStateLayerColor: Appearance.colors.colLayer2Active
                            onClicked: root.outputDevicesExpanded = !root.outputDevicesExpanded

                            Behavior on iconRotation {
                                ElementMoveAnimation {}
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.showOutputDevices ? outputDeviceList.targetHeight : 0
                        opacity: root.showOutputDevices ? 1 : 0
                        clip: true

                        Behavior on Layout.preferredHeight {
                            ElementMoveAnimation {}
                        }
                        Behavior on opacity {
                            ElementMoveAnimation {}
                        }

                        StyledListView {
                            id: outputDeviceList

                            readonly property real baseContentHeight: count * 56 + Math.max(0, count - 1)
                                                                      * spacing
                            readonly property real targetHeight: Math.min(Sizes.sidebarScrollableListMaxHeight,
                                                                          Math.max(baseContentHeight,
                                                                                   contentHeight))

                            anchors.fill: parent
                            spacing: Appearance.spacing.xSmall
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: root.showOutputDevices && contentHeight > height
                            model: Volume.outputDevices

                            delegate: SettingsRow {
                                required property var modelData

                                width: ListView.view.width
                                iconName: Volume.nodeIconName(modelData)
                                title: Volume.nodeDisplayName(modelData)
                                interactive: !Volume.isDefaultOutput(modelData)
                                highlighted: Volume.isDefaultOutput(modelData)
                                onClicked: Volume.setDefaultOutput(modelData)
                            }
                        }
                    }
                }

                SettingsSection {
                    Layout.fillWidth: true
                    visible: Volume.ready && Volume.outputAvailable
                    title: qsTr("Application volume")

                    StyledListView {
                        id: playbackStreamList

                        readonly property real baseContentHeight: count * 48 + Math.max(0, count - 1)
                                                                  * spacing

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(Sizes.sidebarScrollableListMaxHeight, Math.max(
                                                             baseContentHeight, contentHeight))
                        visible: count > 0
                        spacing: Appearance.spacing.xSmall
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        model: Volume.playbackStreams

                        delegate: ApplicationVolumeRow {
                            required property var modelData

                            width: ListView.view.width
                            title: Volume.applicationDisplayName(modelData)
                            iconSource: Volume.applicationIconSource(modelData)
                            volume: Volume.nodeVolume(modelData)
                            muted: Volume.nodeMuted(modelData)
                            onVolumeMoved: value => Volume.setNodeVolume(modelData, value)
                            onMuteRequested: Volume.toggleNodeMute(modelData)
                        }

                        Behavior on Layout.preferredHeight {
                            ElementMoveAnimation {}
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: Volume.playbackStreams.length === 0
                        iconName: "music_off"
                        title: qsTr("No active application audio")
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
