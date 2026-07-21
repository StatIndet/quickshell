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

    title: "麦克风"
    icon: "mic"
    showBackButton: true
    backAction: () => WidgetState.qsView = "settings"

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "microphone"
    property bool inputDevicesExpanded: false
    readonly property bool showInputDevices: root.inputDevicesExpanded
    readonly property string stateMessage: {
        if (Volume.lastError.length > 0)
            return Volume.lastError;
        if (!Volume.ready)
            return "正在连接 PipeWire 音频服务";
        if (Volume.inputDevices.length === 0 && !Volume.inputAvailable)
            return "未检测到可用的麦克风设备";
        return "";
    }

    onIsActiveChanged: {
        if (!isActive)
            inputDevicesExpanded = false;
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
            contentHeight: microphoneContent.implicitHeight

            ColumnLayout {
                id: microphoneContent

                width: parent.width - Appearance.spacing.small
                spacing: Appearance.spacing.small

                SettingsSection {
                    Layout.fillWidth: true
                    visible: Volume.ready && (Volume.inputDevices.length > 0 || Volume.inputAvailable)
                    title: "输入"

                    VolumeSlider {
                        Layout.fillWidth: true
                        visible: Volume.inputAvailable
                        title: Volume.sourceName || "默认输入"
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
                            text: "输入设备"
                            color: Appearance.colors.colOnLayer1
                            font.family: Sizes.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        ToolButton {
                            id: inputDevicesButton

                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            hoverEnabled: true
                            Accessible.name: root.inputDevicesExpanded ? "收起输入设备" : "展开输入设备"
                            onClicked: root.inputDevicesExpanded = !root.inputDevicesExpanded

                            background: Rectangle {
                                radius: Appearance.rounding.full
                                color: root.inputDevicesExpanded
                                    ? Appearance.colors.colSecondaryContainer
                                    : inputDevicesButton.down
                                        ? Appearance.colors.colLayer2Active
                                        : inputDevicesButton.hovered ? Appearance.colors.colLayer2Hover : "transparent"
                            }

                            contentItem: MaterialSymbol {
                                text: "expand_more"
                                iconSize: 22
                                color: root.inputDevicesExpanded
                                    ? Appearance.colors.colOnSecondaryContainer
                                    : Appearance.colors.colOnLayer2
                                rotation: root.inputDevicesExpanded ? 180 : 0

                                Behavior on rotation { ElementMoveAnimation {} }
                            }

                            StyledToolTip {
                                text: root.inputDevicesExpanded ? "收起输入设备" : "展开输入设备"
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.showInputDevices
                            ? inputDeviceList.targetHeight : 0
                        opacity: root.showInputDevices ? 1 : 0
                        clip: true

                        Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
                        Behavior on opacity { ElementMoveAnimation {} }

                        StyledListView {
                            id: inputDeviceList

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
                            interactive: root.showInputDevices && contentHeight > height
                            smoothWheelEnabled: interactive
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
