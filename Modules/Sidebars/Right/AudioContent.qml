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

    title: "声音"
    icon: "volume_up"
    showBackButton: true
    backAction: () => WidgetState.qsView = "settings"

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "audio"
    property bool outputDevicesExpanded: false
    readonly property bool showOutputDevices: root.outputDevicesExpanded
    readonly property string stateMessage: {
        if (Volume.lastError.length > 0)
            return Volume.lastError;
        if (!Volume.ready)
            return "正在连接 PipeWire 音频服务";
        if (Volume.outputDevices.length === 0 && !Volume.outputAvailable)
            return "未检测到可用的声音输出设备";
        return "";
    }

    onIsActiveChanged: {
        if (!isActive)
            outputDevicesExpanded = false;
    }

    headerTools: ToolButton {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        hoverEnabled: true
        Accessible.name: "打开高级声音设置"
        onClicked: Volume.openMixer()

        background: Rectangle {
            radius: Appearance.rounding.full
            color: parent.down
                ? Appearance.colors.colLayer2Active
                : parent.hovered ? Appearance.colors.colLayer2Hover : "transparent"
        }

        contentItem: MaterialSymbol {
            text: "open_in_new"
            iconSize: 20
            color: Appearance.colors.colOnLayer2
        }

        StyledToolTip { text: "高级声音设置" }
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

            Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
            Behavior on opacity { ElementMoveAnimation {} }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.stateMessage.length > 0
            tone: Volume.lastError.length > 0 ? "error" : "info"
            iconName: !Volume.ready
                ? "hourglass_top"
                : Volume.lastError.length > 0 ? "error" : "info"
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
                    title: "输出"

                    VolumeSlider {
                        Layout.fillWidth: true
                        visible: Volume.outputAvailable
                        title: Volume.sinkName || "默认输出"
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
                            text: "输出设备"
                            color: Appearance.colors.colOnLayer1
                            font.family: Sizes.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        ToolButton {
                            id: outputDevicesButton

                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            hoverEnabled: true
                            Accessible.name: root.outputDevicesExpanded ? "收起输出设备" : "展开输出设备"
                            onClicked: root.outputDevicesExpanded = !root.outputDevicesExpanded

                            background: Rectangle {
                                radius: Appearance.rounding.full
                                color: root.outputDevicesExpanded
                                    ? Appearance.colors.colSecondaryContainer
                                    : outputDevicesButton.down
                                        ? Appearance.colors.colLayer2Active
                                        : outputDevicesButton.hovered ? Appearance.colors.colLayer2Hover : "transparent"
                            }

                            contentItem: MaterialSymbol {
                                text: "expand_more"
                                iconSize: 22
                                color: root.outputDevicesExpanded
                                    ? Appearance.colors.colOnSecondaryContainer
                                    : Appearance.colors.colOnLayer2
                                rotation: root.outputDevicesExpanded ? 180 : 0

                                Behavior on rotation { ElementMoveAnimation {} }
                            }

                            StyledToolTip {
                                text: root.outputDevicesExpanded ? "收起输出设备" : "展开输出设备"
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.showOutputDevices
                            ? outputDeviceList.targetHeight : 0
                        opacity: root.showOutputDevices ? 1 : 0
                        clip: true

                        Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
                        Behavior on opacity { ElementMoveAnimation {} }

                        StyledListView {
                            id: outputDeviceList

                            readonly property real baseContentHeight: count * 56
                                + Math.max(0, count - 1) * spacing
                            readonly property real targetHeight: Math.min(
                                Sizes.sidebarScrollableListMaxHeight,
                                Math.max(baseContentHeight, contentHeight)
                            )

                            anchors.fill: parent
                            spacing: Appearance.spacing.xSmall
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: root.showOutputDevices && contentHeight > height
                            smoothWheelEnabled: interactive
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
                    title: "应用音量"

                    StyledListView {
                        id: playbackStreamList

                        readonly property real baseContentHeight: count * 48
                            + Math.max(0, count - 1) * spacing

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(
                            Sizes.sidebarScrollableListMaxHeight,
                            Math.max(baseContentHeight, contentHeight)
                        )
                        visible: count > 0
                        spacing: Appearance.spacing.xSmall
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        smoothWheelEnabled: interactive
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

                        Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: Volume.playbackStreams.length === 0
                        iconName: "music_off"
                        title: "没有活动的应用音频"
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
