import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common

TabBar {
    id: root

    property real indicatorPadding: 8
    property real leadingIndex: currentIndex
    property real trailingIndex: currentIndex

    Layout.fillWidth: true
    implicitHeight: 48

    Behavior on leadingIndex {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutSine
        }
    }

    Behavior on trailingIndex {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutSine
        }
    }

    background: Item {
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (event.angleDelta.y < 0)
                    root.incrementCurrentIndex();
                else if (event.angleDelta.y > 0)
                    root.decrementCurrentIndex();
            }
        }

        Rectangle {
            id: activeIndicator

            readonly property real baseWidth: root.count > 0 ? root.width / root.count : root.width

            z: 2
            anchors.bottom: parent.bottom
            height: 3
            x: Math.min(root.leadingIndex, root.trailingIndex) * baseWidth + root.indicatorPadding
            width: ((Math.max(root.leadingIndex, root.trailingIndex) + 1) * baseWidth - root.indicatorPadding) - x
            topLeftRadius: height
            topRightRadius: height
            color: Appearance.colors.colPrimary
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Appearance.colors.colOutlineVariant
        }
    }
}
