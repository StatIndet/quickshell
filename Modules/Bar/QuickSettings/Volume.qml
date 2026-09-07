import QtQuick
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var screen: null

    implicitHeight: 28
    implicitWidth: 28

    ArcGauge {
        anchors.fill: parent

        value: Volume.sinkVolume
        progressColor: (Volume.sinkMuted || Volume.sinkVolume <= 0) ? Appearance.colors.colError :
                                                                      Appearance.colors.colPrimary
        trackColor: Appearance.colors.colLayer2Hover
        handleColor: Appearance.colors.colOnSurface
        iconColor: (Volume.sinkMuted || Volume.sinkVolume <= 0) ? Appearance.colors.colError :
                                                                  Appearance.colors.colOnSurface

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

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onWheel: wheel => {
            const step = 0.05;
            let newVol = Volume.sinkVolume;
            if (wheel.angleDelta.y > 0)
                newVol += step;
            else
                newVol -= step;
            Volume.setSinkVolume(newVol);
        }
        onClicked: {
            if (root.screen && root.screen.name)
                WidgetState.qsScreenName = root.screen.name;
            if (WidgetState.qsOpen && WidgetState.qsView === "audio") {
                WidgetState.qsOpen = false;
            } else {
                WidgetState.qsView = "audio";
                WidgetState.qsOpen = true;
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: (Volume.sinkMuted ? qsTr("Volume: muted") : qsTr("Volume: ") + Math.round(Volume.sinkVolume
                                                                                        * 100) + "%") + qsTr(
                  "\nScroll to adjust; click to open sound")
    }
}
