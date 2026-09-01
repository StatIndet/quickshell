import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property string hourText: "00"
    property string minuteText: "00"
    property string periodText: "A"
    readonly property string clockFamily: Fonts.systemClock
    readonly property var clockAxes: Fonts.familyAvailable(Fonts.systemClock) ? ({
        "wght": 700,
        "wdth": 75,
        "opsz": 132,
        "GRAD": 75,
        "ROND": 25,
        "slnt": 0
    }) : ({
    })

    function updateTime() {
        const now = new Date();
        const hour24 = now.getHours();
        const displayHour = UiPreferences.useTwelveHourClock ? ((hour24 + 11) % 12) + 1 : hour24;
        root.hourText = String(displayHour).padStart(2, "0");
        root.minuteText = String(now.getMinutes()).padStart(2, "0");
        root.periodText = hour24 >= 12 ? "P" : "A";
    }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateTime()
    }

    Column {
        anchors.centerIn: parent
        spacing: -4

        Text {
            width: root.width
            height: 142
            text: root.hourText
            color: Appearance.colors.colPrimary
            font.family: root.clockFamily
            font.pixelSize: 132
            font.weight: Font.Bold
            font.letterSpacing: -9
            font.variableAxes: root.clockAxes
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            width: root.width
            height: 32

            Row {
                anchors.centerIn: parent
                spacing: 14

                Repeater {
                    model: 2

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: Appearance.colors.colOutlineVariant
                    }

                }

            }

        }

        Text {
            width: root.width
            height: 142
            text: root.minuteText
            color: Appearance.colors.colPrimary
            font.family: root.clockFamily
            font.pixelSize: 132
            font.weight: Font.Bold
            font.letterSpacing: -9
            font.variableAxes: root.clockAxes
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            visible: UiPreferences.useTwelveHourClock
            width: root.width
            height: visible ? 64 : 0
            text: root.periodText + "M"
            color: Appearance.colors.colPrimary
            font.family: root.clockFamily
            font.pixelSize: 56
            font.weight: Font.Bold
            font.letterSpacing: -6
            font.variableAxes: root.clockAxes
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

    }

}
