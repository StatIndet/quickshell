import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Services
import qs.Components

ApplicationWindow {
    id: root

    visible: true
    title: "设置"
    flags: Qt.Window | Qt.FramelessWindowHint
    width: 1100
    height: 750
    minimumWidth: 760
    minimumHeight: 520
    color: Appearance.m3colors.m3background
    Material.theme: PersonalizationConfig.themeMode === "light" ? Material.Light : Material.Dark
    Material.accent: Appearance.colors.colPrimary
    onClosing: Qt.quit()

    property real contentPadding: 8
    property int currentPage: 0
    property bool navExpanded: width > 900
    readonly property var pages: [
        ({ "title": "通用", "icon": "settings" }),
        ({ "title": "壁纸", "icon": "wallpaper" }),
        ({ "title": "主题", "icon": "palette" }),
        ({ "title": "钥石", "icon": "pill" })
    ]

    function pageComponent(index) {
        switch (index) {
        case 0:
            return generalPage;
        case 1:
            return wallpaperPage;
        case 2:
            return themePage;
        case 3:
            return keystonePage;
        default:
            return generalPage;
        }
    }

    function openConfig() {
        Qt.openUrlExternally(Paths.fileUrl(PersonalizationConfig.filePath));
    }

    function copyConfigPath() {
        Quickshell.clipboardText = PersonalizationConfig.filePath;
        copiedTimer.restart();
    }

    Timer {
        id: copiedTimer
        interval: 1400
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.contentPadding
        spacing: root.contentPadding

        Item {
            id: titlebar
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(titleText.implicitHeight, closeButton.implicitHeight)

            Text {
                id: titleText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                text: "设置"
                color: Appearance.colors.colOnLayer0
                font.family: Sizes.fontFamily
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 35
                implicitHeight: 35
                radius: Appearance.rounding.full
                color: closeMouse.pressed ? Appearance.colors.colLayer1Active : closeMouse.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 20
                    color: Appearance.colors.colOnLayer1
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            DragHandler {
                target: null
                acceptedButtons: Qt.LeftButton
                onActiveChanged: {
                    if (active)
                        root.startSystemMove();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.contentPadding

            Item {
                    id: navRailWrapper
                    Layout.fillHeight: true
                    Layout.margins: 5
                    implicitWidth: root.navExpanded ? 150 : configButton.baseSize

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    ColumnLayout {
                        id: navRail
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        spacing: 10

                        NavigationRailExpandButton {
                            expanded: root.navExpanded
                            onClicked: root.navExpanded = !root.navExpanded
                        }

                        FloatingActionButton {
                            id: configButton
                            property bool justCopied: copiedTimer.running

                            iconText: justCopied ? "check" : "edit"
                            buttonText: justCopied ? "路径已复制" : "配置文件"
                            expanded: root.navExpanded
                            onClicked: root.openConfig()
                            onAltClicked: root.copyConfigPath()
                        }

                        NavigationRailTabArray {
                            currentIndex: root.currentPage
                            expanded: root.navExpanded

                            Repeater {
                                model: root.pages

                                NavigationRailButton {
                                    required property int index
                                    required property var modelData

                                    active: root.currentPage === index
                                    expanded: root.navExpanded
                                    buttonIcon: modelData.icon
                                    buttonText: modelData.title
                                    showToggledHighlight: false
                                    onPressed: root.currentPage = index
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }

                Rectangle {
                    id: bodyBackground

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Math.max(0, Appearance.rounding.large - root.contentPadding)
                    color: Appearance.m3colors.m3surfaceContainerLow
                    clip: true

                    Loader {
                        id: pageLoader
                        anchors.fill: parent
                        sourceComponent: root.pageComponent(root.currentPage)
                    }
            }
        }
    }

    Component {
        id: generalPage
        GeneralPage {}
    }

    Component {
        id: wallpaperPage
        WallpaperPage {}
    }

    Component {
        id: themePage
        ThemePage {}
    }

    Component {
        id: keystonePage
        KeystonePage {}
    }
}
