import QtQuick

Item {
    id: root

    property alias text: label.text
    property alias font: label.font
    property alias color: label.color
    readonly property real overflow: Math.max(0, label.implicitWidth - width)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    function restartScroll() {
        scroll.stop();
        label.x = 0;
        if (overflow > 0 && visible)
            scroll.start();
    }

    onOverflowChanged: Qt.callLater(restartScroll)
    onVisibleChanged: restartScroll()

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        onTextChanged: Qt.callLater(root.restartScroll)
    }

    SequentialAnimation {
        id: scroll
        loops: Animation.Infinite
        PauseAnimation {
            duration: 1800
        }
        NumberAnimation {
            target: label
            property: "x"
            to: -root.overflow
            duration: Math.max(1800, root.overflow * 35)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
        }
        PauseAnimation {
            duration: 1800
        }
        NumberAnimation {
            target: label
            property: "x"
            to: 0
            duration: Math.max(1800, root.overflow * 35)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
        }
    }
}
