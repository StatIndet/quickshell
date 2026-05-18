//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

ApplicationWindow {
    id: root

    visible: true
    width: 560
    height: 220
    minimumWidth: 420
    minimumHeight: 180
    title: "Material Accessible Slider Demo"
    color: Appearance.m3colors.m3background
    Material.theme: Appearance.m3colors.darkmode ? Material.Dark : Material.Light
    Material.accent: Appearance.colors.colPrimary
    onClosing: Qt.quit()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 18

        Text {
            Layout.fillWidth: true
            text: "MaterialAccessibleSlider"
            color: Appearance.colors.colOnSurface
            font.family: Sizes.fontFamily
            font.pixelSize: 20
            font.weight: Font.Medium
        }

        MaterialAccessibleSlider {
            id: demoSlider

            Layout.fillWidth: true
            from: 0
            to: 100
            value: 50
            stepSize: 1
            accessibleName: "Demo slider"
            valueFormatter: sliderValue => Math.round(sliderValue).toString()
        }

        Text {
            Layout.fillWidth: true
            text: "value: " + Math.round(demoSlider.value)
            color: Appearance.colors.colSubtext
            font.family: Sizes.fontFamilyMono
            font.pixelSize: 13
        }
    }
}
