import QtQuick

Item {
    Loader {
        anchors.fill: parent
        asynchronous: true
        source: Qt.resolvedUrl("WeatherApiSettings.qml")
    }
}
