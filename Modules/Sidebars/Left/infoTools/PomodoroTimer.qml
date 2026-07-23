import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ToolCircularProgress {
            Layout.alignment: Qt.AlignHCenter
            implicitSize: 200
            lineWidth: 8
            value: TimerService.pomodoroLapDuration > 0
                ? TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration
                : 0
            enableAnimation: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        const minutes = Math.floor(TimerService.pomodoroSecondsLeft / 60).toString().padStart(2, "0");
                        const seconds = Math.floor(TimerService.pomodoroSecondsLeft % 60).toString().padStart(2, "0");
                        return `${minutes}:${seconds}`;
                    }
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 40
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.pomodoroLongBreak
                        ? "Long break"
                        : TimerService.pomodoroBreak
                            ? "Break"
                            : "Focus"
                    color: Appearance.colors.colSubtext
                    font.family: Sizes.fontFamily
                    font.pixelSize: 14
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitWidth: 36
                implicitHeight: 36
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer2

                Text {
                    anchors.centerIn: parent
                    text: TimerService.pomodoroCycle + 1
                    color: Appearance.colors.colOnLayer2
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 14
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            MaterialRippleButton {
                implicitWidth: 90
                implicitHeight: 35
                buttonRadius: Appearance.rounding.full
                colBackground: TimerService.pomodoroRunning
                    ? Appearance.colors.colSecondaryContainer
                    : Appearance.colors.colPrimary
                colBackgroundHover: TimerService.pomodoroRunning
                    ? Appearance.colors.colSecondaryContainerHover
                    : Appearance.colors.colPrimaryHover
                colRipple: TimerService.pomodoroRunning
                    ? Appearance.colors.colSecondaryContainerActive
                    : Appearance.colors.colPrimaryActive
                Accessible.name: TimerService.pomodoroRunning ? "Pause Pomodoro" : "Start Pomodoro"
                onClicked: TimerService.togglePomodoro()

                contentItem: Text {
                    text: TimerService.pomodoroRunning
                        ? "Pause"
                        : TimerService.pomodoroSecondsLeft === TimerService.pomodoroLapDuration
                            ? "Start"
                            : "Resume"
                    color: TimerService.pomodoroRunning
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
                enabled: TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration
                    || TimerService.pomodoroCycle > 0
                    || TimerService.pomodoroBreak
                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive
                Accessible.name: "Reset Pomodoro"
                onClicked: TimerService.resetPomodoro()

                contentItem: Text {
                    text: "Reset"
                    color: Appearance.colors.colOnErrorContainer
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
