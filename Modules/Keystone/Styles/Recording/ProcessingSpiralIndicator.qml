import QtQuick

Item {
    id: root

    required property bool running
    required property color dotColor
    property int frameIndex: 0
    readonly property var spiralOrder: [2, 1, 0, 3, 6, 7, 8, 5, 4]

    function spiralPosition(dotIndex) {
        return spiralOrder.indexOf(dotIndex);
    }

    implicitWidth: 15
    implicitHeight: 15
    onRunningChanged: {
        if (!running)
            frameIndex = 0;

    }

    Timer {
        interval: 90
        repeat: true
        running: root.running
        onTriggered: root.frameIndex = (root.frameIndex + 1) % (root.spiralOrder.length * 2 + 1)
    }

    Grid {
        anchors.centerIn: parent
        rows: 3
        columns: 3
        spacing: 3

        Repeater {
            model: 9

            delegate: Rectangle {
                required property int index
                readonly property int spiralPosition: root.spiralPosition(index)
                readonly property bool lightingPhase: root.frameIndex < root.spiralOrder.length
                readonly property int activeStep: lightingPhase ? root.frameIndex : root.spiralOrder.length - 1
                readonly property int fadeStep: lightingPhase ? 0 : root.frameIndex - root.spiralOrder.length
                readonly property int trailDistance: activeStep - spiralPosition
                readonly property bool illuminated: lightingPhase ? spiralPosition <= activeStep : spiralPosition >= fadeStep

                width: 3
                height: 3
                radius: width / 2
                color: root.dotColor
                opacity: !illuminated ? 0.18 : trailDistance === 0 ? 1 : trailDistance === 1 ? 0.8 : trailDistance === 2 ? 0.64 : 0.48
                scale: trailDistance === 0 ? 1.35 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}
