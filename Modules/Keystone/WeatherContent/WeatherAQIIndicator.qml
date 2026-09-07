import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services
import qs.Common

Item {
    id: root

    implicitHeight: layout.implicitHeight
    implicitWidth: 300

    property int aqi: 0

    function calculateAQI(pm25) {
        if (pm25 === undefined || pm25 === null)
            return 0;
        const c = pm25;
        let index;
        if (c <= 12.0) {
            index = (50 - 0) / (12.0 - 0.0) * (c - 0.0) + 0;
        } else if (c <= 35.4) {
            index = (100 - 51) / (35.4 - 12.1) * (c - 12.1) + 51;
        } else if (c <= 55.4) {
            index = (150 - 101) / (55.4 - 35.5) * (c - 35.5) + 101;
        } else if (c <= 150.4) {
            index = (200 - 151) / (150.4 - 55.5) * (c - 55.5) + 151;
        } else if (c <= 250.4) {
            index = (300 - 201) / (250.4 - 150.5) * (c - 150.5) + 201;
        } else if (c <= 350.4) {
            index = (400 - 301) / (350.4 - 250.5) * (c - 250.5) + 301;
        } else {
            index = (500 - 401) / (500.4 - 350.5) * (c - 350.5) + 401;
        }
        return Math.min(500, Math.round(index));
    }

    function getAqiDescription(aqiValue) {
        if (aqiValue <= 50)
            return qsTr("Excellent");
        if (aqiValue <= 100)
            return qsTr("Good");
        if (aqiValue <= 150)
            return qsTr("Unhealthy for sensitive groups");
        if (aqiValue <= 200)
            return qsTr("Unhealthy");
        if (aqiValue <= 300)
            return qsTr("Very unhealthy");
        return qsTr("Hazardous");
    }

    Connections {
        target: WeatherPlugin
        function onDataChanged() {
            if (WeatherPlugin.hasValidData && WeatherPlugin.currentAirQuality) {
                root.aqi = calculateAQI(WeatherPlugin.currentAirQuality.pm25 || 0);
            }
            canvas.requestPaint();
        }
    }

    Component.onCompleted: {
        if (WeatherPlugin.hasValidData && WeatherPlugin.currentAirQuality) {
            root.aqi = calculateAQI(WeatherPlugin.currentAirQuality.pm25 || 0);
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: qsTr("Air quality")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: getAqiDescription(root.aqi) + " " + root.aqi
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }

        Canvas {
            id: canvas
            Layout.fillWidth: true
            Layout.preferredHeight: 12
            Layout.alignment: Qt.AlignBottom

            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                const barHeight = 8;
                const yPos = (height - barHeight) / 2;
                const radius = barHeight / 2;

                // Map AQI to 0-1 for position (assume max is 300 for normal display, cap at 0.95)
                const ratio = Math.max(0.02, Math.min(0.98, root.aqi / 300.0));
                // The gap center
                const indicatorX = Math.max(radius, Math.min(width - radius, width * ratio));

                const gapWidth = 14;
                const gapLeft = indicatorX - gapWidth / 2;
                const gapRight = indicatorX + gapWidth / 2;

                // Create gradient
                const grad = ctx.createLinearGradient(0, 0, width, 0);
                grad.addColorStop(0.0, "#00e400"); // Green
                grad.addColorStop(0.16, "#ffff00"); // Yellow
                grad.addColorStop(0.33, "#ff7e00"); // Orange
                grad.addColorStop(0.5, "#ff0000"); // Red
                grad.addColorStop(0.66, "#8f3f97"); // Purple
                grad.addColorStop(1.0, "#7e0023"); // Maroon

                // Draw left part
                if (gapLeft > radius * 2) {
                    ctx.beginPath();
                    ctx.moveTo(radius, yPos);
                    ctx.lineTo(gapLeft - radius, yPos);
                    ctx.arc(gapLeft - radius, yPos + radius, radius, -Math.PI / 2, Math.PI / 2);
                    ctx.lineTo(radius, yPos + barHeight);
                    ctx.arc(radius, yPos + radius, radius, Math.PI / 2, Math.PI * 1.5);
                    ctx.fillStyle = grad;
                    ctx.fill();
                }

                // Draw right part
                if (gapRight < width - radius * 2) {
                    ctx.beginPath();
                    ctx.moveTo(gapRight + radius, yPos);
                    ctx.lineTo(width - radius, yPos);
                    ctx.arc(width - radius, yPos + radius, radius, -Math.PI / 2, Math.PI / 2);
                    ctx.lineTo(gapRight + radius, yPos + barHeight);
                    ctx.arc(gapRight + radius, yPos + radius, radius, Math.PI / 2, Math.PI * 1.5);
                    ctx.fillStyle = grad;
                    ctx.fill();
                }

                // Draw circle indicator
                ctx.beginPath();
                ctx.arc(indicatorX, yPos + radius, radius, 0, Math.PI * 2);
                ctx.fillStyle = grad; // It will pick the color at this position roughly by using the gradient
                ctx.fill();
            }
        }
    }
}
