import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    function closeChildWindows() {
        enginePicker.closeMenu();
    }

    Component.onCompleted: ClipboardService.loadHistoryConfig()

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("Web search")
            iconName: "language"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Search engine")
                iconName: "search"

                trailing: SearchSelectMenuField {
                    id: enginePicker

                    Layout.preferredWidth: 220
                    options: SpotlightSearchService.searchEngines
                    value: UiPreferences.spotlightSearchEngine
                    textRole: "label"
                    valueRole: "id"
                    closeOnAccept: true
                    leadingWidth: Metrics.iconM
                    Accessible.name: qsTr("Search engine")
                    onAccepted: value => {
                        return UiPreferences.setSpotlightSearchEngine(value);
                    }

                    leadingDelegate: Component {
                        Image {
                            property var optionData: null

                            source: optionData ? Qt.resolvedUrl("../../assets/icons/search-engines/"
                                                                + optionData.icon) : ""
                            sourceSize.width: Metrics.iconM * 2
                            sourceSize.height: Metrics.iconM * 2
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("Clipboard")
            iconName: "content_paste"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("History limit")
                supportingText: qsTr("Oldest items are removed when new content is saved.")
                iconName: "history"

                trailing: MaterialStepper {
                    from: 50
                    to: 750
                    stepSize: 50
                    value: ClipboardService.historyLimit
                    enabled: ClipboardService.historyConfigLoaded
                    busy: ClipboardService.historyConfigBusy
                    Accessible.name: qsTr("History limit")
                    onValueModified: value => ClipboardService.setHistoryLimit(value)
                }
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: ClipboardService.historyConfigError !== null
                tone: "error"
                message: ClipboardService.historyConfigError ? ClipboardService.historyConfigError.message :
                                                               ""
            }
        }
    }
}
