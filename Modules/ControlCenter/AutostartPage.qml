import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property var pendingRemoveEntry: null
    property var parentModal: null
    readonly property real pageContentWidth: 720

    function openApplicationBrowser() {
        appBrowserLoader.active = true;
        if (appBrowserLoader.item)
            appBrowserLoader.item.show();
    }

    function requestRemove(entry) {
        root.pendingRemoveEntry = entry;
        removeDialog.open();
    }

    function removePendingEntry() {
        const entry = root.pendingRemoveEntry;
        removeDialog.close();
        root.pendingRemoveEntry = null;
        if (entry)
            AutostartService.remove(entry);
    }

    function closeChildWindows() {
        if (appBrowserLoader.item)
            appBrowserLoader.item.hide();
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin
    Component.onCompleted: {
        AutostartService.initialize();
    }

    Loader {
        id: appBrowserLoader

        active: false
        asynchronous: false
        source: Qt.resolvedUrl("AppBrowserPopup.qml")
        onLoaded: item.parentModal = root.parentModal
    }

    Binding {
        target: appBrowserLoader.item
        property: "appsModel"
        value: ApplicationService.applications
        when: appBrowserLoader.status === Loader.Ready
    }

    Connections {
        function onAppSelected(application) {
            AutostartService.addApplication(application);
        }

        target: appBrowserLoader.item
        ignoreUnknownSignals: true
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(root.pageContentWidth, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AutostartService.lastError !== "" && !AutostartService.initializationFailed
            tone: "error"
            message: AutostartService.lastError
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AutostartService.lastMessage !== ""
            tone: "info"
            message: AutostartService.lastMessage
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AutostartService.initializing
            iconName: "progress_activity"
            message: qsTr("Initializing the user autostart directory…")
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AutostartService.initialized && AutostartService.listing
            iconName: "progress_activity"
            message: qsTr("Loading user autostart entries…")
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !AutostartService.initializing && AutostartService.initializationFailed
            spacing: Metrics.spacingS

            InlineStatusBanner {
                Layout.fillWidth: true
                tone: "error"
                message: AutostartService.lastError
            }

            ActionButton {
                text: qsTr("Retry")
                filled: true
                onClicked: AutostartService.initialize()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingXL
            visible: AutostartService.ready

            SettingsSection {
                Layout.fillWidth: true
                flat: true
                iconName: "rocket_launch"
                title: qsTr("Add application to autostart")

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "apps"
                    title: qsTr("Browse applications")
                    supportingText: qsTr("Select an installed app to add to user-level startup")

                    trailing: ActionButton {
                        text: qsTr("Browse applications")
                        enabled: !AutostartService.busy
                        onClicked: root.openApplicationBrowser()
                    }
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                flat: true
                iconName: "list_alt"
                title: qsTr("User autostart applications")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingS

                    ActionButton {
                        text: qsTr("Refresh")
                        enabled: AutostartService.ready
                        onClicked: AutostartService.refresh()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXS

                    Repeater {
                        model: AutostartService.entries

                        delegate: Item {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: Math.max(Metrics.controlHeightXL, entryContent.implicitHeight
                                                     + Metrics.spacingS * 2)

                            RowLayout {
                                id: entryContent

                                anchors.fill: parent
                                anchors.margins: Metrics.spacingS
                                spacing: Metrics.spacingS

                                Image {
                                    Layout.preferredWidth: Metrics.iconL
                                    Layout.preferredHeight: Metrics.iconL
                                    Layout.alignment: Qt.AlignVCenter
                                    source: ApplicationService.iconSourceForEntry(modelData)
                                    sourceSize.width: Metrics.iconL * 2
                                    sourceSize.height: Metrics.iconL * 2
                                    fillMode: Image.PreserveAspectFit
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: Metrics.spacingXXS

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.valid ? modelData.name : qsTr("Invalid entry: %1").arg(
                                                                    modelData.name)
                                        color: modelData.valid ? Appearance.colors.colOnSurface :
                                                                 Appearance.colors.colError
                                        font.family: Fonts.ui
                                        font.pixelSize: Typography.bodyMedium.pixelSize
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.valid ? modelData.exec : modelData.error
                                        color: modelData.valid ? Appearance.colors.colOnSurfaceVariant :
                                                                 Appearance.colors.colError
                                        font.family: Fonts.mono
                                        font.pixelSize: Typography.bodySmall.pixelSize
                                        elide: Text.ElideMiddle
                                    }
                                }

                                StyledSwitch {
                                    Layout.alignment: Qt.AlignVCenter
                                    checked: modelData.valid && !modelData.hidden
                                    enabled: modelData.valid && !AutostartService.busy
                                    onToggled: AutostartService.setEnabled(modelData, checked)
                                }

                                ActionButton {
                                    text: qsTr("Delete")
                                    enabled: !AutostartService.busy
                                    onClicked: root.requestRemove(modelData)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: AutostartService.entries.length === 0
                        spacing: Metrics.spacingS

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "rocket_launch"
                            iconSize: Metrics.iconL
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("No autostart applications")
                            horizontalAlignment: Text.AlignHCenter
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodyMedium.pixelSize
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }

    MaterialDialog {
        id: removeDialog

        anchors.centerIn: Overlay.overlay
        width: Math.min(420, root.width - Metrics.spacingL * 2)
        dialogTitle: qsTr("Delete autostart entry?")
        messageText: root.pendingRemoveEntry ? qsTr("The autostart entry “%1” will be deleted.").arg(
                                                   root.pendingRemoveEntry.name) : ""

        actionsComponent: Component {
            RowLayout {
                spacing: Metrics.spacingS

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    text: qsTr("Cancel")
                    onClicked: removeDialog.close()
                }

                ActionButton {
                    text: qsTr("Delete")
                    onClicked: root.removePendingEntry()
                }
            }
        }
    }
}
