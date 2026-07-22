import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Clavis.Sysmon 1.0
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    property string screenName: ""

    readonly property real coverAspectRatio: 5 / 2
    readonly property int coverHeight: Math.round(width / coverAspectRatio)
    readonly property int profileAreaHeight: 112
    readonly property int avatarSize: 96
    readonly property int avatarBorderWidth: 4
    readonly property real avatarCoverFraction: 0.42
    readonly property color profileSurfaceColor: Appearance.m3colors.m3surfaceContainerHigh
    readonly property int wallpaperRevision: WallpaperService.revision
    readonly property string wallpaperPath: wallpaperRevision >= 0
        ? (WallpaperService.wallpaperForScreen(screenName)
            || WallpaperService.currentWallpaper
            || PersonalizationConfig.wallpaperPath)
        : ""
    readonly property bool colorWallpaper: WallpaperService.isColorSource(wallpaperPath)
    readonly property string wallpaperUrl: wallpaperPath !== "" && !colorWallpaper
        ? Paths.fileUrl(wallpaperPath) + "?revision=" + wallpaperRevision
        : ""
    readonly property string accountName: SysmonPlugin.systemUser || "user"
    readonly property string hostName: SysmonPlugin.hostName || "host"
    readonly property string accountIdentity: accountName + "@" + hostName
    readonly property string distroId: SysmonPlugin.distroId || "linux"
    readonly property string operatingSystem: SysmonPlugin.distroName || "Linux"
    readonly property string uptime: SysmonPlugin.uptime || "0m"

    function distroLogo() {
        const id = String(root.distroId).toLowerCase();
        const logos = {
            "arch": "󰣇",
            "archlinux": "󰣇",
            "cachyos": "󰣇",
            "endeavouros": "",
            "manjaro": "",
            "fedora": "",
            "ubuntu": "",
            "debian": "",
            "opensuse": "",
            "nixos": "",
            "gentoo": "",
            "void": "",
            "alpine": ""
        };
        return logos[id] || "";
    }

    function openControlCenter() {
        WidgetState.leftSidebarOpen = false;
        Quickshell.execDetached([
            "qs",
            "--path",
            Paths.shellDir + "/controlcenter.qml"
        ]);
    }

    implicitHeight: coverHeight + profileAreaHeight
    radius: Appearance.rounding.extraLarge
    color: profileSurfaceColor
    antialiasing: true

    Rectangle {
        id: cover

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.coverHeight
        radius: Appearance.rounding.extraLarge
        color: root.colorWallpaper ? root.wallpaperPath : Appearance.colors.colPrimaryContainer
        antialiasing: true

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: cover.width
                height: cover.height
                radius: cover.radius
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: wallpaperImage.status !== Image.Ready && !root.colorWallpaper
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Appearance.colors.colPrimaryContainer
                }

                GradientStop {
                    position: 1
                    color: Appearance.colors.colTertiaryContainer
                }
            }
        }

        Image {
            id: wallpaperImage

            anchors.fill: parent
            source: root.wallpaperUrl
            sourceSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            asynchronous: true
            cache: false
            smooth: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.08)
        }
    }

    Item {
        id: profileArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: cover.bottom
        height: root.profileAreaHeight
    }

    Rectangle {
        id: avatarFrame

        readonly property bool hovered: avatarButton.hovered

        x: Appearance.spacing.panelPadding
        y: root.coverHeight - root.avatarSize * root.avatarCoverFraction
        z: 2
        width: root.avatarSize
        height: root.avatarSize
        radius: Appearance.rounding.full
        color: root.profileSurfaceColor
        border.width: avatarButton.activeFocus ? 2 : 0
        border.color: Appearance.colors.colPrimary
        antialiasing: true

        Rectangle {
            id: avatarSurface

            anchors.fill: parent
            anchors.margins: root.avatarBorderWidth
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimaryContainer
            antialiasing: true

            Rectangle {
                id: avatarMask

                anchors.fill: parent
                radius: Appearance.rounding.full
                visible: false
                layer.enabled: true
            }

            Image {
                id: fallbackAvatar

                anchors.fill: parent
                source: Paths.fileUrl(Paths.defaultAvatar)
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: false
            }

            Image {
                id: profileAvatar

                anchors.fill: parent
                source: AvatarService.avatarUrl
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: profileAvatar.status === Image.Ready ? profileAvatar : fallbackAvatar
                maskSource: avatarMask
                visible: profileAvatar.status === Image.Ready || fallbackAvatar.status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: profileAvatar.status !== Image.Ready && fallbackAvatar.status !== Image.Ready
                text: "account_circle"
                color: Appearance.colors.colOnPrimaryContainer
                font.family: "Material Symbols Rounded"
                font.pixelSize: 36
            }

            Rectangle {
                id: avatarScrim

                anchors.fill: parent
                radius: Appearance.rounding.full
                color: Appearance.applyAlpha(Appearance.m3colors.m3scrim, 0.7)
                opacity: avatarFrame.hovered || avatarButton.activeFocus ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutSine
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    text: "edit"
                    iconSize: 28
                    fill: avatarFrame.hovered || avatarButton.activeFocus ? 1 : 0
                    color: Appearance.colors.colOnImage
                    opacity: avatarScrim.opacity
                    scale: avatarFrame.hovered || avatarButton.activeFocus ? 1 : 0.82

                    Behavior on scale {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutSine
                        }
                    }
                }
            }
        }

        Button {
            id: avatarButton

            anchors.fill: parent
            z: 3
            padding: 0
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            Accessible.name: "打开设置中心"

            onClicked: root.openControlCenter()

            background: null
            contentItem: Item {}

            HoverHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                cursorShape: Qt.PointingHandCursor
            }

            StyledToolTip {
                text: "打开设置中心"
                alternativeVisibleCondition: avatarButton.activeFocus
            }
        }
    }

    Column {
        id: accountDetails

        anchors.left: avatarFrame.right
        anchors.leftMargin: Appearance.spacing.panelPadding
        anchors.right: profileArea.right
        anchors.rightMargin: Appearance.spacing.panelPadding
        anchors.verticalCenter: profileArea.verticalCenter
        spacing: Appearance.spacing.small

        Text {
            width: parent.width
            text: root.accountIdentity
            color: Appearance.colors.colOnSurface
            font.family: Sizes.fontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        RowLayout {
            width: parent.width
            height: 24
            spacing: Appearance.spacing.small

            Text {
                id: distroIcon

                Layout.alignment: Qt.AlignVCenter
                text: root.distroLogo()
                color: Appearance.colors.colPrimary
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 18
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: accountDetails.width * 0.44
                text: root.operatingSystem
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Sizes.fontFamily
                font.pixelSize: 15
                elide: Text.ElideRight
            }

            Text {
                id: uptimeIcon

                Layout.alignment: Qt.AlignVCenter
                text: "schedule"
                color: Appearance.colors.colOnSurfaceVariant
                font.family: "Material Symbols Rounded"
                font.pixelSize: 17
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                text: "Up · " + root.uptime
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 14
                elide: Text.ElideRight
            }
        }
    }

}
