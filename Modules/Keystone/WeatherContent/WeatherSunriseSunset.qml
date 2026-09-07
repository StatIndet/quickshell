import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Components

Item {
    id: root

    implicitHeight: childrenRect.height
    implicitWidth: 300

    property var sunriseTime: 0
    property var sunsetTime: 0
    property real progress: 0

    function updateProgress() {
        const now = new Date().getTime() / 1000;
        let p = 0;
        if (root.sunriseTime > 0 && root.sunsetTime > 0) {
            const totalDuration = root.sunsetTime - root.sunriseTime;
            if (totalDuration > 0) {
                p = (now - root.sunriseTime) / totalDuration;
            }
        }
        root.progress = Math.max(0, Math.min(1, p));
    }

    Connections {
        target: WeatherPlugin
        function onDataChanged() {
            if (WeatherPlugin.hasValidData && WeatherPlugin.current) {
                root.sunriseTime = WeatherPlugin.current().sunrise || 0;
                root.sunsetTime = WeatherPlugin.current().sunset || 0;
            } else {
                const today = WeatherPlugin.dailyForecast.count() > 0 ? WeatherPlugin.dailyForecast.get(0) :
                                                                        null;
                if (today) {
                    root.sunriseTime = today.sunrise || 0;
                    root.sunsetTime = today.sunset || 0;
                }
            }
            updateProgress();
        }
    }

    Component.onCompleted: {
        if (WeatherPlugin.hasValidData && WeatherPlugin.current) {
            root.sunriseTime = WeatherPlugin.current().sunrise || 0;
            root.sunsetTime = WeatherPlugin.current().sunset || 0;
        } else {
            const today = WeatherPlugin.dailyForecast.count() > 0 ? WeatherPlugin.dailyForecast.get(0) : null;
            if (today) {
                root.sunriseTime = today.sunrise || 0;
                root.sunsetTime = today.sunset || 0;
            }
        }
        updateProgress();
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: updateProgress()
    }

    Item {
        anchors.fill: parent
        anchors.margins: 4

        // Top labels (Sunrise/Sunset icons and text)
        Item {
            id: topLabels
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48

            ColumnLayout {
                anchors.left: parent.left
                spacing: 2

                MaterialSymbol {
                    text: "wb_twilight"
                    fill: 1
                    iconSize: 26
                    color: Appearance.colors.colOnSurface
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: qsTr("Sunrise")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            ColumnLayout {
                anchors.right: parent.right
                spacing: 2

                MaterialSymbol {
                    text: "wb_twilight"
                    fill: 1
                    iconSize: 26
                    color: Appearance.colors.colOnSurface
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: qsTr("Sunset")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // Progress Bar
        Item {
            id: progressBar
            anchors.top: topLabels.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24

            MaterialSymbol {
                id: sunIcon
                text: "light_mode"
                fill: 1
                iconSize: 28
                color: Appearance.colors.colOnSurface
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, (root.progress * parent.width) - (width / 2)))
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: sunIcon.left
                anchors.rightMargin: 6
                height: 10
                radius: 5
                color: Appearance.colors.colOnSurface
                opacity: 0.25
                visible: width > 0
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: sunIcon.right
                anchors.leftMargin: 6
                anchors.right: parent.right
                height: 10
                radius: 5
                color: Appearance.colors.colOnSurface
                visible: width > 0
            }
        }

        // Bottom times
        Item {
            anchors.top: progressBar.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            height: 32

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.sunriseTime > 0 ? Qt.formatDateTime(new Date(root.sunriseTime * 1000), "HH:mm") :
                                             "--:--"
                color: Appearance.colors.colOnSurface
                font.family: Fonts.numeric
                font.pixelSize: 32
                font.weight: Font.Medium
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.sunsetTime > 0 ? Qt.formatDateTime(new Date(root.sunsetTime * 1000), "HH:mm") :
                                            "--:--"

                color: Appearance.colors.colOnSurface
                font.family: Fonts.numeric
                font.pixelSize: 32
                font.weight: Font.Medium
            }
        }
    }
}
