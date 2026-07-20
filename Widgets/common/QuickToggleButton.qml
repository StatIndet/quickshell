import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root

    readonly property bool materialQuickToggleButton: true
    property string iconName: "settings"
    property string title: ""
    property string subtitle: ""
    property string tooltipText: ""
    property bool toggled: false
    property bool expanded: false
    property bool editMode: false
    property bool available: true
    property bool hasAltAction: false
    property bool bounce: true
    property real collapsedSize: 56
    property real expandedWidth: -1
    property real baseCellWidth: collapsedSize
    property real baseCellHeight: collapsedSize
    property real cellSpacing: 6
    property int cellSize: expanded ? 2 : 1
    property real padding: 6

    property var parentGroup: root.parent
    readonly property int indexInParent: parentGroup && parentGroup.indexOfButton ? parentGroup.indexOfButton(root) : -1
    readonly property int clickIndex: parentGroup && parentGroup.clickIndex !== undefined ? parentGroup.clickIndex : -1
    readonly property bool isAtSide: indexInParent === 0 || (parentGroup && indexInParent === parentGroup.childrenCount - 1)
    readonly property bool expandedSplitStyle: expanded
    readonly property bool expandedAltAction: expandedSplitStyle && hasAltAction && !editMode
    property bool down: false
    property bool suppressRelease: false
    property real baseWidth: (expanded && expandedWidth > 0) ? expandedWidth : baseCellWidth * cellSize + cellSpacing * (cellSize - 1)
    property real baseHeight: baseCellHeight
    property real clickedWidth: baseWidth + (isAtSide ? 10 : 20)
    property real clickedHeight: baseHeight

    signal triggered()
    signal altTriggered()
    signal wheelMoved(int delta)

    Layout.fillWidth: bounce && clickIndex >= 0 && indexInParent >= clickIndex - 1 && indexInParent <= clickIndex + 1
    Layout.fillHeight: bounce && clickIndex >= 0 && indexInParent >= clickIndex - 1 && indexInParent <= clickIndex + 1

    implicitWidth: down && bounce ? clickedWidth : baseWidth
    implicitHeight: down && bounce ? clickedHeight : baseHeight
    radius: down ? Appearance.rounding.normal : toggled ? Appearance.rounding.large : height / 2
    opacity: available || editMode ? 1.0 : 0.45
    clip: true
    enabled: available || editMode

    readonly property color textColor: toggled && !expandedSplitStyle && enabled ? Appearance.colors.colOnPrimary : Appearance.transparentize(Appearance.colors.colOnLayer2, enabled ? 0 : 0.7)
    readonly property color iconColor: expanded ? (toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3) : textColor
    readonly property color backgroundColor: {
        if (!root.enabled)
            return Appearance.colors.colLayer2Disabled;
        if (root.toggled && !root.expandedSplitStyle)
            return root.down ? Appearance.colors.colPrimaryActive : buttonMouse.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary;
        return root.down ? Appearance.colors.colLayer2Active : buttonMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2;
    }

    color: backgroundColor

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    Behavior on radius {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.clickBounce.duration
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.clickBounce.duration
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
    }
    Behavior on baseWidth {
        NumberAnimation {
            duration: Appearance.animation.expressiveDefaultSpatial.duration
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }
    }
    Behavior on baseHeight {
        NumberAnimation {
            duration: Appearance.animation.expressiveDefaultSpatial.duration
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }
    }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    RowLayout {
        z: 1
        anchors.fill: parent
        anchors.leftMargin: root.expanded ? root.padding : 0
        anchors.rightMargin: root.expanded ? root.padding : 0
        anchors.topMargin: root.expanded ? root.padding : 0
        anchors.bottomMargin: root.expanded ? root.padding : 0
        spacing: 4

        MouseArea {
            id: iconMouseArea

            Layout.preferredWidth: root.expanded ? height : root.width
            Layout.preferredHeight: root.expanded ? root.height - root.padding * 2 : root.height
            Layout.alignment: Qt.AlignVCenter
            acceptedButtons: root.expandedAltAction ? Qt.LeftButton : Qt.NoButton
            hoverEnabled: root.expandedAltAction
            cursorShape: root.expandedAltAction ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: root.triggered()

            Rectangle {
                id: iconBackground

                anchors.fill: parent
                radius: Math.max(0, root.radius - root.padding)
                color: root.expandedSplitStyle ? (root.toggled ? Appearance.colors.colPrimary : Appearance.colors.colLayer3) : "transparent"

                Behavior on radius {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveDefaultSpatial.duration
                        easing.type: Appearance.animation.expressiveDefaultSpatial.type
                        easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.iconName
                    iconSize: root.expanded ? 22 : 24
                    fill: root.toggled ? 1 : 0
                    color: root.iconColor

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.expandedAltAction
                    radius: iconBackground.radius
                    color: Appearance.transparentize(root.iconColor, iconMouseArea.pressed ? 0.88 : iconMouseArea.containsMouse ? 0.95 : 1)

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: -2
            visible: root.expanded

            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                color: root.textColor
                font.family: Sizes.fontFamily
                font.pixelSize: 13
                font.weight: 600
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.subtitle
                elide: Text.ElideRight
                color: root.textColor
                font.family: Sizes.fontFamily
                font.pixelSize: 12
                font.weight: 100
            }
        }
    }

    MouseArea {
        id: buttonMouse
        z: 0
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function setGroupClickIndex() {
            if (root.parentGroup && root.parentGroup.clickIndex !== undefined)
                root.parentGroup.clickIndex = root.indexInParent;
        }

        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                root.altTriggered();
                return;
            }
            if (root.editMode)
                return;
            root.suppressRelease = false;
            root.down = true;
            setGroupClickIndex();
        }

        onReleased: (event) => {
            root.down = false;
            if (event.button !== Qt.LeftButton)
                return;
            if (root.editMode)
                return;
            if (root.suppressRelease) {
                root.suppressRelease = false;
                return;
            }

            if (root.expandedAltAction)
                root.altTriggered();
            else
                root.triggered();
        }
        onCanceled: root.down = false
        onPressAndHold: {
            if (root.editMode)
                return;
            root.down = false;
            root.suppressRelease = true;
            root.altTriggered();
        }
        onWheel: (wheel) => {
            root.wheelMoved(wheel.angleDelta.y);
            wheel.accepted = true;
        }
    }

    StyledToolTip {
        extraVisibleCondition: root.tooltipText.length > 0 && (buttonMouse.containsMouse || iconMouseArea.containsMouse)
        text: root.tooltipText
    }
}
