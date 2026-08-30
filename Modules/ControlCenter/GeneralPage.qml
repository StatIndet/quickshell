import QtQuick
import qs.Common

Item {
    id: root

    property var parentModal: null
    property string currentSection: "overview"
    property bool presentationActive: false
    property var networkDetailTarget: null

    function openSection(section) {
        root.closeChildWindows();
        root.currentSection = section;
    }

    function showOverview() {
        root.closeChildWindows();
        root.currentSection = "overview";
    }

    function showNetworkRoot() {
        root.closeChildWindows();
        root.currentSection = "network";
    }

    function closeChildWindows() {
        if (pageLoader.item && typeof pageLoader.item.closeChildWindows === "function")
            pageLoader.item.closeChildWindows();

    }

    GeneralSubpageHeader {
        id: subpageHeader

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.currentSection !== "overview"
        title: {
            switch (root.currentSection) {
            case "bar":
                return qsTr("条栏");
            case "sidebar":
                return qsTr("侧边栏");
            case "effects":
                return qsTr("透明与模糊");
            case "language-region":
                return qsTr("语言与地区");
            case "autostart":
                return qsTr("开机启动");
            case "default-apps":
                return qsTr("默认应用");
            case "network":
                return qsTr("网络");
            case "network-add":
                return qsTr("添加网络");
            case "network-saved":
                return qsTr("已保存网络");
            case "network-detail":
                return root.networkDetailTarget ? String(root.networkDetailTarget.ssid || root.networkDetailTarget.name || qsTr("连接详情")) : qsTr("连接详情");
            default:
                return qsTr("通用");
            }
        }
        iconName: {
            switch (root.currentSection) {
            case "bar":
                return "dock_to_bottom";
            case "sidebar":
                return "side_navigation";
            case "effects":
                return "blur_on";
            case "language-region":
                return "language";
            case "autostart":
                return "rocket_launch";
            case "default-apps":
                return "apps";
            case "network":
            case "network-add":
            case "network-saved":
            case "network-detail":
                return "wifi";
            default:
                return "settings";
            }
        }
        onBackRequested: root.currentSection.startsWith("network-") ? root.showNetworkRoot() : root.showOverview()
    }

    Loader {
        id: pageLoader

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: subpageHeader.visible ? subpageHeader.bottom : parent.top
        anchors.bottom: parent.bottom
        source: {
            switch (root.currentSection) {
            case "bar":
                return Qt.resolvedUrl("GeneralBarPage.qml");
            case "sidebar":
                return Qt.resolvedUrl("GeneralSidebarPage.qml");
            case "effects":
                return Qt.resolvedUrl("GeneralEffectsPage.qml");
            case "language-region":
                return Qt.resolvedUrl("LanguageAndRegionPage.qml");
            case "autostart":
                return Qt.resolvedUrl("AutostartPage.qml");
            case "default-apps":
                return Qt.resolvedUrl("DefaultAppsPage.qml");
            case "network":
                return Qt.resolvedUrl("NetworkPage.qml");
            case "network-add":
                return Qt.resolvedUrl("AddNetworkPage.qml");
            case "network-saved":
                return Qt.resolvedUrl("SavedNetworksPage.qml");
            case "network-detail":
                return Qt.resolvedUrl("NetworkConnectionDetailPage.qml");
            default:
                return Qt.resolvedUrl("GeneralOverviewPage.qml");
            }
        }
        onLoaded: {
            if (!item)
                return ;

            if ("parentModal" in item)
                item.parentModal = root.parentModal;

            if ("presentationActive" in item)
                item.presentationActive = Qt.binding(function() {
                return root.presentationActive && root.currentSection === "sidebar";
            });

            if ("target" in item)
                item.target = root.networkDetailTarget;

        }
    }

    Connections {
        function onSectionRequested(section) {
            root.openSection(section);
        }

        function onDetailRequested(target) {
            root.networkDetailTarget = target;
            root.openSection("network-detail");
        }

        function onCompleted() {
            root.showNetworkRoot();
        }

        function onProfileForgotten() {
            root.showNetworkRoot();
        }

        target: pageLoader.item
        ignoreUnknownSignals: true
    }

}
