pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool showAddDialog: false
    readonly property int dialogMargins: 20
    readonly property int fabSize: 48
    readonly property int fabMargins: 14
    readonly property var tabs: [
        { "icon": "checklist", "name": "Unfinished" },
        { "icon": "check_circle", "name": "Done" }
    ]

    focus: true

    function addTask() {
        if (!TodoService.addTask(todoInput.text))
            return;

        todoInput.text = "";
        root.showAddDialog = false;
        tabBar.setCurrentIndex(0);
    }

    onShowAddDialogChanged: {
        if (showAddDialog) {
            Qt.callLater(() => todoInput.forceActiveFocus());
        } else {
            todoInput.text = "";
            Qt.callLater(() => root.forceActiveFocus());
        }
    }

    Keys.onPressed: event => {
        if (event.modifiers === Qt.NoModifier
                && (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)) {
            if (event.key === Qt.Key_PageDown)
                tabBar.incrementCurrentIndex();
            else
                tabBar.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_N) {
            root.showAddDialog = true;
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && root.showAddDialog) {
            root.showAddDialog = false;
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ToolSecondaryTabBar {
            id: tabBar

            Layout.fillWidth: true

            onCurrentIndexChanged: {
                if (swipeView.currentIndex !== currentIndex)
                    swipeView.setCurrentIndex(currentIndex);
            }

            Repeater {
                model: root.tabs

                delegate: ToolSecondaryTabButton {
                    required property var modelData

                    buttonText: modelData.name
                    buttonIcon: modelData.icon
                }
            }
        }

        SwipeView {
            id: swipeView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 10
            spacing: 10
            clip: true
            interactive: !root.showAddDialog

            onCurrentIndexChanged: {
                if (tabBar.currentIndex !== currentIndex)
                    tabBar.setCurrentIndex(currentIndex);
            }

            TaskList {
                listBottomPadding: root.fabSize + root.fabMargins * 2
                emptyPlaceholderIcon: "check_circle"
                emptyPlaceholderText: "Nothing here!"
                taskList: TodoService.list
                    .map((item, index) => Object.assign({}, item, { "originalIndex": index }))
                    .filter(item => !item.done)
            }

            TaskList {
                listBottomPadding: root.fabSize + root.fabMargins * 2
                emptyPlaceholderIcon: "checklist"
                emptyPlaceholderText: "Finished tasks will go here"
                taskList: TodoService.list
                    .map((item, index) => Object.assign({}, item, { "originalIndex": index }))
                    .filter(item => item.done)
            }
        }
    }

    StyledRectangularShadow {
        target: fabButton
        z: 10
    }

    MaterialRippleButton {
        id: fabButton

        property real radius: buttonRadius

        z: 11
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins
        implicitWidth: root.fabSize
        implicitHeight: root.fabSize
        buttonRadius: Appearance.rounding.normal
        colBackground: Appearance.colors.colPrimaryContainer
        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
        colRipple: Appearance.colors.colPrimaryContainerActive
        Accessible.name: "Add task"
        onClicked: root.showAddDialog = true

        contentItem: MaterialSymbol {
            text: "add"
            iconSize: 26
            color: Appearance.colors.colOnPrimaryContainer
        }
    }

    Item {
        z: 20
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.showAddDialog ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                propagateComposedEvents: false
            }
        }

        Rectangle {
            id: dialog

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: root.dialogMargins
            implicitHeight: dialogColumn.implicitHeight
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3surfaceContainerHigh

            ColumnLayout {
                id: dialogColumn

                anchors.fill: parent
                spacing: 16

                Text {
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    text: "Add task"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                MaterialTextField {
                    id: todoInput

                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    implicitHeight: 56
                    focus: root.showAddDialog
                    placeholderText: "Task description"
                    font.family: Sizes.fontFamily
                    font.pixelSize: 14
                    wrapMode: TextEdit.NoWrap
                    onAccepted: root.addTask()
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    spacing: 5

                    DialogActionButton {
                        text: "Cancel"
                        onClicked: root.showAddDialog = false
                    }

                    DialogActionButton {
                        text: "Add"
                        filled: true
                        enabled: todoInput.text.trim().length > 0
                        opacity: enabled ? 1 : 0.38
                        onClicked: root.addTask()
                    }
                }
            }
        }
    }
}
