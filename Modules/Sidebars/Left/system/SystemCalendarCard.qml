import QtQuick
import qs.Common

Rectangle {
    id: root

    property date currentDate: new Date()
    readonly property var monthNames: [
        "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"
    ]
    readonly property var weekdayNames: [
        "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"
    ]
    readonly property var accessibleWeekdayNames: [
        "星期日", "星期一", "星期二", "星期三",
        "星期四", "星期五", "星期六"
    ]
    readonly property string calendarFamily:
        displayFont.status === FontLoader.Ready
            ? displayFont.name
            : Sizes.fontFamily
    readonly property var calendarAxes:
        displayFont.status === FontLoader.Ready
            ? ({
                "ROND": 45,
                "wdth": 78
            })
            : ({})

    radius: Appearance.rounding.extraLarge
    color: Appearance.colors.colSurfaceContainerHigh
    clip: true
    Accessible.name: currentDate.getFullYear()
        + "年" + (currentDate.getMonth() + 1)
        + "月" + currentDate.getDate()
        + "日，" + accessibleWeekdayNames[currentDate.getDay()]

    FontLoader {
        id: displayFont

        source: Paths.fileUrl(
            Paths.fontsDir
                + "/google-sans-flex/"
                + "GoogleSansFlex-VariableFont_"
                + "GRAD,ROND,opsz,slnt,wdth,wght.ttf"
        )
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
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
            text: root.monthNames[root.currentDate.getMonth()]
                + "  " + root.weekdayNames[root.currentDate.getDay()]
            color: Appearance.colors.colOnSecondaryContainer
            renderType: Text.NativeRendering
            font {
                family: root.calendarFamily
                pixelSize: Math.min(
                    Sizes.typeTitleMedium,
                    headingBand.height * 0.36
                )
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
