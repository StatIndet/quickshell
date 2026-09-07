import QtQuick
import qs.Common

Rectangle {
    id: root

    property bool active: true
    property color surfaceColor: Appearance.colors.colSurfaceContainerHigh
    property date currentDate: new Date()
    readonly property var monthNames: [qsTr("January"), qsTr("February"), qsTr("March"), qsTr("April"), qsTr(
            "May"), qsTr("June"), qsTr("July"), qsTr("August"), qsTr("September"), qsTr("October"), qsTr(
            "November"), qsTr("December")]
    readonly property var weekdayNames: [qsTr("Sun"), qsTr("Mon"), qsTr("Tue"), qsTr("Wed"), qsTr("Thu"), qsTr(
            "Fri"), qsTr("Sat")]
    readonly property var accessibleWeekdayNames: [qsTr("Sunday"), qsTr("Monday"), qsTr("Tuesday"), qsTr("Wednesday"),
        qsTr("Thursday"), qsTr("Friday"), qsTr("Saturday")]
    readonly property string calendarFamily: Fonts.expressive
    readonly property var calendarAxes: Fonts.familyAvailable(Fonts.bundledFamilyName) && Fonts.expressive
                                        === Fonts.bundledFamilyName ? ({
                                                                           "ROND": 45,
                                                                           "wdth": 78
                                                                       }) : ({})

    radius: Appearance.rounding.extraLarge
    color: root.surfaceColor
    clip: true
    Accessible.name: currentDate.getFullYear() + qsTr(" ") + (currentDate.getMonth() + 1) + qsTr("/")
                     + currentDate.getDate() + qsTr(", ") + accessibleWeekdayNames[currentDate.getDay()]

    Timer {
        interval: 30000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    Rectangle {
        id: headingBand

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Math.max(42, root.height * 0.36)
        color: Appearance.colors.colSecondaryContainer
        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: 0
        bottomRightRadius: 0

        Text {
            anchors.centerIn: parent
            text: root.monthNames[root.currentDate.getMonth()] + "  "
                  + root.weekdayNames[root.currentDate.getDay()]
            color: Appearance.colors.colOnSecondaryContainer
            renderType: Text.NativeRendering
            font {
                family: root.calendarFamily
                pixelSize: Math.min(Typography.titleMedium.pixelSize, headingBand.height * 0.36)
                weight: Font.Bold
                letterSpacing: 0.8
                variableAxes: root.calendarAxes
            }
        }
    }

    Text {
        anchors {
            top: headingBand.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        text: String(root.currentDate.getDate())
        color: Appearance.colors.colOnSurface
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font {
            family: root.calendarFamily
            pixelSize: Math.min(root.width * 0.52, root.height * 0.5)
            weight: Font.Medium
            variableAxes: root.calendarAxes
        }
    }
}
