import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string title: ""
    property string supportingText: ""
    property string iconName: "volume_up"
    property string iconSource: ""
    property real volume: 0
    property bool muted: false
    property bool available: true
    readonly property string mutedIconName: root.iconName === "mic" ? "mic_off" : "volume_off"

    signal volumeMoved(real volume)
    signal muteRequested()

    implicitHeight: contentLayout.implicitHeight
    opacity: root.available ? 1 : 0.45

    ColumnLayout {
        id: contentLayout

        width: parent.width
        spacing: Appearance.spacing.xSmall

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 48
            spacing: Appearance.spacing.small

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: Appearance.rounding.full
                color: root.muted
                    ? Appearance.colors.colSecondaryContainer
                    : Appearance.colors.colPrimaryContainer

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }

                Image {
                    id: applicationIcon

                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: root.iconSource
                    sourceSize: Qt.size(24, 24)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: root.iconSource.length > 0 && status === Image.Ready
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !applicationIcon.visible
                    text: root.muted ? root.mutedIconName : root.iconName
                    iconSize: 21
                    fill: root.muted ? 1 : 0
                    color: root.muted
                        ? Appearance.colors.colOnSecondaryContainer
                        : Appearance.colors.colOnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Appearance.colors.colOnLayer2
                    font.family: Sizes.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.supportingText.length > 0
                    text: root.supportingText
                    color: Appearance.colors.colOnLayer1
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            ToolButton {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                enabled: root.available
                hoverEnabled: true
                Accessible.name: root.muted ? "取消静音 " + root.title : "静音 " + root.title
                onClicked: root.muteRequested()

                background: Rectangle {
                    radius: Appearance.rounding.full
                    color: parent.down
                        ? Appearance.colors.colLayer2Active
                        : parent.hovered || root.muted
                            ? Appearance.colors.colLayer2Hover
                            : "transparent"
                }

                contentItem: MaterialSymbol {
                    text: root.muted ? root.mutedIconName : root.iconName
                    iconSize: 20
                    fill: root.muted ? 1 : 0
                    color: root.muted
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnLayer2
                }

                ToolTip.visible: hovered
                ToolTip.text: root.muted ? "取消静音" : "静音"
            }
        }

        QuickMaterialSlider {
            id: volumeControl

            Layout.fillWidth: true
            enabled: root.available
            materialSymbol: root.muted ? root.mutedIconName : root.iconName
            percentText: root.muted ? "静音" : Math.round(value * 100) + "%"
            tooltipContent: Math.round(value * 100) + "%"
            Accessible.name: root.title + "音量"

            Binding {
                target: volumeControl
                property: "value"
                value: Math.max(0, Math.min(1, root.volume))
                when: !volumeControl.pressed
            }

            onMoved: root.volumeMoved(value)
        }
    }
}
