import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property bool vertical: false
    readonly property bool showValue: PersonalizationConfig.barShowValues
    readonly property string temperatureText: WeatherPlugin.hasValidData ? Math.round(
                                                                               UiPreferences.weatherTemperature(
                                                                                   WeatherPlugin.currentTemperatureC))
                                                                           + "°" : "--°"
    readonly property int iconSize: Sizes.barIconSize
    readonly property int temperatureSize: 12
    readonly property real contentSpacing: Sizes.barLabelSpacing
    readonly property bool active: WidgetState.dashboardSidebarOpen && WidgetState.dashboardSidebarView
                                   === "weather"

    function toggleView() {
        if (root.active) {
            WidgetState.dashboardSidebarOpen = false;
            return;
        }
        WidgetState.dashboardSidebarView = "weather";
        WidgetState.dashboardSidebarOpen = true;
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarActionButton {
        id: button

        anchors.fill: parent
        vertical: root.vertical
        expandedContent: root.showValue
        buttonRadius: height / 2
        containerColor: "transparent"
        rippleColor: BarColors.foreground
        releaseAction: () => {
            return root.toggleView();
        }

        contentItem: Item {
            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            GridLayout {
                id: content
                anchors.centerIn: parent
                columns: root.vertical ? 1 : 2
                rowSpacing: Sizes.barItemSpacing
                columnSpacing: root.contentSpacing

                MaterialSymbol {
                    Layout.preferredWidth: root.iconSize
                    Layout.preferredHeight: root.iconSize
                    Layout.alignment: Qt.AlignCenter
                    text: WeatherPlugin.currentIconName || "cloud"
                    iconSize: root.iconSize
                    fill: 0
                    color: BarColors.foreground
                }

                Text {
                    visible: root.showValue
                    Layout.alignment: Qt.AlignCenter
                    text: root.temperatureText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Fonts.numeric
                    font.pixelSize: root.temperatureSize
                    font.bold: true
                    color: BarColors.foreground
                }
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: button.pointerHovered
        text: qsTr("Weather")
    }
}
