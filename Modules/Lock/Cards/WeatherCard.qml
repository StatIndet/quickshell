import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Common

Rectangle {
    id: root

    property real availableHeight: height
    readonly property string temp: fmtTemp(WeatherPlugin.currentTemperatureC, "--")
    readonly property string cond: WeatherPlugin.loading ? qsTr("正在加载…") : (WeatherPlugin.currentWeatherText || qsTr("未知"))
    readonly property string loc: WeatherPlugin.locationName || qsTr("位置")
    readonly property string iconName: WeatherPlugin.currentIconName || "cloud"
    readonly property string feelsLike: qsTr("体感温度：") + fmtTemp(WeatherPlugin.currentFeelsLikeC, "--")
    readonly property string humidity: qsTr("湿度：") + fmtPercent(WeatherPlugin.currentRelativeHumidity)
    readonly property bool loadingState: WeatherPlugin.loading || !WeatherPlugin.hasValidData
    readonly property bool veryCompact: root.availableHeight < Metrics.lockVeryCompactBreakpoint
    readonly property bool showTitle: root.availableHeight >= Metrics.lockCompactBreakpoint
    readonly property bool allowForecast: root.availableHeight >= Metrics.lockForecastBreakpoint
    readonly property bool showSkeletonForecast: root.loadingState && root.allowForecast
    readonly property bool showForecast: WeatherPlugin.hasValidData && root.allowForecast && WeatherPlugin.hourlyForecast.count() > 0
    readonly property int forecastCount: root.availableHeight < Metrics.lockFetchExpandedBreakpoint ? 3 : root.width < 360 ? 4 : 5
    readonly property int forecastSpacing: root.width < 400 ? Metrics.spacingM : Metrics.spacingXL
    readonly property int forecastFontSize: root.width < 400 ? 18 : 20
    readonly property int forecastIconSize: root.width < 400 ? 50 : 56
    readonly property int contentMargin: root.veryCompact ? Metrics.lockOuterPadding : Metrics.lockOuterPadding * 2
    property real skeletonPulse: 0

    function validNumber(value) {
        return typeof value === "number" && isFinite(value);
    }

    function fmtTemp(value, fallback) {
        if (!WeatherPlugin.hasValidData || !validNumber(value))
            return fallback;

        return Math.round(UiPreferences.weatherTemperature(value)) + "°";
    }

    function fmtPercent(value) {
        if (!WeatherPlugin.hasValidData || !validNumber(value))
            return "--";

        return Math.round(value) + "%";
    }

    function hourLabel(value) {
        const epoch = Number(value || 0);
        const date = new Date(epoch > 1e+11 ? epoch : epoch * 1000);
        if (isNaN(date.getTime()))
            return "--";

        const hour = date.getHours();
        if (!UiPreferences.useTwelveHourClock)
            return String(hour).padStart(2, "0") + ":00";

        if (hour === 0)
            return "12 AM";

        if (hour === 12)
            return "12 PM";

        return (hour > 12 ? hour - 12 : hour).toString().padStart(2, "0") + (hour > 12 ? " PM" : " AM");
    }

    function forecastModel() {
        const count = Math.min(root.forecastCount, WeatherPlugin.hourlyForecast.count());
        const items = [];
        for (let i = 0; i < count; i += 1) items.push(WeatherPlugin.hourlyForecast.get(i))
        return items;
    }

    Layout.fillWidth: true
    implicitHeight: Math.max(contentLayout.implicitHeight + contentLayout.anchors.topMargin + contentLayout.anchors.bottomMargin, skeletonLayout.implicitHeight + skeletonLayout.anchors.topMargin + skeletonLayout.anchors.bottomMargin)
    color: Appearance.colors.colLayer2
    radius: Metrics.lockCardRadius
    clip: true
    Component.onCompleted: {
        if (!WeatherPlugin.hasValidData)
            WeatherPlugin.refresh();

    }

    ColumnLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.leftMargin: root.contentMargin
        anchors.rightMargin: root.contentMargin
        anchors.topMargin: root.showTitle ? Metrics.lockOuterPadding * 2 : Metrics.lockOuterPadding
        anchors.bottomMargin: root.showForecast ? Metrics.lockOuterPadding * 2 : Metrics.lockOuterPadding
        opacity: root.loadingState ? 0 : 1
        scale: root.loadingState ? 0.98 : 1
        spacing: 7

        Text {
            visible: root.showTitle
            text: qsTr("天气")
            color: Appearance.colors.colPrimary
            font.family: Fonts.ui
            font.pixelSize: 36
            font.weight: 500
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: -Metrics.lockOuterPadding
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 22

            Text {
                text: root.iconName
                color: Appearance.colors.colSecondary
                font.family: Fonts.materialSymbolsOutlined
                font.pixelSize: root.width < 320 ? 72 : 92
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 9

                Text {
                    Layout.fillWidth: true
                    text: root.width <= 320 ? root.temp + "  " + root.cond : root.cond
                    color: Appearance.colors.colSecondary
                    font.family: Fonts.ui
                    font.pixelSize: 24
                    font.weight: 500
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.humidity
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 17
                    elide: Text.ElideRight
                }

            }

            ColumnLayout {
                visible: root.width > 360
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 7
                spacing: 9

                Text {
                    Layout.fillWidth: true
                    text: root.temp
                    color: Appearance.colors.colPrimary
                    font.family: Fonts.ui
                    font.pixelSize: 38
                    font.weight: 500
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }

                Text {
                    Layout.fillWidth: true
                    text: root.feelsLike
                    visible: !root.veryCompact
                    color: Appearance.colors.colOutline
                    font.family: Fonts.ui
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }

            }

        }

        RowLayout {
            visible: root.showForecast
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: root.forecastSpacing

            Repeater {
                model: root.forecastModel()

                ColumnLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.hourLabel(parent.modelData.time)
                        color: Appearance.colors.colOutline
                        font.family: Fonts.ui
                        font.pixelSize: root.forecastFontSize
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: root.forecastIconSize + 8
                        text: parent.modelData.iconName || "cloud_alert"
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.materialSymbolsOutlined
                        font.pixelSize: root.forecastIconSize
                        font.weight: 500
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.fmtTemp(parent.modelData.temperatureC, "--")
                        color: Appearance.colors.colSecondary
                        font.family: Fonts.ui
                        font.pixelSize: root.forecastFontSize
                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
            }

        }

    }

    Item {
        id: skeleton

        anchors.fill: parent
        z: 2
        opacity: root.loadingState ? 1 : 0
        scale: root.loadingState ? 1 : 0.98
        visible: opacity > 0

        ColumnLayout {
            id: skeletonLayout

            anchors.fill: parent
            anchors.leftMargin: root.contentMargin
            anchors.rightMargin: root.contentMargin
            anchors.topMargin: root.showTitle ? Metrics.lockOuterPadding * 2 : Metrics.lockOuterPadding
            anchors.bottomMargin: root.showSkeletonForecast ? Metrics.lockOuterPadding * 2 : Metrics.lockOuterPadding
            spacing: 7

            SkeletonBlock {
                Layout.preferredWidth: 128
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: -Metrics.lockOuterPadding
                visible: root.showTitle
                pulse: root.skeletonPulse
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                SkeletonBlock {
                    Layout.preferredWidth: root.width < 320 ? 72 : 92
                    Layout.preferredHeight: root.width < 320 ? 72 : 92
                    Layout.alignment: Qt.AlignVCenter
                    radius: Metrics.lockCardRadiusSmall
                    pulse: root.skeletonPulse
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 9

                    SkeletonBlock {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        pulse: root.skeletonPulse
                    }

                    SkeletonBlock {
                        Layout.preferredWidth: Math.max(90, parent.width * 0.7)
                        Layout.preferredHeight: 18
                        pulse: root.skeletonPulse
                    }

                }

                ColumnLayout {
                    visible: root.width > 360
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 7
                    spacing: 9

                    SkeletonBlock {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 38
                        pulse: root.skeletonPulse
                    }

                    SkeletonBlock {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 18
                        pulse: root.skeletonPulse
                    }

                }

            }

            RowLayout {
                visible: root.showSkeletonForecast
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: root.forecastSpacing

                Repeater {
                    model: root.forecastCount

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        SkeletonBlock {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            pulse: root.skeletonPulse
                        }

                        SkeletonBlock {
                            Layout.preferredWidth: root.forecastIconSize
                            Layout.preferredHeight: root.forecastIconSize
                            Layout.alignment: Qt.AlignHCenter
                            radius: Metrics.lockCardRadiusSmall
                            pulse: root.skeletonPulse
                        }

                        SkeletonBlock {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignHCenter
                            pulse: root.skeletonPulse
                        }

                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
            }

        }

    }

    Timer {
        running: true
        repeat: true
        interval: 900000
        onTriggered: WeatherPlugin.refresh()
    }

    SequentialAnimation on skeletonPulse {
        running: root.loadingState
        loops: Animation.Infinite

        NumberAnimation {
            to: 1
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }

        NumberAnimation {
            to: 0
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }

    }

    component SkeletonBlock: Rectangle {
        property real pulse: 0

        color: Appearance.colors.colOnSurfaceVariant
        opacity: 0.14 + pulse * 0.12
        radius: 8
    }

}
