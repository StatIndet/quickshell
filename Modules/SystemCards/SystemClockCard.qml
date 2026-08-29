import "../../Common/functions/DateFormat.js" as DateFormat
import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

Item {
    id: root

    property bool active: true
    property date currentTime: new Date()
    readonly property int hour24: currentTime.getHours()
    readonly property int hour12: ((hour24 + 11) % 12) + 1
    readonly property string hourText: String(UiPreferences.useTwelveHourClock ? hour12 : hour24).padStart(2, "0")
    readonly property string minuteText: String(currentTime.getMinutes()).padStart(2, "0")
    readonly property string periodText: hour24 >= 12 ? "PM" : "AM"
    readonly property string clockFamily: Fonts.systemClock
    readonly property var clockAxes: Fonts.familyAvailable(Fonts.systemClock) ? ({
        "ROND": 25,
        "wdth": 30
    }) : ({
    })
    readonly property var dayNames: [qsTr("星期日"), qsTr("星期一"), qsTr("星期二"), qsTr("星期三"), qsTr("星期四"), qsTr("星期五"), qsTr("星期六")]
    readonly property var monthNames: [qsTr("一月"), qsTr("二月"), qsTr("三月"), qsTr("四月"), qsTr("五月"), qsTr("六月"), qsTr("七月"), qsTr("八月"), qsTr("九月"), qsTr("十月"), qsTr("十一月"), qsTr("十二月")]
    readonly property string dateText: I18nService.language.startsWith("zh") ? DateFormat.compactDate(currentTime, I18nService.language, Qt.locale(), "") : dayNames[currentTime.getDay()] + " · " + String(currentTime.getDate()).padStart(2, "0") + " " + monthNames[currentTime.getMonth()]

    function topOffset(metrics) {
        return metrics.tightBoundingRect.y - metrics.boundingRect.y;
    }

    Accessible.name: hourText + ":" + minuteText + (UiPreferences.useTwelveHourClock ? " " + periodText : "") + "，" + dateText

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    SidebarCookieClock {
        anchors.fill: parent
        visible: UiPreferences.sidebarClockStyle === "cookie"
        active: root.active && visible
    }

    Item {
        id: clockFace

        readonly property real hourSize: Math.min(284, height * 1.06, width * 0.88)
        readonly property real minuteSize: UiPreferences.useTwelveHourClock ? Math.min(164, hourSize * 0.61) : hourSize
        readonly property real periodSize: Math.min(26, Math.max(22, height * 0.085))
        readonly property real dateSize: Math.min(32, Math.max(25, height * 0.115))

        visible: UiPreferences.sidebarClockStyle === "digital"

        anchors {
            fill: parent
            margins: Appearance.spacing.small
        }

        Item {
            id: fullClockComposition

            anchors.centerIn: parent
            width: Math.max(glyphGroup.width, dateMetrics.tightBoundingRect.width)
            height: glyphGroup.height + Appearance.spacing.small + dateMetrics.tightBoundingRect.height
            layer.enabled: clockFace.visible

            Item {
                id: glyphGroup

                readonly property real equalColumnWidth: Math.max(hourMetrics.tightBoundingRect.width, minuteMetrics.tightBoundingRect.width)

                width: UiPreferences.useTwelveHourClock ? hourMetrics.tightBoundingRect.width + Appearance.spacing.medium + Math.max(minuteMetrics.tightBoundingRect.width, periodPill.width) : glyphGroup.equalColumnWidth * 2 + Appearance.spacing.medium
                height: Math.max(hourMetrics.tightBoundingRect.height, minuteMetrics.tightBoundingRect.height + periodPill.height + Appearance.spacing.small)

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }

                Text {
                    id: hours

                    x: UiPreferences.useTwelveHourClock ? -hourMetrics.tightBoundingRect.x : 0
                    y: -root.topOffset(hourMetrics)
                    width: UiPreferences.useTwelveHourClock ? implicitWidth : glyphGroup.equalColumnWidth
                    text: root.hourText
                    color: Appearance.colors.colPrimary
                    renderType: Text.NativeRendering
                    horizontalAlignment: Text.AlignHCenter

                    font {
                        family: root.clockFamily
                        pixelSize: clockFace.hourSize
                        weight: Font.Medium
                        variableAxes: root.clockAxes
                    }

                }

                TextMetrics {
                    id: hourMetrics

                    text: hours.text
                    font: hours.font
                }

                Item {
                    id: minuteColumn

                    width: Math.max(UiPreferences.useTwelveHourClock ? minuteMetrics.tightBoundingRect.width : glyphGroup.equalColumnWidth, UiPreferences.useTwelveHourClock ? periodPill.width : 0)
                    height: minuteMetrics.tightBoundingRect.height + (UiPreferences.useTwelveHourClock ? periodPill.height + Appearance.spacing.small : 0)

                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: minutes

                        anchors.left: parent.left
                        y: -root.topOffset(minuteMetrics)
                        width: parent.width
                        text: root.minuteText
                        color: Appearance.colors.colSecondary
                        renderType: Text.NativeRendering
                        horizontalAlignment: Text.AlignHCenter

                        font {
                            family: root.clockFamily
                            pixelSize: clockFace.minuteSize
                            weight: Font.Medium
                            variableAxes: root.clockAxes
                        }

                    }

                    TextMetrics {
                        id: minuteMetrics

                        text: minutes.text
                        font: minutes.font
                    }

                    Rectangle {
                        id: periodPill

                        visible: UiPreferences.useTwelveHourClock
                        width: periodLabel.implicitWidth + Appearance.spacing.medium
                        height: periodLabel.implicitHeight + Appearance.spacing.small
                        radius: Appearance.rounding.small
                        color: BlurService.solidBackgroundColor(Appearance.colors.colSecondaryContainer)

                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                        }

                        Text {
                            id: periodLabel

                            anchors.centerIn: parent
                            text: root.periodText
                            color: Appearance.colors.colOnSecondaryContainer
                            renderType: Text.NativeRendering

                            font {
                                family: root.clockFamily
                                pixelSize: clockFace.periodSize
                                weight: Font.DemiBold
                                variableAxes: root.clockAxes
                            }

                        }

                    }

                }

            }

            Text {
                id: dateLabel

                width: parent.width
                text: root.dateText
                color: Appearance.colors.colOnSurface
                renderType: Text.NativeRendering
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight

                anchors {
                    top: glyphGroup.bottom
                    topMargin: Appearance.spacing.small
                    horizontalCenter: parent.horizontalCenter
                }

                font {
                    family: root.clockFamily
                    pixelSize: clockFace.dateSize
                    weight: Font.DemiBold
                    letterSpacing: 2.4
                    variableAxes: root.clockAxes
                }

            }

            TextMetrics {
                id: dateMetrics

                text: dateLabel.text
                font: dateLabel.font
            }

            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Appearance.applyAlpha(Appearance.colors.colShadow, 0.4)
                shadowBlur: 0.8
                shadowVerticalOffset: 4
                shadowHorizontalOffset: 0
                autoPaddingEnabled: true
            }

        }

    }

}
