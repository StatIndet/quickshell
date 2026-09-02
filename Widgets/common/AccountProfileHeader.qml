import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root

    property string wallpaperPath: ""
    property bool colorWallpaper: false
    property string avatarUrl: ""
    property string fallbackAvatarUrl: ""
    property string accountIdentity: ""
    property string distroId: "linux"
    property string distroName: "Linux"
    property string uptimeText: ""
    property bool showNetworkStatus: false
    property string networkIconName: "wifi_off"
    property string networkStatusText: ""
    property string networkStatusDetail: ""
    property string avatarActionLabel: qsTr("更改头像")
    property real coverHeight: Math.max(150, Math.min(220, width * 0.23))
    property real profileAreaHeight: 120
    property real avatarSize: 104
    property real avatarCoverFraction: 0.42

    signal avatarActivated()
    signal networkActivated()

    property color surfaceColor: Appearance.m3colors.m3surfaceContainerHigh
    readonly property color profileSurfaceColor: surfaceColor
    readonly property string wallpaperUrl: wallpaperPath !== "" && !colorWallpaper
        ? Paths.fileUrl(wallpaperPath) : ""

    function distroLogo() {
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
        return logos[String(root.distroId || "").toLowerCase()] || "";
    }

    implicitHeight: coverHeight + profileAreaHeight
    radius: Appearance.rounding.extraLarge
    color: profileSurfaceColor
    antialiasing: true
    clip: true

    Rectangle {
        id: cover

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.coverHeight
        topLeftRadius: root.radius
        topRightRadius: root.radius
        color: root.colorWallpaper
            ? root.wallpaperPath : Appearance.colors.colPrimaryContainer

        gradient: root.wallpaperUrl === "" && !root.colorWallpaper
            ? fallbackGradient : null

        Gradient {
            id: fallbackGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Appearance.colors.colPrimaryContainer }
            GradientStop { position: 1; color: Appearance.colors.colTertiaryContainer }
        }

        Image {
            id: wallpaperImage

            anchors.fill: parent
            source: root.wallpaperUrl
            sourceSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            visible: false
        }

        Rectangle {
            id: coverMask

            anchors.fill: parent
            topLeftRadius: root.radius
            topRightRadius: root.radius
            color: "black"
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaperImage
            maskEnabled: true
            maskSource: coverMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
            opacity: wallpaperImage.status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve:
                        Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            topLeftRadius: root.radius
            topRightRadius: root.radius
            color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.08)
        }
    }

    Rectangle {
        id: avatarFrame

        x: Appearance.spacing.panelPadding
        y: root.coverHeight - root.avatarSize * root.avatarCoverFraction
        z: 2
        width: root.avatarSize
        height: root.avatarSize
        radius: Appearance.rounding.full
        color: "transparent"

        Rectangle {
            id: avatarSurface

            anchors.fill: parent
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimaryContainer

            Image {
                id: fallbackAvatar
                anchors.fill: parent
                source: root.fallbackAvatarUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            Image {
                id: profileAvatar
                anchors.fill: parent
                source: root.avatarUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: false
            }

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: Appearance.rounding.full
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: profileAvatar.status === Image.Ready
                    ? profileAvatar : fallbackAvatar
                maskEnabled: true
                maskSource: avatarMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
                visible: profileAvatar.status === Image.Ready
                    || fallbackAvatar.status === Image.Ready
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: profileAvatar.status !== Image.Ready
                    && fallbackAvatar.status !== Image.Ready
                text: "account_circle"
                iconSize: 42
                color: Appearance.colors.colOnPrimaryContainer
            }

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.full
                color: Appearance.applyAlpha(Appearance.m3colors.m3scrim, 0.68)
                opacity: avatarButton.pointerHovered ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 160 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "edit"
                    iconSize: 28
                    fill: 1
                    color: Appearance.colors.colOnImage
                }
            }
        }

        RippleButton {
            id: avatarButton

            anchors.fill: parent
            padding: 0
            focusPolicy: Qt.StrongFocus
            buttonRadius: Appearance.rounding.full
            containerColor: "transparent"
            stateLayerEnabled: false
            rippleColor: Appearance.colors.colOnImage
            Accessible.name: root.avatarActionLabel
            onClicked: {
                focus = false
                root.avatarActivated()
            }
            contentItem: Item {}
        }
    }

    RowLayout {
        anchors.left: avatarFrame.right
        anchors.leftMargin: Appearance.spacing.large
        anchors.right: parent.right
        anchors.rightMargin: Appearance.spacing.large
        anchors.top: cover.bottom
        height: root.profileAreaHeight
        spacing: Appearance.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Appearance.spacing.xSmall

            Text {
                Layout.fillWidth: true
                text: root.accountIdentity
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: Typography.titleLarge.pixelSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Text {
                    text: root.distroLogo()
                    color: Appearance.colors.colPrimary
                    font.family: Fonts.numeric
                    font.pixelSize: 18
                }

                Text {
                    Layout.maximumWidth: parent.width * 0.44
                    text: root.distroName
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: Typography.bodyMedium.pixelSize
                    elide: Text.ElideRight
                }

                MaterialSymbol {
                    text: "schedule"
                    iconSize: 18
                    color: Appearance.colors.colOnSurfaceVariant
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("已运行 %1").arg(root.uptimeText)
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: Typography.bodyMedium.pixelSize
                    elide: Text.ElideRight
                }
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            visible: root.showNetworkStatus
            implicitWidth: networkContent.implicitWidth + Appearance.spacing.large * 2
            implicitHeight: 48
            buttonRadius: Appearance.rounding.full
            containerColor: "transparent"
            stateLayerColor: Appearance.colors.colSecondaryContainer
            pressedStateLayerColor: Appearance.colors.colSecondaryContainer
            hoverStateLayerOpacity: 0.5
            focusStateLayerOpacity: 0.5
            pressedStateLayerOpacity: 0.7
            rippleColor: Appearance.colors.colPrimary
            Accessible.name: root.networkStatusDetail.length > 0
                ? root.networkStatusText + ", " + root.networkStatusDetail
                : root.networkStatusText
            onClicked: root.networkActivated()

            contentItem: ButtonLabel {
                id: networkContent

                iconName: root.networkIconName
                primaryText: root.networkStatusText
                supportingText: root.networkStatusDetail
                maximumTextWidth: 180
                iconColor: Appearance.colors.colPrimary
                primaryPixelSize: Typography.bodyMedium.pixelSize
                primaryWeight: Font.DemiBold
            }
        }
    }
}
