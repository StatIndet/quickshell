import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var screen: null
    property bool vertical: false
    readonly property bool showValue: PersonalizationConfig.barShowValues

    implicitWidth: mouseArea.implicitWidth
    implicitHeight: mouseArea.implicitHeight

    BarActionButton {
        id: mouseArea
        anchors.fill: parent
        vertical: root.vertical
        expandedContent: root.showValue
        contentItem: Item {
            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight
            GridLayout {
                id: content
                anchors.centerIn: parent
                columns: root.vertical ? 1 : 2
                rowSpacing: Sizes.barItemSpacing
                columnSpacing: Sizes.barLabelSpacing
                ArcGauge {
                    id: gauge
                    Layout.preferredWidth: Sizes.barControlCircleSize
                    Layout.preferredHeight: Sizes.barControlCircleSize
                    Layout.alignment: Qt.AlignCenter

                    value: Volume.sinkVolume
                    progressColor: (Volume.sinkMuted || Volume.sinkVolume <= 0) ? BarColors.error :
                                                                                  BarColors.selected

                    trackColor: BarColors.track
                    handleColor: BarColors.foreground
                    iconColor: (Volume.sinkMuted || Volume.sinkVolume <= 0) ? BarColors.error :
                                                                              BarColors.foreground

                    icon: {
                        if (Volume.isHeadphone)
                            return "headphones";
                        if (Volume.sinkMuted || Volume.sinkVolume <= 0)
                            return "volume_off";
                        if (Volume.sinkVolume < 0.5)
                            return "volume_down";
                        return "volume_up";
                    }
                }

                Text {
                    id: valueText
                    visible: root.showValue
                    text: Math.round(Volume.sinkVolume * 100) + "%"
                    font.family: Fonts.numeric
                    font.pixelSize: 12
                    color: BarColors.foreground
                    Layout.alignment: Qt.AlignCenter
                }
            }
        }
        Accessible.name: tooltip.text

        WheelHandler {
            onWheel: wheel => {
                const step = 0.05;
                let newVol = Volume.sinkVolume;
                if (wheel.angleDelta.y > 0)
                    newVol += step;
                else
                    newVol -= step;
                Volume.setSinkVolume(newVol);
            }
        }
        onClicked: {
            if (root.screen && root.screen.name)
                WidgetState.quickSettingsScreenName = root.screen.name;
            if (WidgetState.quickSettingsOpen && WidgetState.quickSettingsView === "audio") {
                WidgetState.quickSettingsOpen = false;
            } else {
                WidgetState.quickSettingsView = "audio";
                WidgetState.quickSettingsOpen = true;
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: mouseArea.pointerHovered
        text: (Volume.sinkMuted ? qsTr("Volume: muted") : qsTr("Volume: ") + Math.round(Volume.sinkVolume
                                                                                        * 100) + "%") + qsTr(
                  "\nScroll to adjust; click to open sound")
    }
}
