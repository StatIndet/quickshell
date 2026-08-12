import Quickshell
import QtQuick
import QtQuick.Layouts
import Clavis.Niri
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property string screenName: ""
    property bool vertical: false
    property Item previewAnchorItem: null
    property var previewWorkspaceId: 0
    property bool previewRequested: false
    readonly property bool hasMultipleOutputs: Niri.outputs.count > 1

    implicitHeight: vertical ? layout.implicitHeight + 16 : Sizes.barPillThickness
    implicitWidth: vertical ? Sizes.barVisualThickness : layout.implicitWidth + 24

    function acceptsOutput(outputName) {
        if (root.screenName === "")
            return true
        if (!root.hasMultipleOutputs && outputName === "")
            return true
        return outputName === root.screenName
    }

    function showPreview(workspaceId) {
        root.previewRequested = false;
        root.previewAnchorItem = root;
        root.previewWorkspaceId = workspaceId;
        root.previewRequested = true;
    }

    function hidePreview() {
        root.previewRequested = false;
    }

    function dismissPreview() {
        root.previewRequested = false;
        root.previewAnchorItem = null;
    }

    TopBarPillBackground { anchors.fill: parent }

    GridLayout {
        id: layout
        anchors.centerIn: parent
        rowSpacing: 8
        columnSpacing: 8
        columns: root.vertical ? 1 : Math.max(1, Niri.workspaces.count)

        Repeater {
            model: Niri.workspaces

            delegate: Item {
                id: delegateRoot

                property bool belongsToScreen: root.acceptsOutput(model.output)
                property bool active: model.isActive
                property bool hasWindows: model.windowCount > 0
                property bool isHovered: mouseArea.containsMouse

                visible: belongsToScreen
                implicitWidth: !belongsToScreen ? 0
                    : root.vertical ? 12 : ((active || isHovered) ? 32 : 12)
                implicitHeight: !belongsToScreen ? 0
                    : root.vertical ? ((active || isHovered) ? 32 : 12) : 12

                Behavior on implicitWidth {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
                Behavior on implicitHeight {
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
                    onContainsMouseChanged: {
                        if (containsMouse && delegateRoot.hasWindows)
                            root.showPreview(model.id);
                        else if (!containsMouse)
                            root.hidePreview();
                    }
                    onClicked: {
                        root.dismissPreview();
                        Niri.focusWorkspaceById(model.id);
                    }
                }

                PopupToolTip {
                    extraVisibleCondition: mouseArea.containsMouse && !delegateRoot.hasWindows
                    text: qsTr("工作区 ") + model.id
                }
            }
        }
    }

    WorkspacePreview {
        id: workspacePreview

        anchorItem: root.previewAnchorItem
        workspaceId: root.previewWorkspaceId
        requestedVisible: root.previewRequested
        onDismissed: root.dismissPreview()
    }
}
