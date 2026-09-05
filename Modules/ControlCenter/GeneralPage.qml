import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property var parentModal: null
    property string currentSection: "overview"
    property bool presentationActive: false
    property string selectedBluetoothAddress: ""
    property string selectedBluetoothAdapterId: ""

    signal navigateRequested(string pageId)

    function selectedBluetoothDevice() {
        return BluetoothService.devices.find((device) => {
            return device.address === root.selectedBluetoothAddress && (root.selectedBluetoothAdapterId.length === 0 || device.adapterId === root.selectedBluetoothAdapterId);
        }) || null;
    }

    function openSection(section) {
        root.closeChildWindows();
        BluetoothService.clearError();
        root.currentSection = section;
    }

    function showOverview() {
        root.closeChildWindows();
        BluetoothService.clearError();
        root.currentSection = "overview";
    }

    function showConnectedDevices() {
        root.openSection("connected-devices");
    }

    function openBluetoothDevice(address, adapterId) {
        root.selectedBluetoothAddress = address;
        root.selectedBluetoothAdapterId = adapterId;
        root.openSection("bluetooth-device");
    }

    function goBack() {
        if (root.currentSection === "bluetooth-pairing" || root.currentSection === "bluetooth-device")
            root.showConnectedDevices();
        else
            root.showOverview();
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
            case "spotlight":
                return "Spotlight";
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
            case "connected-devices":
                return qsTr("连接的设备");
            case "bluetooth-pairing":
                return qsTr("配对新设备");
            case "bluetooth-device":
                {
                    const device = root.selectedBluetoothDevice();
                    return device ? device.name : qsTr("蓝牙设备");
                };
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
            case "spotlight":
                return "search";
            case "effects":
                return "blur_on";
            case "language-region":
                return "language";
            case "autostart":
                return "rocket_launch";
            case "default-apps":
                return "apps";
            case "network":
                return "wifi";
            case "connected-devices":
            case "bluetooth-pairing":
                return "devices_other";
            case "bluetooth-device":
                {
                    const device = root.selectedBluetoothDevice();
                    return BluetoothDeviceIcon.iconName(device);
                };
            default:
                return "settings";
            }
        }
        onBackRequested: root.goBack()
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
            case "spotlight":
                return Qt.resolvedUrl("SpotlightPage.qml");
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
            case "connected-devices":
                return Qt.resolvedUrl("ConnectedDevicesPage.qml");
            case "bluetooth-pairing":
                return Qt.resolvedUrl("BluetoothPairingPage.qml");
            case "bluetooth-device":
                return Qt.resolvedUrl("BluetoothDevicePage.qml");
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
                return root.presentationActive;
            });

            if ("deviceAddress" in item)
                item.deviceAddress = root.selectedBluetoothAddress;

            if ("deviceAdapterId" in item)
                item.deviceAdapterId = root.selectedBluetoothAdapterId;

        }
    }

    Connections {
        function onSectionRequested(section) {
            root.openSection(section);
        }

        function onPairingRequested() {
            root.openSection("bluetooth-pairing");
        }

        function onDeviceRequested(address, adapterId) {
            root.openBluetoothDevice(address, adapterId);
        }

        function onReturnRequested() {
            root.showConnectedDevices();
        }

        function onNavigateRequested(pageId) {
            root.navigateRequested(pageId);
        }

        target: pageLoader.item
        ignoreUnknownSignals: true
    }

}
