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
            title: qsTr("网页搜索")
            iconName: "language"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("搜索引擎")
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
                    Accessible.name: qsTr("搜索引擎")
                    onAccepted: (value) => {
                        return UiPreferences.setSpotlightSearchEngine(value);
                    }

                    leadingDelegate: Component {
                        Image {
                            property var optionData: null

                            source: optionData ? Qt.resolvedUrl("../../assets/icons/search-engines/" + optionData.icon) : ""
                            sourceSize.width: Metrics.iconM * 2
                            sourceSize.height: Metrics.iconM * 2
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                    }

                }

            }

        }

    }

}
