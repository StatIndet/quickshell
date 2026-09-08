import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

FloatingWindow {
    id: root

    property var parentModal: null
    property var appsModel: []
    property string searchQuery: ""
    property var filteredApps: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false

    signal appSelected(var application)

    parentWindow: root.parentModal
    objectName: "clavisAutostartAppBrowser"
    // Stable compositor rule identity; visible headings remain localized.
    title: "clavis-control-center-application-browser"
    minimumSize: Qt.size(420, 380)
    implicitWidth: 560
    implicitHeight: 620
    color: "transparent"
    visible: false

    function updateFilteredApps() {
        const query = root.searchQuery.trim().toLocaleLowerCase();
        const source = root.appsModel || [];
        if (query === "") {
            root.filteredApps = source.slice();
        } else {
            root.filteredApps = source.filter(application => {
                const values = [application.name, application.id, application.genericName,
                                application.comment];
                const keywords = application.keywords || [];
                for (const keyword of keywords)
                    values.push(keyword);
                return values.some(value => String(value || "").toLocaleLowerCase().includes(query));
            });
        }
        root.selectedIndex = -1;
        root.keyboardNavigationActive = false;
    }

    function selectNext() {
        if (root.filteredApps.length === 0)
            return;
        root.keyboardNavigationActive = true;
        root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredApps.length - 1);
        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    function selectPrevious() {
        if (root.filteredApps.length === 0)
            return;
        root.keyboardNavigationActive = true;
        root.selectedIndex = Math.max(root.selectedIndex - 1, -1);
        if (root.selectedIndex < 0)
            root.keyboardNavigationActive = false;
        else
            appList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    function selectApplication(index) {
        const application = root.filteredApps[index];
        if (!application)
            return;
        root.appSelected(application);
        root.hide();
    }

    function show() {
        if (!root.parentModal) {
            console.warn("AppBrowserPopup cannot open without parentModal");
            return;
        }
        root.updateFilteredApps();
        root.visible = true;
        root.focusSearch();
    }

    function focusSearch() {
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    function hide() {
        root.visible = false;
        searchField.text = "";
        root.searchQuery = "";
        root.filteredApps = [];
        root.selectedIndex = -1;
        root.keyboardNavigationActive = false;
    }

    onClosed: root.hide()
    onAppsModelChanged: {
        if (root.visible)
            root.updateFilteredApps();
    }

    Rectangle {
        id: background

        anchors.fill: parent
        radius: Appearance.rounding.large
        color: BlurService.backgroundColor(Appearance.m3colors.m3surface)
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: background
        radius: background.radius
    }

    FocusScope {
        id: contentFocus

        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.hide();
                event.accepted = true;
                return;
            case Qt.Key_Down:
                root.selectNext();
                event.accepted = true;
                return;
            case Qt.Key_Up:
                root.selectPrevious();
                event.accepted = true;
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.selectApplication(root.keyboardNavigationActive ? root.selectedIndex : 0);
                event.accepted = true;
                return;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spacingM
            spacing: Metrics.spacingM

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.controlHeightL

                RowLayout {
                    anchors.fill: parent
                    spacing: Metrics.spacingS

                    Rectangle {
                        Layout.preferredWidth: Metrics.controlHeightM
                        Layout.preferredHeight: Metrics.controlHeightM
                        Layout.alignment: Qt.AlignVCenter
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colPrimaryContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "apps"
                            iconSize: Metrics.iconM
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingXXS

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Select application")
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: Typography.titleMedium.pixelSize
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Select an installed application to add to user autostart")
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodySmall.pixelSize
                            elide: Text.ElideRight
                        }
                    }

                    ActionButton {
                        text: qsTr("Close")
                        onClicked: root.hide()
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

            MaterialTextField {
                id: searchField

                Layout.fillWidth: true
                placeholderText: qsTr("Search by application name, ID, or description")
                leadingContent: Component {
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "search"
                        iconSize: Metrics.iconM - Metrics.spacingXXS
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                onTextChanged: {
                    if (root.searchQuery !== text)
                        root.searchQuery = text;
                    root.updateFilteredApps();
                }
            }

            StyledListView {
                id: appList

                Layout.fillWidth: true
                Layout.fillHeight: true
                model: root.filteredApps
                spacing: Metrics.spacingXS
                clip: true

                delegate: Rectangle {
                    required property int index
                    required property var modelData

                    width: appList.width
                    height: Math.max(Metrics.controlHeightXL, appContent.implicitHeight + Metrics.spacingS
                                     * 2)
                    radius: Metrics.cornerM
                    color: root.keyboardNavigationActive && index === root.selectedIndex
                           ? Appearance.colors.colPrimaryContainer : pointer.containsMouse
                             ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1
                    border.width: root.keyboardNavigationActive && index === root.selectedIndex ? 1 : 0
                    border.color: Appearance.colors.colPrimary

                    RowLayout {
                        id: appContent

                        anchors.fill: parent
                        anchors.margins: Metrics.spacingS
                        spacing: Metrics.spacingS

                        Image {
                            Layout.preferredWidth: Metrics.iconL
                            Layout.preferredHeight: Metrics.iconL
                            Layout.alignment: Qt.AlignVCenter
                            source: ApplicationService.iconSource(modelData.icon)
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
                                text: modelData.name || modelData.id
                                color: Appearance.colors.colOnSurface
                                font.family: Fonts.ui
                                font.pixelSize: Typography.bodyMedium.pixelSize
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.genericName || modelData.comment || modelData.id
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Fonts.ui
                                font.pixelSize: Typography.bodySmall.pixelSize
                                elide: Text.ElideRight
                            }
                        }

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            text: "add"
                            iconSize: Metrics.iconM
                            color: Appearance.colors.colPrimary
                        }
                    }

                    MouseArea {
                        id: pointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectApplication(index)
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Metrics.spacingS
                    visible: root.filteredApps.length === 0

                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "search_off"
                        iconSize: Metrics.iconL
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    Text {
                        text: qsTr("No matching applications")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: Typography.bodyMedium.pixelSize
                    }
                }
            }
        }
    }
}
