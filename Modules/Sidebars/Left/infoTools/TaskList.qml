pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var taskList
    property string emptyPlaceholderIcon: "check_circle"
    property string emptyPlaceholderText: "Nothing here!"
    property int itemSpacing: 5
    property int itemPadding: 8
    property int listBottomPadding: 76

    StyledListView {
        id: listView

        anchors.fill: parent
        anchors.bottomMargin: root.listBottomPadding
        spacing: root.itemSpacing
        animateAppearance: true
        animateMovement: true

        model: ScriptModel {
            values: root.taskList
        }

        delegate: Item {
            id: taskItem

            required property var modelData

            width: ListView.view.width
            implicitHeight: taskCard.implicitHeight
            clip: true

            Rectangle {
                id: taskCard

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: taskColumn.implicitHeight
                color: Appearance.colors.colLayer2
                radius: Appearance.rounding.small

                ColumnLayout {
                    id: taskColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: root.itemPadding
                        text: taskItem.modelData.content
                        color: Appearance.colors.colOnLayer2
                        font.family: Sizes.fontFamily
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.bottomMargin: root.itemPadding
                        spacing: 4

                        Item {
                            Layout.fillWidth: true
                        }

                        ActionButton {
                            iconName: taskItem.modelData.done ? "remove_done" : "check"
                            accessibleName: taskItem.modelData.done ? "Mark unfinished" : "Mark done"
                            onClicked: {
                                if (taskItem.modelData.done)
                                    TodoService.markUnfinished(taskItem.modelData.originalIndex);
                                else
                                    TodoService.markDone(taskItem.modelData.originalIndex);
                            }
                        }

                        ActionButton {
                            iconName: "delete_forever"
                            accessibleName: "Delete task"
                            onClicked: TodoService.deleteItem(taskItem.modelData.originalIndex)
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.taskList.length === 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: root.emptyPlaceholderIcon
                iconSize: 55
                color: Appearance.colors.colOutline
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.emptyPlaceholderText
                color: Appearance.colors.colOutline
                font.family: Sizes.fontFamily
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    component ActionButton: MaterialRippleButton {
        required property string iconName
        required property string accessibleName

        implicitWidth: 30
        implicitHeight: 30
        buttonRadius: Appearance.rounding.small
        colBackground: Appearance.transparentize(Appearance.colors.colLayer2Hover, 1)
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        Accessible.name: accessibleName

        contentItem: MaterialSymbol {
            text: iconName
            iconSize: 20
            color: Appearance.colors.colOnLayer1
        }
    }
}
