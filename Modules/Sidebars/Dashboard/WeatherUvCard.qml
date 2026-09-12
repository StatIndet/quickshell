import QtQuick

Item {
    id: root

    property real value: NaN
    property string level: "--"
    property int activeIndex: -1
    property bool animationEnabled: false
    property bool animationActive: true

    WeatherBlob {
        anchors.fill: parent
        value: root.value
        level: root.level
        activeIndex: root.activeIndex
        title: qsTr("UV index")
        animationEnabled: root.animationEnabled
        animationActive: root.animationActive
    }
}
