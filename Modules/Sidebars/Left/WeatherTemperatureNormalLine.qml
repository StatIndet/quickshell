import QtQuick

Item {
    id: root

    required property real temperatureC
    required property real domainMinimumC
    required property real domainMaximumC
    required property real chartTop
    required property real chartBottom
    required property string temperatureText
    required property string numericFontFamily
    required property string uiFontFamily
    property string normalText: qsTr("标准值")
    property color lineColor
    property color labelColor
    readonly property real lineY: chartBottom - (temperatureC - domainMinimumC) / (domainMaximumC - domainMinimumC) * (chartBottom - chartTop)

    y: lineY
    height: 1
    enabled: false
    Accessible.name: temperatureText + " " + qsTr("1991–2020 常年平均")

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: root.lineColor
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.bottom: parent.top
        anchors.bottomMargin: 3
        text: root.temperatureText
        color: root.labelColor
        font.family: root.numericFontFamily
        font.pixelSize: 11
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.bottom: parent.top
        anchors.bottomMargin: 3
        text: root.normalText
        color: root.labelColor
        font.family: root.uiFontFamily
        font.pixelSize: 11
        font.bold: true
    }

}
