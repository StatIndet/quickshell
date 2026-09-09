import QtQuick
import qs.Common
import qs.Components

Rectangle {
    id: root

    property int value: 0
    property int from: 0
    property int to: 100
    property int stepSize: 1
    // Pause value requests without canceling a held pointer during async saves.
    property bool busy: false

    signal valueModified(int value)

    function setValue(nextValue) {
        if (!root.enabled || root.busy)
            return;
        const normalized = Math.max(root.from, Math.min(root.to, Math.round(nextValue)));
        if (normalized === root.value)
            return;

        root.valueModified(normalized);
    }

    implicitWidth: 180
    implicitHeight: Metrics.controlHeightL
    radius: Appearance.rounding.full
    color: Appearance.colors.colLayer2

    StepButton {
        anchors.left: parent.left
        increase: false
    }

    Text {
        anchors.centerIn: parent
        text: root.value
        color: Appearance.colors.colOnLayer2
        font.family: Fonts.numeric
        font.pixelSize: Typography.titleLarge.pixelSize
        font.weight: Font.Medium
    }

    StepButton {
        anchors.right: parent.right
        increase: true
    }

    component StepButton: Rectangle {
        id: button

        required property bool increase
        readonly property bool canChange: increase ? root.value < root.to : root.value > root.from

        width: 54
        height: root.height
        topLeftRadius: !button.increase ? root.radius : 0
        bottomLeftRadius: !button.increase ? root.radius : 0
        topRightRadius: button.increase ? root.radius : 0
        bottomRightRadius: button.increase ? root.radius : 0
        color: !canChange ? "transparent" : pointer.pressed ? Appearance.colors.colLayer2Active :
                                                              pointer.containsMouse
                                                              ? Appearance.colors.colLayer2Hover :
                                                                "transparent"
        opacity: canChange ? 1 : 0.38
        Accessible.role: Accessible.Button
        Accessible.name: increase ? qsTr("Increase") : qsTr("Decrease")
        Accessible.onPressAction: root.setValue(root.value + (increase ? root.stepSize : -root.stepSize))

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.increase ? "add" : "remove"
            iconSize: Metrics.iconM
            color: Appearance.colors.colOnLayer2
            font.weight: Font.Medium
        }

        MouseArea {
            id: pointer

            property bool repeated: false

            anchors.fill: parent
            enabled: button.canChange
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: repeated = false
            onClicked: {
                if (!repeated)
                    root.setValue(root.value + (button.increase ? root.stepSize : -root.stepSize));
            }

            Timer {
                interval: pointer.repeated ? 100 : 400
                repeat: true
                running: pointer.pressed && pointer.containsMouse && pointer.enabled && pointer.visible
                onTriggered: {
                    pointer.repeated = true;
                    root.setValue(root.value + (button.increase ? root.stepSize : -root.stepSize));
                }
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }
    }
}
