import QtQuick
import QtQuick.Effects
import M3Shapes
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
        anchors.leftMargin: 34
        anchors.verticalCenter: parent.verticalCenter
        width: 126
        height: 126

        MaterialShape {
            id: avatarShape

            anchors.centerIn: parent
            implicitSize: parent.height
            shape: MaterialShape.Pill
            color: Appearance.colors.colLayer4
            layer.enabled: true
        }

        Image {
            id: fallbackAvatar

            anchors.fill: parent
            source: Paths.fileUrl(Paths.defaultAvatar)
            sourceSize: Qt.size(252, 252)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        Image {
            id: profileAvatar

            anchors.fill: parent
            source: AvatarService.avatarUrl
            sourceSize: Qt.size(252, 252)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: profileAvatar.status === Image.Ready ? profileAvatar : fallbackAvatar
            maskEnabled: true
            maskSource: avatarShape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: profileAvatar.status !== Image.Ready && fallbackAvatar.status !== Image.Ready
            text: "person_add"
            iconSize: 40
            fill: 1
            color: Appearance.colors.colOnSurfaceVariant
        }

        MaterialShape {
            anchors.centerIn: parent
            implicitSize: parent.height
            shape: MaterialShape.Pill
            color: Appearance.applyAlpha(Appearance.colors.colScrim, 0.42)
            opacity: avatarMouse.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                    easing.type: Appearance.animation.expressiveEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                }
            }
        }

        MaterialShape {
            anchors.centerIn: parent
            implicitSize: parent.height * 0.52
            shape: MaterialShape.Diamond
            color: Appearance.colors.colPrimary
            opacity: avatarMouse.containsMouse ? 1 : 0
            scale: avatarMouse.pressed ? 0.88 : avatarMouse.containsMouse ? 1 : 0.7

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "person_edit"
                iconSize: 25
                fill: 1
                color: Appearance.colors.colOnPrimary
            }
        }

        MouseArea {
            id: avatarMouse

            anchors.fill: parent
            containmentMask: QtObject {
                function contains(pt: point): bool {
                    return avatarShape.contains(pt);
                }
            }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.avatarEditRequested()
        }
    }

    MaterialShape {
        id: distroBadge

        x: 10
        y: 10
        implicitSize: 52
        shape: MaterialShape.Gem
        color: Appearance.colors.colPrimaryContainer

        Text {
            anchors.centerIn: parent
            text: root.distroLogo()
            color: Appearance.colors.colOnPrimaryContainer
            font.family: Sizes.fontFamilyMono
            font.pixelSize: 25
            font.bold: true
        }
    }

    MaterialShape {
        id: uptimeShape

        anchors.left: avatarContainer.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: -23
        anchors.bottomMargin: 1
        implicitSize: 46
        shape: MaterialShape.ClamShell
        color: Appearance.colors.colTertiaryContainer

        MaterialSymbol {
            anchors.centerIn: parent
            text: "clock_arrow_up"
            iconSize: 22
            fill: 1
            color: Appearance.colors.colOnTertiaryContainer
        }
    }

    Rectangle {
        id: bubble1

        anchors.left: avatarContainer.right
        anchors.top: bubble2.bottom
        anchors.leftMargin: 5
        anchors.topMargin: -3
        width: 10
        height: 10
        radius: 5
        color: Appearance.colors.colSecondaryContainer
    }

    Rectangle {
        id: bubble2

        anchors.left: bubble1.right
        anchors.verticalCenter: wmContainer.bottom
        anchors.leftMargin: 4
        width: 15
        height: 15
        radius: 8
        color: Appearance.colors.colSecondaryContainer
    }

    Rectangle {
        id: wmContainer

        anchors.left: bubble2.left
        anchors.leftMargin: -8
        y: 12
        width: Math.min(152, Math.max(94, wmRow.implicitWidth + 20))
        height: 34
        radius: 17
        color: Appearance.colors.colSecondaryContainer

        Row {
            id: wmRow

            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "select_window"
                iconSize: 18
                color: Appearance.colors.colOnSecondaryContainer
            }

            Text {
                id: wmText

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, wmContainer.width - 44)
                text: root.wmName + "..."
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Sizes.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                font.italic: true
                elide: Text.ElideRight
            }
        }
    }

    Text {
        id: userLabel

        anchors.left: wmContainer.left
        anchors.right: parent.right
        anchors.top: wmContainer.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 16
        anchors.topMargin: 10
        text: root.systemUser + " @ " + root.hostName
        color: Appearance.colors.colOnSurface
        font.family: Sizes.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        anchors.left: userLabel.left
        anchors.right: parent.right
        anchors.top: userLabel.bottom
        anchors.rightMargin: 16
        anchors.topMargin: 3
        text: root.distroName + " · " + root.chassis
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Sizes.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    Text {
        anchors.left: uptimeShape.right
        anchors.right: parent.right
        anchors.verticalCenter: uptimeShape.verticalCenter
        anchors.leftMargin: 5
        anchors.rightMargin: 16
        text: "up " + root.uptime
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Sizes.fontFamilyMono
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
