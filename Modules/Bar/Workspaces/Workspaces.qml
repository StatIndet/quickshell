import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Clavis.Niri 1.0
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property string screenName: ""
    readonly property bool hasMultipleOutputs: Niri.outputs.count > 1

    implicitHeight: 36
    implicitWidth: layout.width + 24

    function acceptsOutput(outputName) {
        if (root.screenName === "")
            return true
        if (!root.hasMultipleOutputs && outputName === "")
            return true
        return outputName === root.screenName
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: height / 2
        visible: false
    }

    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Qt.alpha(Appearance.colors.colShadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: Niri.workspaces

            delegate: Item {
                id: delegateRoot

                property bool belongsToScreen: root.acceptsOutput(model.output)
                property bool active: model.isActive
                property bool hasWindows: model.windowCount > 0
                property bool isHovered: mouseArea.containsMouse

                visible: belongsToScreen
                implicitWidth: !belongsToScreen ? 0 : ((active || isHovered) ? 32 : 12)
                implicitHeight: belongsToScreen ? 12 : 0

                Behavior on implicitWidth {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.implicitWidth
                    height: parent.implicitHeight
                    radius: height / 2

                    color: delegateRoot.active ? Appearance.colors.colPrimary
                         : delegateRoot.hasWindows ? Appearance.colors.colOnSurface
                         : delegateRoot.isHovered ? Appearance.colors.colLayer2Hover
                         : Appearance.colors.colLayer4

                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.focusWorkspaceById(model.id)
                }

                PopupToolTip {
                    extraVisibleCondition: mouseArea.containsMouse
                    text: "工作区 " + model.id + (delegateRoot.hasWindows ? "\n窗口: " + model.windowCount : "")
                }
            }
        }
    }
}
