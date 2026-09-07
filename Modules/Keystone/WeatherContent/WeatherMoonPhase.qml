import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Components

Item {
    id: root

    implicitHeight: layout.implicitHeight
    implicitWidth: 300

    property real moonPhaseAngle: 0
    property string moonPhaseName: qsTr("New moon")
    property int illumination: 0
    property int currentPhaseIndex: 0

    function updateMoonPhase() {
        let angle = 0;
        if (WeatherPlugin.hasValidData && WeatherPlugin.dailyForecast.count() > 0) {
            angle = WeatherPlugin.dailyForecast.get(0).moonPhaseAngle || 0;
        }
        root.moonPhaseAngle = angle;

        let lit = (1 - Math.cos(angle * Math.PI / 180)) / 2 * 100;
        root.illumination = Math.round(lit);

        let index;
        if (angle < 22.5)
            index = 0;
        else if (angle < 67.5)
            index = 1;
        else if (angle < 112.5)
            index = 2;
        else if (angle < 157.5)
            index = 3;
        else if (angle < 202.5)
            index = 4;
        else if (angle < 247.5)
            index = 5;
        else if (angle < 292.5)
            index = 6;
        else if (angle < 337.5)
            index = 7;
        else
            index = 0;

        root.currentPhaseIndex = index;

        const phases = [qsTr("New moon"), qsTr("Waxing crescent"), qsTr("First quarter"), qsTr(
                            "Waxing gibbous"), qsTr("Full moon"), qsTr("Waning gibbous"), qsTr("Last quarter"),
                        qsTr("Waning crescent")];
        root.moonPhaseName = phases[index];
    }

    Connections {
        target: WeatherPlugin
        function onDataChanged() {
            updateMoonPhase();
        }
    }

    Component.onCompleted: updateMoonPhase()

    function moonPhaseSymbolForIndex(index) {
        const symbols = ["radio_button_unchecked", "brightness_2", "contrast", "tonality", "circle",
                         "tonality", "contrast", "brightness_2"];
        return symbols[Math.max(0, Math.min(7, index))];
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: 8

        MaterialSymbol {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            Layout.alignment: Qt.AlignVCenter
            text: root.moonPhaseSymbolForIndex(root.currentPhaseIndex)
            iconSize: 56
            fill: 1
            color: Appearance.colors.colOnSurface
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -4
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.moonPhaseName
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 24
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    text: root.illumination + "% " + qsTr("Illumination")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.numeric
                    font.pixelSize: 16
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 28

                RowLayout {
                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        model: 8
                        delegate: Item {
                            Layout.fillWidth: true
                            implicitHeight: parent.height

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.moonPhaseSymbolForIndex(index)
                                iconSize: index === root.currentPhaseIndex ? 30 : 22
                                fill: index === root.currentPhaseIndex ? 1 : 0
                                color: index === root.currentPhaseIndex ? Appearance.colors.colPrimary :
                                                                          Appearance.applyAlpha(
                                                                              Appearance.colors.colOnSurfaceVariant,
                                                                              0.5)

                                Behavior on iconSize {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation {
                                        duration: 200
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
