pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "calendar_layout.js" as CalendarLayout
import "../../../../Common/functions/DateFormat.js" as DateFormat

Item {
    id: root

    property int monthShift: 0
    readonly property date viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    readonly property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    readonly property var weekDays: DateFormat.calendarWeekdays(I18nService.language)

    function monthTitle(date) {
        return DateFormat.monthTitle(date, I18nService.language, Qt.locale());
    }

    focus: true

    Keys.onPressed: event => {
        if (event.modifiers !== Qt.NoModifier)
            return;

        if (event.key === Qt.Key_PageDown) {
            root.monthShift += 1;
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.monthShift -= 1;
            event.accepted = true;
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.monthShift -= 1;
            else if (event.angleDelta.y < 0)
                root.monthShift += 1;
        }
    }

    ColumnLayout {
        id: calendarColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            HeaderButton {
                buttonText: `${root.monthShift !== 0 ? "• " : ""}${root.monthTitle(root.viewingDate)}`
                tooltipText: root.monthShift === 0 ? "" : qsTr("Jump to current month")
                onClicked: root.monthShift = 0
            }

            Item {
                Layout.fillWidth: true
            }

            HeaderButton {
                forceCircle: true
                iconName: "chevron_left"
                accessibleName: qsTr("Previous month")
                onClicked: root.monthShift -= 1
            }

            HeaderButton {
                forceCircle: true
                iconName: "chevron_right"
                accessibleName: qsTr("Next month")
                onClicked: root.monthShift += 1
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: root.weekDays

                delegate: Item {
                    required property string modelData

                    Layout.fillWidth: true
                    implicitHeight: 38

                    DayButton {
                        anchors.centerIn: parent
                        day: parent.modelData
                        bold: true
                        enabled: false
                    }
                }
            }
        }

        Repeater {
            model: 6

            delegate: RowLayout {
                id: weekRow

                required property int index
                readonly property int weekIndex: index

                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: 7

                    delegate: Item {
                        required property int index
                        readonly property var cell: root.calendarLayout[weekRow.weekIndex][index]

                        Layout.fillWidth: true
                        implicitHeight: 38

                        DayButton {
                            anchors.centerIn: parent
                            day: String(parent.cell.day)
                            todayState: parent.cell.today
                        }
                    }
                }
            }
        }
    }

    component HeaderButton: RippleButton {
        id: headerButton

        property string iconName: ""
        property string accessibleName: buttonText
        property string tooltipText: ""
        property bool forceCircle: false

        implicitWidth: forceCircle ? implicitHeight : contentItem.implicitWidth + 20
        implicitHeight: 32
        buttonRadius: Appearance.rounding.full
        containerColor: Appearance.colors.colLayer2
        stateLayerColor: Appearance.colors.colLayer2Hover
        pressedStateLayerColor: Appearance.colors.colLayer2Active
        rippleColor: Appearance.colors.colOnLayer2
        Accessible.name: accessibleName

        Behavior on implicitWidth {
            SmoothedAnimation {
                velocity: 650
            }
        }

        contentItem: Item {
            implicitWidth: headerText.implicitWidth
            implicitHeight: Math.max(headerText.implicitHeight, headerIcon.implicitHeight)

            Text {
                id: headerText

                anchors.centerIn: parent
                visible: headerButton.iconName.length === 0
                text: headerButton.buttonText
                color: Appearance.colors.colOnLayer1
                font.family: Fonts.ui
                font.pixelSize: 14
            }

            MaterialSymbol {
                id: headerIcon

                anchors.centerIn: parent
                visible: headerButton.iconName.length > 0
                text: headerButton.iconName
                iconSize: 21
                color: Appearance.colors.colOnLayer1
            }
        }

        StyledToolTip {
            text: headerButton.tooltipText
            alternativeVisibleCondition: headerButton.activeFocus
            visible: headerButton.tooltipText.length > 0
        }
    }

    component DayButton: RippleButton {
        id: dayButton

        property string day: ""
        property int todayState: 0
        property bool bold: false

        implicitWidth: 38
        implicitHeight: 38
        toggled: todayState === 1
        buttonRadius: Appearance.rounding.small
        containerColor: dayButton.todayState === 1 ? Appearance.colors.colPrimary : "transparent"
        stateLayerColor: dayButton.todayState === 1 ? Appearance.colors.colPrimaryHover :
                                                      Appearance.colors.colLayer1Hover
        pressedStateLayerColor: dayButton.todayState === 1 ? Appearance.colors.colPrimaryActive :
                                                             Appearance.colors.colLayer1Active
        rippleColor: dayButton.todayState === 1 ? Appearance.colors.colOnPrimary :
                                                  Appearance.colors.colOnLayer1

        contentItem: Text {
            text: dayButton.day
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: dayButton.todayState === 1 ? Appearance.colors.colOnPrimary : dayButton.todayState === 0
                                                ? Appearance.colors.colOnLayer1 :
                                                  Appearance.colors.colOutlineVariant
            font.family: Fonts.ui
            font.pixelSize: 14
            font.weight: dayButton.bold ? Font.DemiBold : Font.Normal

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }
        }
    }
}
