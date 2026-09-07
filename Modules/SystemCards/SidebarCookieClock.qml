import QtQuick
import qs.Common
import qs.Services
import "CookieClock"

Item {
    id: root

    property bool active: true
    property date currentTime: new Date()
    readonly property real referenceSize: 230
    readonly property real compositionScale: Math.max(0.01, Math.min(width, height) * 0.9
                                                      / root.referenceSize)
    readonly property int hour24: root.currentTime.getHours()
    readonly property int hour12: ((root.hour24 + 11) % 12) + 1
    readonly property int minute: root.currentTime.getMinutes()
    readonly property int second: root.currentTime.getSeconds()
    readonly property color faceColor: BlurService.solidBackgroundColor(Appearance.colors.colPrimaryContainer)
    readonly property color dialColor: Appearance.mix(Appearance.colors.colSecondary,
                                                      Appearance.colors.colPrimaryContainer, 0.15)
    readonly property color infoColor: Appearance.mix(Appearance.colors.colPrimary,
                                                      Appearance.colors.colPrimaryContainer, 0.55)
    readonly property string periodText: root.hour24 >= 12 ? "PM" : "AM"
    readonly property string centerHourText: String(UiPreferences.useTwelveHourClock ? root.hour12 :
                                                                                       root.hour24).padStart(2,
                                                                                                             "0")
    readonly property string centerMinuteText: String(root.minute).padStart(2, "0")

    Accessible.name: qsTr("Cookie clock ") + root.centerHourText + ":" + root.centerMinuteText + (
                         UiPreferences.useTwelveHourClock ? " " + root.periodText : "")

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    Item {
        id: composition

        width: root.referenceSize
        height: root.referenceSize
        anchors.centerIn: parent
        scale: root.compositionScale
        transformOrigin: Item.Center

        CookieBody {
            anchors.fill: parent
            active: root.active
            constantlyRotate: UiPreferences.sidebarCookieConstantlyRotate
            sides: UiPreferences.sidebarCookieSides
            faceColor: root.faceColor
        }

        MinuteMarks {
            anchors.fill: parent
            style: UiPreferences.sidebarCookieDialStyle
            color: root.dialColor
            z: 1
        }

        Loader {
            active: UiPreferences.sidebarCookieHourMarks
            visible: status === Loader.Ready
            anchors.centerIn: parent
            z: 1

            sourceComponent: HourMarks {
                color: root.dialColor
                markColor: Appearance.mix(root.infoColor, root.dialColor, 0.5)
            }
        }

        Loader {
            active: UiPreferences.sidebarCookieTimeIndicators
            visible: status === Loader.Ready
            anchors.centerIn: parent
            z: 1

            sourceComponent: TimeColumn {
                hour24: root.hour24
                minute: root.minute
                useTwelveHourClock: UiPreferences.useTwelveHourClock
                hourMarksEnabled: UiPreferences.sidebarCookieHourMarks
                color: root.infoColor
            }
        }

        Loader {
            active: UiPreferences.sidebarCookieMinuteHandStyle !== "hide"
            visible: status === Loader.Ready
            anchors.fill: parent
            z: 2

            sourceComponent: MinuteHand {
                minute: root.minute
                style: UiPreferences.sidebarCookieMinuteHandStyle
            }
        }

        Loader {
            active: UiPreferences.sidebarCookieHourHandStyle !== "hide"
            visible: status === Loader.Ready
            anchors.fill: parent
            z: UiPreferences.sidebarCookieHourHandStyle === "hollow" ? 0 : 3

            sourceComponent: HourHand {
                hour: root.hour12
                minute: root.minute
                style: UiPreferences.sidebarCookieHourHandStyle
            }
        }

        Loader {
            active: UiPreferences.sidebarCookieSecondHandStyle !== "hide"
            visible: status === Loader.Ready
            anchors.fill: parent
            z: UiPreferences.sidebarCookieSecondHandStyle === "line" ? 3 : 4

            sourceComponent: SecondHand {
                second: root.second
                constantlyRotate: UiPreferences.sidebarCookieConstantlyRotate
                style: UiPreferences.sidebarCookieSecondHandStyle
            }
        }

        Loader {
            active: UiPreferences.sidebarCookieMinuteHandStyle !== "bold"
            visible: status === Loader.Ready
            anchors.centerIn: parent
            z: 5

            sourceComponent: Rectangle {
                width: 6
                height: width
                radius: width / 2
                color: UiPreferences.sidebarCookieMinuteHandStyle === "medium" ? root.faceColor :
                                                                                 Appearance.colors.colTertiary
            }
        }

        Loader {
            active: UiPreferences.sidebarCookieDateStyle !== "hide"
            visible: status === Loader.Ready
            anchors.fill: parent
            z: 6

            sourceComponent: DateIndicator {
                style: UiPreferences.sidebarCookieDateStyle
                currentTime: root.currentTime
                second: root.second
                active: root.active
                infoColor: root.infoColor
            }
        }
    }
}
