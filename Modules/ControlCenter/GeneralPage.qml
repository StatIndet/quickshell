pragma ComponentBehavior: Bound

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
        return BluetoothService.devices.find(device => {
            return device.address === root.selectedBluetoothAddress && (
                        root.selectedBluetoothAdapterId.length === 0 || device.adapterId
                        === root.selectedBluetoothAdapterId);
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

    Component {
        id: subpageHeader

        GeneralSubpageHeader {
            readonly property string section: parent.route

            anchors.left: parent.left
            anchors.right: parent.right
            title: {
                switch (section) {
                case "displays":
                    return qsTr("Displays");
                case "bar":
                    return qsTr("Bar");
                case "sidebar":
                    return qsTr("Sidebars");
                case "spotlight":
                    return "Spotlight";
                case "effects":
                    return qsTr("Transparency and blur");
                case "shortcuts":
                    return qsTr("Keyboard shortcuts");
                case "language-region":
                    return qsTr("Language & region");
                case "autostart":
                    return qsTr("Autostart");
                case "default-apps":
                    return qsTr("Default applications");
                case "network":
                    return qsTr("Network");
                case "connected-devices":
                    return qsTr("Connected devices");
                case "bluetooth-pairing":
                    return qsTr("Pair new device");
                case "bluetooth-device":
                {
                    const device = root.selectedBluetoothDevice();
                    return device ? device.name : qsTr("Bluetooth device");
                }
                default:
                    return qsTr("General");
                }
            }
            iconName: {
                switch (section) {
                case "displays":
                    return "monitor";
                case "bar":
                    return "dock_to_bottom";
                case "sidebar":
                    return "side_navigation";
                case "spotlight":
                    return "search";
                case "effects":
                    return "blur_on";
                case "shortcuts":
                    return "keyboard";
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
                }
                default:
                    return "settings";
                }
            }
            onBackRequested: root.goBack()
        }
    }

    SettingsPageHost {
        id: pageLoader

        anchors.fill: parent
        route: root.currentSection
        navigationDepth: root.currentSection === "overview" ? 0 : (root.currentSection === "bluetooth-device"
                                                                   || root.currentSection
                                                                   === "bluetooth-pairing" ? 2 : 1)
        presentationActive: root.presentationActive
        headerComponent: root.currentSection === "overview" ? null : subpageHeader
        source: {
            switch (root.currentSection) {
            case "displays":
                return Qt.resolvedUrl("DisplaysPage.qml");
            case "bar":
                return Qt.resolvedUrl("GeneralBarPage.qml");
            case "sidebar":
                return Qt.resolvedUrl("GeneralSidebarPage.qml");
            case "spotlight":
                return Qt.resolvedUrl("SpotlightPage.qml");
            case "effects":
                return Qt.resolvedUrl("GeneralEffectsPage.qml");
            case "shortcuts":
                return Qt.resolvedUrl("ShortcutsPage.qml");
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
                return;

            if ("parentModal" in item)
                item.parentModal = root.parentModal;

            const page = item;
            if ("presentationActive" in page)
                page.presentationActive = Qt.binding(function () {
                    return root.presentationActive && pageLoader.item === page;
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
