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
    signal muteRequested

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
            font.family: Fonts.ui
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
            showTooltipOnHover: true
            tooltipContent: Math.round(value * 100) + "%"
            Accessible.name: qsTr("%1 volume").arg(root.title)

            Binding {
                target: volumeControl
                property: "value"
                value: Math.max(0, Math.min(1, root.volume))
                when: !volumeControl.pressed
            }

            onMoved: root.volumeMoved(value)
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            enabled: root.available
            selected: root.muted
            iconName: "volume_off"
            iconSize: 20
            iconFill: root.muted ? 1 : 0
            iconColor: Appearance.colors.colOnLayer2
            selectedIconColor: Appearance.colors.colOnSecondaryContainer
            selectedContainerColor: Appearance.colors.colSecondaryContainer
            selectedHoverStateLayerColor: Appearance.colors.colSecondaryContainerHover
            selectedPressedStateLayerColor: Appearance.colors.colSecondaryContainerActive
            accessibleName: root.muted ? qsTr("Unmute %1").arg(root.title) : qsTr("Mute %1").arg(root.title)
            tooltipText: root.muted ? qsTr("Unmute") : qsTr("Mute")
            hoverStateLayerColor: Appearance.colors.colLayer2Hover
            pressedStateLayerColor: Appearance.colors.colLayer2Active
            onClicked: root.muteRequested()
        }
    }
}
