import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    readonly property real gammaCutoff: 0.3
    property var screen: null
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    readonly property real brightnessValue: brightnessMonitor ? brightnessMonitor.brightness :
                                                                Brightness.brightnessValue
    property real verticalPadding: 4
    property real horizontalPadding: 12

    Layout.fillWidth: true
    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + verticalPadding * 2
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    ColumnLayout {
        id: contentItem

        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }
        spacing: 0

        QuickMaterialSlider {
            materialSymbol: "light_mode"
            secondaryMaterialSymbol: "wb_twilight"
            secondaryIconLocation: root.gammaCutoff
            stopIndicatorValues: (DisplayColor.dimming * 100) !== 100 && root.brightnessValue > 0 ? [root.gammaCutoff
                                                                                                     + root.brightnessValue
                                                                                                     * (1 - root.gammaCutoff)] :
                                                                                                    []
            value: (DisplayColor.dimming * 100) === 100 ? root.gammaCutoff + root.brightnessValue * (1
                                                                                                     - root.gammaCutoff) :
                                                          ((DisplayColor.dimming * 100) - (
                                                               DisplayColor.dimmingLowerLimit * 100)) / (100
                                                                                                         - (DisplayColor.dimmingLowerLimit
                                                                                                            * 100)) * root.gammaCutoff
            percentText: (DisplayColor.dimming * 100) === 100 ? `${Math.round(root.brightnessValue * 100)}%` :
                                                                `${Math.round(DisplayColor.dimming * 100)}%`
            tooltipContent: (DisplayColor.dimming * 100) === 100 ? `${Math.round(root.brightnessValue * 100)}%` :
                                                                   qsTr("Software dimming: %1%").arg(
                                                                       Math.round(DisplayColor.dimming * 100))
            onMoved: {
                if (value >= root.gammaCutoff) {
                    Brightness.setBrightnessForScreen(root.screen, (value - root.gammaCutoff) / (1
                                                                                                 - root.gammaCutoff));
                    if ((DisplayColor.dimming * 100) !== 100)
                        DisplayColor.setDimming(1);
                } else {
                    if (root.brightnessValue > 0)
                        Brightness.setBrightnessForScreen(root.screen, 0, true);
                    DisplayColor.setDimming(value / root.gammaCutoff * (1 - DisplayColor.dimmingLowerLimit)
                                            + DisplayColor.dimmingLowerLimit);
                }
            }
        }

        QuickMaterialSlider {
            materialSymbol: "volume_up"
            value: Volume.sinkVolume
            onMoved: Volume.setSinkVolume(value)
        }

        QuickMaterialSlider {
            materialSymbol: "mic"
            value: Volume.sourceVolume
            onMoved: Volume.setSourceVolume(value)
        }
    }
}
