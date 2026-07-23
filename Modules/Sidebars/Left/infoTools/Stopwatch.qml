pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    function mainTime(value) {
        const totalSeconds = Math.floor(value) / 100;
        const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, "0");
        const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, "0");
        return `${minutes}:${seconds}`;
    }

    function centiseconds(value) {
        return (Math.floor(value) % 100).toString().padStart(2, "0");
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.leftMargin: 16
        anchors.rightMargin: 16

        RowLayout {
            id: elapsedIndicator

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: controlButtons.left
            anchors.leftMargin: 6
            spacing: 0

            states: State {
                name: "hasLaps"
                when: TimerService.stopwatchLaps.length > 0

                AnchorChanges {
                    target: elapsedIndicator
                    anchors.top: parent.top
                    anchors.verticalCenter: undefined
                    anchors.left: controlButtons.left
                }
            }

            transitions: Transition {
                AnchorAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }

            Text {
                text: root.mainTime(TimerService.stopwatchTime)
                color: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 40
            }

            Text {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 7
                text: `:${root.centiseconds(TimerService.stopwatchTime)}`
                color: Appearance.colors.colSubtext
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 20
            }
        }

        StyledListView {
            id: lapsList

            anchors.top: elapsedIndicator.bottom
            anchors.bottom: controlButtons.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 16
            anchors.bottomMargin: 16
            spacing: 4
            popin: true
            opacity: TimerService.stopwatchLaps.length > 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }

            model: ScriptModel {
                values: TimerService.stopwatchLaps.map((value, index, values) => values[values.length - 1 - index])
            }

            delegate: Rectangle {
                id: lapItem

                required property int index
                required property var modelData

                readonly property int horizontalPadding: 10
                readonly property int verticalPadding: 6
                readonly property int originalIndex: TimerService.stopwatchLaps.length - index - 1
                readonly property real previousLap: originalIndex > 0
                    ? TimerService.stopwatchLaps[originalIndex - 1]
                    : 0

                width: ListView.view.width
                implicitHeight: lapRow.implicitHeight + verticalPadding * 2
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                RowLayout {
                    id: lapRow

                    anchors.fill: parent
                    anchors.leftMargin: lapItem.horizontalPadding
                    anchors.rightMargin: lapItem.horizontalPadding
                    anchors.topMargin: lapItem.verticalPadding
                    anchors.bottomMargin: lapItem.verticalPadding

                    Text {
                        text: `${TimerService.stopwatchLaps.length - lapItem.index}.`
                        color: Appearance.colors.colSubtext
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: 12
                    }

                    Text {
                        text: `${root.mainTime(lapItem.modelData)}.${root.centiseconds(lapItem.modelData)}`
                        color: Appearance.colors.colOnLayer2
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            const delta = lapItem.modelData - lapItem.previousLap;
                            const main = root.mainTime(delta);
                            const shortened = main.startsWith("00:") ? main.slice(3) : main;
                            return `+${shortened}.${root.centiseconds(delta)}`;
                        }
                        color: Appearance.colors.colPrimary
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: 11
                    }
                }
            }
        }

        RowLayout {
            id: controlButtons

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            spacing: 4

            MaterialRippleButton {
                implicitWidth: 90
                implicitHeight: 35
                buttonRadius: Appearance.rounding.full
                colBackground: TimerService.stopwatchRunning
                    ? Appearance.colors.colSecondaryContainer
                    : Appearance.colors.colPrimary
                colBackgroundHover: TimerService.stopwatchRunning
                    ? Appearance.colors.colSecondaryContainerHover
                    : Appearance.colors.colPrimaryHover
                colRipple: TimerService.stopwatchRunning
                    ? Appearance.colors.colSecondaryContainerActive
                    : Appearance.colors.colPrimaryActive
                Accessible.name: TimerService.stopwatchRunning ? "Pause stopwatch" : "Start stopwatch"
                onClicked: TimerService.toggleStopwatch()

                contentItem: Text {
                    text: TimerService.stopwatchRunning
                        ? "Pause"
                        : TimerService.stopwatchTime === 0
                            ? "Start"
                            : "Resume"
                    color: TimerService.stopwatchRunning
                        ? Appearance.colors.colOnSecondaryContainer
                        : Appearance.colors.colOnPrimary
                    font.family: Sizes.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MaterialRippleButton {
                implicitWidth: 90
                implicitHeight: 35
                buttonRadius: Appearance.rounding.full
                enabled: TimerService.stopwatchTime > 0 || TimerService.stopwatchLaps.length > 0
                colBackground: TimerService.stopwatchRunning
                    ? Appearance.colors.colLayer2
                    : Appearance.colors.colErrorContainer
                colBackgroundHover: TimerService.stopwatchRunning
                    ? Appearance.colors.colLayer2Hover
                    : Appearance.colors.colErrorContainerHover
                colRipple: TimerService.stopwatchRunning
                    ? Appearance.colors.colLayer2Active
                    : Appearance.colors.colErrorContainerActive
                Accessible.name: TimerService.stopwatchRunning ? "Record lap" : "Reset stopwatch"
                onClicked: {
                    if (TimerService.stopwatchRunning)
                        TimerService.stopwatchRecordLap();
                    else
                        TimerService.stopwatchReset();
                }

                contentItem: Text {
                    text: TimerService.stopwatchRunning ? "Lap" : "Reset"
                    color: TimerService.stopwatchRunning
                        ? Appearance.colors.colOnLayer2
                        : Appearance.colors.colOnErrorContainer
                    font.family: Sizes.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
