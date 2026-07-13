import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Clavis.Sysmon 1.0
import qs.Common
import qs.Components
import qs.Services

// Adapted from Caelestia Shell's dashboard user card (GPL-3.0).
Rectangle {
    id: root

    signal avatarEditRequested()

    readonly property string systemUser: SysmonPlugin.systemUser || "user"
    readonly property string hostName: SysmonPlugin.hostName || "host"
    readonly property string wmName: SysmonPlugin.wmName || "unknown"
    readonly property string distroName: SysmonPlugin.distroName || "Linux"
    readonly property string chassis: SysmonPlugin.chassis || "Computer"
    readonly property string uptime: SysmonPlugin.uptime || "0m"

    function distroLogo() {
        const id = String(SysmonPlugin.distroId || "").toLowerCase();
        const logos = {
            "arch": "󰣇",
            "archlinux": "󰣇",
            "endeavouros": "",
            "manjaro": "",
            "fedora": "",
            "ubuntu": "",
            "debian": "",
            "opensuse": "",
            "nixos": "",
            "gentoo": "",
            "void": ""
        };
        return logos[id] || "";
    }

    color: Appearance.colors.colLayer3
    radius: 24
    clip: true

    Item {
        id: avatarContainer

        anchors.left: parent.left
        anchors.leftMargin: 42
        anchors.verticalCenter: parent.verticalCenter
        width: 118
        height: 118

        Image {
            id: fallbackAvatar

            anchors.fill: parent
            source: Paths.fileUrl(Paths.defaultAvatar)
            sourceSize: Qt.size(236, 236)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        Image {
            id: profileAvatar

            anchors.fill: parent
            source: AvatarService.avatarUrl
            sourceSize: Qt.size(236, 236)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: false
        }

        Rectangle {
            id: avatarMask

            anchors.fill: parent
            radius: width / 2
            color: "black"
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: profileAvatar.status === Image.Ready ? profileAvatar : fallbackAvatar
            maskEnabled: true
            maskSource: avatarMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Appearance.applyAlpha(Appearance.colors.colScrim, avatarMouse.containsMouse ? 0.42 : 0)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 48
                height: 48
                radius: 12
                rotation: 45
                scale: avatarMouse.pressed ? 0.84 : avatarMouse.containsMouse ? 1 : 0.72
                opacity: avatarMouse.containsMouse ? 1 : 0
                color: Appearance.colors.colPrimary

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    rotation: -45
                    text: "person_edit"
                    iconSize: 24
                    fill: 1
                    color: Appearance.colors.colOnPrimary
                }
            }
        }

        MouseArea {
            id: avatarMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.avatarEditRequested()
        }
    }

    Rectangle {
        id: distroBadge

        anchors.left: avatarContainer.left
        anchors.top: avatarContainer.top
        anchors.leftMargin: -18
        anchors.topMargin: -8
        width: 50
        height: 50
        radius: 13
        rotation: 45
        color: Appearance.colors.colPrimaryContainer

        Text {
            anchors.centerIn: parent
            rotation: -45
            text: root.distroLogo()
            color: Appearance.colors.colOnPrimaryContainer
            font.family: Sizes.fontFamilyMono
            font.pixelSize: 25
            font.bold: true
        }
    }

    Rectangle {
        anchors.right: avatarContainer.right
        anchors.bottom: avatarContainer.bottom
        anchors.rightMargin: -8
        anchors.bottomMargin: -5
        width: 42
        height: 42
        radius: 21
        color: Appearance.colors.colTertiaryContainer

        MaterialSymbol {
            anchors.centerIn: parent
            text: "clock_arrow_up"
            iconSize: 22
            fill: 1
            color: Appearance.colors.colOnTertiaryContainer
        }
    }

    ColumnLayout {
        anchors.left: avatarContainer.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 24
        anchors.rightMargin: 18
        anchors.topMargin: 18
        anchors.bottomMargin: 17
        spacing: 5

        Text {
            Layout.fillWidth: true
            text: root.systemUser + " @ " + root.hostName
            color: Appearance.colors.colOnSurface
            font.family: Sizes.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.distroName + " · " + root.chassis
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Sizes.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.preferredWidth: Math.min(wmRow.implicitWidth + 20, parent.width)
            Layout.preferredHeight: 32
            radius: 16
            color: Appearance.colors.colSecondaryContainer

            Row {
                id: wmRow

                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "select_window"
                    iconSize: 18
                    color: Appearance.colors.colOnSecondaryContainer
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wmName
                    color: Appearance.colors.colOnSecondaryContainer
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            MaterialSymbol {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                text: "schedule"
                iconSize: 18
                color: Appearance.colors.colTertiary
            }

            Text {
                Layout.fillWidth: true
                text: "up " + root.uptime
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }
}
