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
    readonly property real brightnessValue: brightnessMonitor ? brightnessMonitor.brightness : Brightness.brightnessValue
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
            stopIndicatorValues: Wlsunset.gamma !== 100 && root.brightnessValue > 0 ? [root.gammaCutoff + root.brightnessValue * (1 - root.gammaCutoff)] : []
            value: Wlsunset.gamma === 100 ? root.gammaCutoff + root.brightnessValue * (1 - root.gammaCutoff) : (Wlsunset.gamma - Wlsunset.gammaLowerLimit) / (100 - Wlsunset.gammaLowerLimit) * root.gammaCutoff
            percentText: Wlsunset.gamma === 100 ? `${Math.round(root.brightnessValue * 100)}%` : `${Wlsunset.gamma}%`
            tooltipContent: Wlsunset.gamma === 100 ? `${Math.round(root.brightnessValue * 100)}%` : `Gamma ${Wlsunset.gamma}%`
            onMoved: {
                if (value >= root.gammaCutoff) {
                    Brightness.setBrightnessForScreen(root.screen, (value - root.gammaCutoff) / (1 - root.gammaCutoff));
                    if (Wlsunset.gamma !== 100)
                        Wlsunset.setGamma(100);
                } else {
                    if (root.brightnessValue > 0)
                        Brightness.setBrightnessForScreen(root.screen, 0, true);
                    Wlsunset.setGamma(value / root.gammaCutoff * (100 - Wlsunset.gammaLowerLimit) + Wlsunset.gammaLowerLimit);
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
