import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

FloatingWindow {
    id: root

    property var parentModal: null
    property string currentPage: "saved"
    property string profileParentPage: ""
    property var selectedProfile: null

    function openSavedNetworks() {
        if (!root.parentModal)
            return ;

        root.selectedProfile = null;
        root.profileParentPage = "";
        root.currentPage = "saved";
        root.visible = true;
    }

    function openProfile(profile, parentPage) {
        if (!root.parentModal || !profile)
            return ;

        root.selectedProfile = profile;
        root.profileParentPage = String(parentPage || "");
        root.currentPage = "profile";
        profileEditor.resetEditor();
        root.visible = true;
    }

    function openAddNetwork() {
        if (!root.parentModal)
            return ;

        root.selectedProfile = null;
        root.profileParentPage = "";
        root.currentPage = "add";
        root.visible = true;
    }

    function dismiss() {
        if (root.currentPage === "add")
            addPage.resetForm();

        root.visible = false;
    }

    function leaveProfile() {
        if (root.profileParentPage === "saved") {
            root.selectedProfile = null;
            root.profileParentPage = "";
            root.currentPage = "saved";
        } else {
            root.dismiss();
        }
    }

    visible: false
    parentWindow: root.parentModal
    title: qsTr("网络配置")
    implicitWidth: 620
    implicitHeight: 640
    minimumSize: Qt.size(500, 520)
    color: "transparent"
    onClosed: {
        if (root.currentPage === "add")
            addPage.resetForm();

        root.visible = false;
    }

    Rectangle {
        id: windowBackground

        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        color: BlurService.backgroundColor(Appearance.m3colors.m3surfaceContainerHigh)
        border.width: Metrics.dividerWidth
        border.color: Appearance.colors.colOutlineVariant
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: windowBackground
        radius: windowBackground.radius
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: (event) => {
            if (root.currentPage === "profile" && root.profileParentPage === "saved")
                root.leaveProfile();
            else
                root.dismiss();
            event.accepted = true;
        }

        PageTransitionLayer {
            anchors.fill: parent
            active: root.currentPage === "saved"
            hubPage: true
            transitionsEnabled: root.visible

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Metrics.spacingXL
                spacing: Metrics.spacingM

                WizardHeader {
                    Layout.fillWidth: true
                    title: qsTr("已保存网络")
                    onCloseRequested: root.dismiss()
                }

                SavedNetworksPage {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onDetailRequested: (profile) => {
                        return root.openProfile(profile, "saved");
                    }
                }

            }

        }

        PageTransitionLayer {
            anchors.fill: parent
            active: root.currentPage === "profile"
            transitionsEnabled: root.visible

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Metrics.spacingXL
                spacing: Metrics.spacingM

                WizardHeader {
                    Layout.fillWidth: true
                    title: qsTr("连接配置")
                    subtitle: root.selectedProfile ? String(root.selectedProfile.ssid || root.selectedProfile.name || "") : ""
                    showBack: root.profileParentPage === "saved"
                    onBackRequested: root.leaveProfile()
                    onCloseRequested: root.dismiss()
                }

                NetworkProfileEditor {
                    id: profileEditor

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    target: root.selectedProfile
                    onProfileForgotten: root.leaveProfile()
                }

            }

        }

        PageTransitionLayer {
            anchors.fill: parent
            active: root.currentPage === "add"
            transitionsEnabled: root.visible

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Metrics.spacingXL
                spacing: Metrics.spacingM

                WizardHeader {
                    Layout.fillWidth: true
                    title: qsTr("添加网络")
                    onCloseRequested: root.dismiss()
                }

                AddNetworkPage {
                    id: addPage

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onCompleted: root.dismiss()
                }

            }

        }

    }

}
