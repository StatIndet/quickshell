import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Components
import qs.Widgets.common

FloatingWindow {
    id: root

    visible: false
    title: "clavis-control-center"
    implicitWidth: 1100
    implicitHeight: 750
    minimumSize: Qt.size(760, 520)
    color: "transparent"
    Material.theme: PersonalizationConfig.themeMode === "light" ? Material.Light : Material.Dark
    Material.accent: Appearance.colors.colPrimary

    signal popoutClosed
    property bool _wasShown: false

    function showWindow() {
        root._wasShown = true;
        root.visible = true;
    }

    function hideWindow() {
        if (root.visible) {
            root.closeChildWindows();
            root.visible = false;
        }
    }

    function toggleWindow() {
        if (root.visible)
            root.hideWindow();
        else
            root.showWindow();
    }

    onVisibleChanged: {
        if (!root.visible && root._wasShown) {
            root.closeChildWindows();
            root._wasShown = false;
            root.popoutClosed();
        }
    }

    property real contentPadding: 8
    property int currentPage: 0
    property bool navExpanded: width > 900
    property string pendingPageSection: ""
    readonly property var pages: [
        ({ "id": "account", "title": qsTr("账户"), "icon": "account_circle", "source": "AccountPage.qml" }),
        ({ "id": "general", "title": qsTr("通用"), "icon": "settings", "source": "GeneralPage.qml" }),
        ({ "id": "wallpaper", "title": qsTr("壁纸"), "icon": "wallpaper", "source": "WallpaperPage.qml" }),
        ({ "id": "theme", "title": qsTr("主题"), "icon": "palette", "source": "ThemePage.qml" }),
        ({ "id": "keystone", "title": qsTr("钥石"), "icon": "toggle_off", "source": "KeystonePage.qml" }),
        ({ "id": "weather", "title": qsTr("天气"), "icon": "partly_cloudy_day", "source": "WeatherPage.qml" }),
        ({ "id": "advanced", "title": qsTr("高级"), "icon": "tune", "source": "AdvancedPage.qml" })
    ]

    function pageSource(index) {
        if (index < 0 || index >= pages.length)
            return Qt.resolvedUrl("AccountPage.qml");
        return Qt.resolvedUrl(pages[index].source);
    }

    function openPage(pageId) {
        for (let index = 0; index < pages.length; ++index) {
            if (pages[index].id === pageId) {
                currentPage = index;
                return true;
            }
        }
        return false;
    }

    function openPageSection(pageId, section) {
        root.pendingPageSection = section;
        if (!root.openPage(pageId)) {
            root.pendingPageSection = "";
            return false;
        }
        root.applyPendingPageSection();
        return true;
    }

    function applyPendingPageSection() {
        if (!root.pendingPageSection || !pageLoader.item)
            return;
        if (root.pages[root.currentPage].id !== "general"
                || typeof pageLoader.item.openSection !== "function")
            return;
        const section = root.pendingPageSection;
        root.pendingPageSection = "";
        pageLoader.item.openSection(section);
    }

    function closeChildWindows() {
        const page = pageLoader.item;
        if (page && typeof page.closeChildWindows === "function")
            page.closeChildWindows();
    }

    onCurrentPageChanged: root.closeChildWindows()

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

    Rectangle {
        id: outerBackground

        anchors.fill: parent
        radius: Appearance.rounding.large
        color: BlurService.backgroundColor(
            Appearance.m3colors.m3background)
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: outerBackground
        radius: outerBackground.radius
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
                text: qsTr("设置")
                color: Appearance.colors.colOnLayer0
                font.family: Fonts.ui
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
                    onClicked: root.hideWindow()
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
                            buttonText: justCopied ? qsTr("路径已复制") : qsTr("配置文件")
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
                    color: root.currentPage === 0
                        ? "transparent"
                        : Appearance.m3colors.m3surfaceContainerLow
                    clip: true

                    Loader {
                        id: pageLoader

                        property var parentModal: root
                        anchors.fill: parent
                        source: root.pageSource(root.currentPage)

                        onLoaded: {
                            if (item && "parentModal" in item)
                                item.parentModal = parentModal;
                            if (item && "presentationActive" in item)
                                item.presentationActive = Qt.binding(function() { return root.visible; });
                            root.applyPendingPageSection();
                        }
                    }

                    Connections {
                        target: pageLoader.item
                        ignoreUnknownSignals: true

                        function onNavigateRequested(pageId) {
                            if (pageId === "connected-devices" || pageId === "network") {
                                root.openPageSection("general", pageId);
                                return;
                            }
                            root.openPage(pageId);
                        }
                    }
            }
        }
    }
}
