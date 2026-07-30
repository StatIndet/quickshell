import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: 82
    radius: Appearance.rounding.large
    color: Appearance.colors.colLayer1

    readonly property var profiles: [
        {
            "id": "power-saver",
            "title": qsTr("节能"),
            "subtitle": "60 Hz",
            "icon": "battery_saver"
        },
        {
            "id": "balanced",
            "title": qsTr("平衡"),
            "subtitle": "120 Hz",
            "icon": "balance"
        },
        {
            "id": "performance",
            "title": qsTr("性能"),
            "subtitle": "120 Hz",
            "icon": "speed"
        }
    ]

    RowLayout {
        anchors.fill: parent
        anchors.margins: 7
        spacing: 6

        Repeater {
            model: root.profiles

            Rectangle {
                id: profileButton

                required property var modelData
                readonly property bool selected:
                    PowerProfileService.profile === modelData.id
                readonly property bool hovered: mouseArea.containsMouse

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                enabled: PowerProfileService.available
                    && !PowerProfileService.busy
                opacity: enabled ? 1 : 0.5
                color: selected
                    ? Appearance.colors.colPrimary
                    : hovered
                        ? Appearance.colors.colLayer2Hover
                        : Appearance.colors.colLayer2

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: profileButton.modelData.icon
                        iconSize: 22
                        fill: profileButton.selected ? 1 : 0
                        color: profileButton.selected
                            ? Appearance.colors.colOnPrimary
                            : Appearance.colors.colOnLayer2
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: profileButton.modelData.title
                        color: profileButton.selected
                            ? Appearance.colors.colOnPrimary
                            : Appearance.colors.colOnLayer2
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.typeLabelMedium
                        font.weight: 600
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: profileButton.modelData.subtitle
                        color: profileButton.selected
                            ? Appearance.transparentize(
                                Appearance.colors.colOnPrimary, 0.25)
                            : Appearance.colors.colOnLayer2
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: Sizes.typeLabelSmall
                    }
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: profileButton.enabled
                        ? Qt.PointingHandCursor
                        : Qt.ArrowCursor
                    onClicked:
                        PowerProfileService.setProfile(
                            profileButton.modelData.id)
                }

                PopupToolTip {
                    extraVisibleCondition: mouseArea.containsMouse
                    text: profileButton.modelData.title
                        + qsTr("模式")
                        + (profileButton.modelData.id === "power-saver"
                            ? qsTr("\n自动将内屏切换为 60 Hz")
                            : qsTr("\n自动将内屏恢复为 120 Hz"))
                }
            }
        }
    }
}
