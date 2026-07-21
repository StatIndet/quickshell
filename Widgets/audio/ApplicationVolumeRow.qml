import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string title: ""
    property string iconSource: ""
    property real volume: 0
    property bool muted: false
    property bool available: true

    signal volumeMoved(real volume)
    signal muteRequested()

    implicitHeight: 48
    opacity: root.available ? 1 : 0.45

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.small

        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: applicationIcon

                anchors.centerIn: parent
                width: 28
                height: 28
                source: root.iconSource
                sourceSize: Qt.size(28, 28)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: root.iconSource.length > 0 && status === Image.Ready
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: !applicationIcon.visible
                text: "apps"
                iconSize: 23
                color: Appearance.colors.colOnLayer1
            }
        }

        Text {
            Layout.minimumWidth: 52
            Layout.preferredWidth: Math.min(72, Math.max(52, implicitWidth))
            Layout.maximumWidth: 72
            Layout.alignment: Qt.AlignVCenter
            text: root.title
            color: Appearance.colors.colOnLayer2
            font.family: Sizes.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
            elide: Text.ElideRight

            StyledToolTip {
                text: root.title
                extraVisibleCondition: parent.truncated && parentHover.hovered
            }

            HoverHandler {
                id: parentHover
            }
        }

        MaterialSplitSlider {
            id: volumeControl

            Layout.fillWidth: true
            Layout.minimumWidth: 156
            Layout.alignment: Qt.AlignVCenter
            enabled: root.available
            configuration: MaterialSplitSlider.Configuration.XS
            stopIndicatorValues: []
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

        ToolButton {
            id: muteButton

            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            enabled: root.available
            hoverEnabled: true
            Accessible.name: root.muted ? "取消静音 " + root.title : "静音 " + root.title
            onClicked: root.muteRequested()

            background: Rectangle {
                radius: Appearance.rounding.full
                color: root.muted
                    ? Appearance.colors.colSecondaryContainer
                    : muteButton.down
                        ? Appearance.colors.colLayer2Active
                        : muteButton.hovered ? Appearance.colors.colLayer2Hover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }
            }

            contentItem: MaterialSymbol {
                text: "volume_off"
                iconSize: 20
                fill: root.muted ? 1 : 0
                color: root.muted
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnLayer2
            }

            StyledToolTip {
                text: root.muted ? "取消静音" : "静音"
                extraVisibleCondition: muteButton.hovered
            }
        }
    }
}
