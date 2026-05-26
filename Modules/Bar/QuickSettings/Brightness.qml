import QtQuick
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

Item {
    id: root

    implicitHeight: 28
    implicitWidth: 28

    ArcGauge {
        anchors.fill: parent

        value: Brightness.brightnessValue
        progressColor: Appearance.colors.colPrimary
        trackColor: Appearance.colors.colLayer2Hover
        handleColor: Appearance.colors.colOnSurface
        iconColor: Appearance.colors.colOnSurface
        icon: "brightness_medium"
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onWheel: (wheel) => {
            const step = 0.05
            let newBri = Brightness.brightnessValue
            if (wheel.angleDelta.y > 0) newBri += step
            else newBri -= step
            Brightness.setBrightness(newBri)
        }
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: "亮度: " + Math.round(Brightness.brightnessValue * 100) + "%\n滚轮调节"
    }
}
