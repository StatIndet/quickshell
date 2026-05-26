import QtQuick
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property string viewName: "info"
    property string iconName: "notifications"
    property color activeColor: Appearance.colors.colSecondaryContainer
    property color activeContentColor: Appearance.colors.colOnSecondaryContainer
    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool isActive: WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === viewName
    readonly property int buttonSize: 28
    readonly property int hoverButtonSize: 34

    implicitHeight: buttonSize
    implicitWidth: buttonSize

    Rectangle {
        id: background
        anchors.centerIn: parent
        width: root.isHovered ? root.hoverButtonSize : root.buttonSize
        height: width
        radius: height / 2
        color: root.activeColor

        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: root.iconName
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.isHovered ? 18 : 16
            color: root.activeContentColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on font.pixelSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
    }

    function toggleView() {
        if (WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === viewName) {
            WidgetState.leftSidebarOpen = false;
            return;
        }

        WidgetState.leftSidebarView = viewName;
        WidgetState.leftSidebarOpen = true;
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleView()
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: root.viewName === "sys" ? "系统监控" : "通知中心"
    }
}
