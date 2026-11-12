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
    readonly property var monitor: Brightness.getMonitorForScreen(screen)
    readonly property real brightnessValue: monitor ? monitor.brightness : Brightness.brightnessValue

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

                    value: root.brightnessValue
                    progressColor: BarColors.selected
                    trackColor: BarColors.track
                    handleColor: BarColors.foreground
                    iconColor: BarColors.foreground
                    icon: "brightness_medium"
                }

                Text {
                    id: valueText
                    visible: root.showValue
                    text: Math.round(root.brightnessValue * 100) + "%"
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
                let newBri = root.brightnessValue;
                if (wheel.angleDelta.y > 0)
                    newBri += step;
                else
                    newBri -= step;
                Brightness.setBrightnessForScreen(root.screen, newBri);
                wheel.accepted = true;
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: mouseArea.pointerHovered
        text: qsTr("Brightness: ") + Math.round(root.brightnessValue * 100) + qsTr("%\nScroll to adjust")
    }
}
