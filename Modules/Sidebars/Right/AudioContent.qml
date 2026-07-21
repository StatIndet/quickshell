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
    readonly property string stateMessage: {
        if (Volume.lastError.length > 0)
            return Volume.lastError;
        if (!Volume.ready)
            return "正在连接 PipeWire 音频服务";
        if (!Volume.available)
            return "未检测到可用的音频设备";
        return "";
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

        ToolTip.visible: hovered
        ToolTip.text: "高级声音设置"
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
                    supportingText: Volume.outputAvailable
                        ? "当前通过“" + Volume.sinkName + "”播放声音"
                        : "请选择声音输出设备"

                    VolumeSlider {
                        Layout.fillWidth: true
                        visible: Volume.outputAvailable
                        title: Volume.sinkName || "默认输出"
                        supportingText: Volume.sinkMuted ? "已静音" : "主音量"
                        iconName: Volume.nodeIconName(Volume.sink)
                        volume: Volume.sinkVolume
                        muted: Volume.sinkMuted
                        available: Volume.outputAvailable
                        onVolumeMoved: value => Volume.setSinkVolume(value)
                        onMuteRequested: Volume.toggleSinkMute()
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: Volume.outputDevices.length > 1 || !Volume.outputAvailable
                        text: "选择输出设备"
                        color: Appearance.colors.colOnLayer1
                        font.family: Sizes.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Repeater {
                        model: Volume.outputDevices.length > 1 || !Volume.outputAvailable
                            ? Volume.outputDevices
                            : []

                        SettingsRow {
                            required property var modelData

                            Layout.fillWidth: true
                            iconName: Volume.nodeIconName(modelData)
                            title: Volume.nodeDisplayName(modelData)
                            supportingText: Volume.nodeSupportingText(modelData)
                            interactive: !Volume.isDefaultOutput(modelData)
                            highlighted: Volume.isDefaultOutput(modelData)
                            onClicked: Volume.setDefaultOutput(modelData)

                            trailing: MaterialSymbol {
                                visible: Volume.isDefaultOutput(modelData)
                                text: "check_circle"
                                iconSize: 21
                                fill: 1
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }

                SettingsSection {
                    Layout.fillWidth: true
                    visible: Volume.ready && (Volume.inputDevices.length > 0 || Volume.inputAvailable)
                    title: "输入"
                    supportingText: Volume.inputAvailable
                        ? "当前使用“" + Volume.sourceName + "”采集声音"
                        : "请选择声音输入设备"

                    VolumeSlider {
                        Layout.fillWidth: true
                        visible: Volume.inputAvailable
                        title: Volume.sourceName || "默认输入"
                        supportingText: Volume.sourceMuted ? "已静音" : "输入音量"
                        iconName: "mic"
                        volume: Volume.sourceVolume
                        muted: Volume.sourceMuted
                        available: Volume.inputAvailable
                        onVolumeMoved: value => Volume.setSourceVolume(value)
                        onMuteRequested: Volume.toggleSourceMute()
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: Volume.inputDevices.length > 1 || !Volume.inputAvailable
                        text: "选择输入设备"
                        color: Appearance.colors.colOnLayer1
                        font.family: Sizes.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Repeater {
                        model: Volume.inputDevices.length > 1 || !Volume.inputAvailable
                            ? Volume.inputDevices
                            : []

                        SettingsRow {
                            required property var modelData

                            Layout.fillWidth: true
                            iconName: Volume.nodeIconName(modelData)
                            title: Volume.nodeDisplayName(modelData)
                            supportingText: Volume.nodeSupportingText(modelData)
                            interactive: !Volume.isDefaultInput(modelData)
                            highlighted: Volume.isDefaultInput(modelData)
                            onClicked: Volume.setDefaultInput(modelData)

                            trailing: MaterialSymbol {
                                visible: Volume.isDefaultInput(modelData)
                                text: "check_circle"
                                iconSize: 21
                                fill: 1
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }

                SettingsSection {
                    Layout.fillWidth: true
                    visible: Volume.ready && Volume.outputAvailable
                    title: "应用音量"
                    supportingText: Volume.playbackStreams.length > 0
                        ? "分别调整正在向当前输出设备播放声音的应用"
                        : "当前没有应用正在播放声音"

                    Repeater {
                        model: Volume.playbackStreams

                        VolumeSlider {
                            required property var modelData

                            Layout.fillWidth: true
                            title: Volume.nodeDisplayName(modelData)
                            supportingText: Volume.nodeSupportingText(modelData)
                            iconName: "music_note"
                            iconSource: Volume.applicationIconSource(modelData)
                            volume: Volume.nodeVolume(modelData)
                            muted: Volume.nodeMuted(modelData)
                            onVolumeMoved: value => Volume.setNodeVolume(modelData, value)
                            onMuteRequested: Volume.toggleNodeMute(modelData)
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: Volume.playbackStreams.length === 0
                        iconName: "music_off"
                        title: "没有活动的应用音频"
                        supportingText: "开始播放媒体后，应用音量会自动出现在这里"
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
