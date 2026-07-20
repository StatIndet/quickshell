import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components

// Adapted from Caelestia Shell's dashboard calendar (GPL-3.0).
Rectangle {
    id: root

    property date displayedDate: new Date()
    property date pendingDate: displayedDate
    property int transitionDirection: -1
    property real monthOffset: 0
    property real monthOpacity: 1

    readonly property int displayYear: displayedDate.getFullYear()
    readonly property int displayMonth: displayedDate.getMonth()

    function navigateMonth(delta) {
        if (monthTransition.running)
            monthTransition.complete();

        transitionDirection = delta > 0 ? -1 : 1;
        pendingDate = new Date(displayYear, displayMonth + delta, 1);
        monthTransition.restart();
    }

    function returnToToday() {
        const now = new Date();
        const currentIndex = displayYear * 12 + displayMonth;
        const nextIndex = now.getFullYear() * 12 + now.getMonth();
        if (currentIndex === nextIndex)
            return;

        if (monthTransition.running)
            monthTransition.complete();
        transitionDirection = nextIndex > currentIndex ? -1 : 1;
        pendingDate = now;
        monthTransition.restart();
    }

    color: Appearance.colors.colLayer3
    radius: 24
    clip: true

    SequentialAnimation {
        id: monthTransition

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "monthOffset"
                to: 30 * root.transitionDirection
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
            NumberAnimation {
                target: root
                property: "monthOpacity"
                to: 0
                duration: Appearance.animation.expressiveEffects.duration
            }
        }
        ScriptAction {
            script: {
                root.displayedDate = root.pendingDate;
                root.monthOffset = -30 * root.transitionDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "monthOffset"
                to: 0
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
            }
            NumberAnimation {
                target: root
                property: "monthOpacity"
                to: 1
                duration: Appearance.animation.expressiveEffects.duration
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: root.returnToToday()
        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.navigateMonth(-1);
            else if (event.angleDelta.y < 0)
                root.navigateMonth(1);
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ToolButton {
                id: previousMonthButton

                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                padding: 0
                background: Rectangle {
                    radius: height / 2
                    color: previousMonthButton.down
                        ? Appearance.colors.colLayer4Active
                        : previousMonthButton.hovered
                          ? Appearance.colors.colLayer4Hover
                          : "transparent"
                }
                contentItem: MaterialSymbol {
                    text: "chevron_left"
                    iconSize: 21
                    color: Appearance.colors.colOnSurface
                }
                onClicked: root.navigateMonth(-1)
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: monthMouse.pressed
                        ? Appearance.colors.colPrimaryContainerActive
                        : monthMouse.containsMouse
                          ? Appearance.colors.colPrimaryContainerHover
                          : Appearance.colors.colPrimaryContainer
                }

                Text {
                    anchors.centerIn: parent
                    opacity: root.monthOpacity
                    transform: Translate { x: root.monthOffset }
                    text: calendarGrid.title
                    color: Appearance.colors.colOnPrimaryContainer
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: monthMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.returnToToday()
                }
            }

            ToolButton {
                id: nextMonthButton

                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                padding: 0
                background: Rectangle {
                    radius: height / 2
                    color: nextMonthButton.down
                        ? Appearance.colors.colLayer4Active
                        : nextMonthButton.hovered
                          ? Appearance.colors.colLayer4Hover
                          : "transparent"
                }
                contentItem: MaterialSymbol {
                    text: "chevron_right"
                    iconSize: 21
                    color: Appearance.colors.colOnSurface
                }
                onClicked: root.navigateMonth(1)
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: calendarGrid.locale

            delegate: Text {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                color: model.day === 0 || model.day === 6
                    ? Appearance.colors.colTertiary
                    : Appearance.colors.colOnSurface
                font.family: Sizes.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: root.monthOpacity
            transform: Translate { x: root.monthOffset }

            MonthGrid {
                id: calendarGrid

                anchors.fill: parent
                month: root.displayMonth
                year: root.displayYear
                locale: Qt.locale()
                spacing: 2

                delegate: Item {
                    id: dayItem

                    required property var model

                    implicitWidth: 38
                    implicitHeight: 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 3
                        height: width
                        radius: width / 2
                        color: dayItem.model.today
                            ? Appearance.colors.colPrimary
                            : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: calendarGrid.locale.toString(dayItem.model.day)
                        color: {
                            if (dayItem.model.today)
                                return Appearance.colors.colOnPrimary;
                            const dayOfWeek = dayItem.model.date.getDay();
                            return dayOfWeek === 0 || dayOfWeek === 6
                                ? Appearance.colors.colTertiary
                                : Appearance.colors.colOnSurfaceVariant;
                        }
                        opacity: dayItem.model.today || dayItem.model.month === calendarGrid.month ? 1 : 0.38
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: 12
                        font.weight: dayItem.model.today ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}
