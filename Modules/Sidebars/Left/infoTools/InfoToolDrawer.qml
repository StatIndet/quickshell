pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../../../Common/functions/DateFormat.js" as DateFormat

Rectangle {
    id: root

    property bool active: false
    readonly property bool collapsed: InfoDrawerState.collapsed
    readonly property int selectedTab: InfoDrawerState.selectedTab
    property int displayedTab: selectedTab
    property bool componentComplete: false
    property bool collapseTransitionRunning: false
    property date currentDate: new Date()

    readonly property var tabs: [
        {
            "name": qsTr("Calendar"),
            "icon": "calendar_month"
        },
        {
            "name": qsTr("To-do"),
            "icon": "done_outline"
        },
        {
            "name": qsTr("Timer"),
            "icon": "schedule"
        }
    ]

    implicitHeight: collapsed ? collapsedRow.implicitHeight : 350
    radius: Appearance.rounding.normal
    color: BlurService.opaqueBackgroundColor(Appearance.m3colors.m3surfaceContainerLow)
    clip: true
    focus: active

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.expressiveDefaultSpatial.duration
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }
    }

    function componentForIndex(index) {
        if (index === 1)
            return todoComponent;
        if (index === 2)
            return timerComponent;
        return calendarComponent;
    }

    function formattedDate(date) {
        return DateFormat.compactDate(date, I18nService.language, Qt.locale(), "ddd, dd/MM");
    }

    function focusCurrentPage() {
        if (!root.active)
            return;

        if (!root.collapsed && pageLoader.item)
            pageLoader.item.forceActiveFocus();
        else
            root.forceActiveFocus();
    }

    function setCollapsed(state) {
        if (state === root.collapsed)
            return;

        collapseTransition.stop();
        expandTransition.stop();
        root.collapseTransitionRunning = true;
        InfoDrawerState.setCollapsed(state);

        if (state)
            collapseTransition.restart();
        else
            expandTransition.restart();
    }

    function setSelectedTab(index) {
        InfoDrawerState.setSelectedTab(index);
    }

    onActiveChanged: {
        if (active)
            Qt.callLater(root.focusCurrentPage);
    }

    onCollapsedChanged: {
        if (!collapseTransitionRunning) {
            collapsedRow.opacity = collapsed ? 1 : 0;
            expandedRow.opacity = collapsed ? 0 : 1;
        }
        if (active)
            Qt.callLater(root.focusCurrentPage);
    }

    onSelectedTabChanged: {
        if (!componentComplete || selectedTab === displayedTab)
            return;

        pageSwitchAnimation.stop();
        pageSwitchAnimation.down = selectedTab > displayedTab;
        pageSwitchAnimation.restart();
    }

    Component.onCompleted: {
        root.componentComplete = true;
        root.displayedTab = root.selectedTab;
        collapsedRow.opacity = root.collapsed ? 1 : 0;
        expandedRow.opacity = root.collapsed ? 0 : 1;
    }

    Keys.onPressed: event => {
        if (event.modifiers !== Qt.ControlModifier)
            return;

        if (event.key === Qt.Key_PageDown) {
            root.setSelectedTab(Math.min(root.selectedTab + 1, root.tabs.length - 1));
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.setSelectedTab(Math.max(root.selectedTab - 1, 0));
            event.accepted = true;
        }
    }

    Timer {
        interval: 60000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    RowLayout {
        id: collapsedRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: Math.max(expandButton.implicitHeight + 20, collapsedText.implicitHeight + 20)
        spacing: 15
        visible: opacity > 0

        RippleButton {
            id: expandButton

            Layout.leftMargin: 10
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            implicitWidth: 34
            implicitHeight: 34
            buttonRadius: Appearance.rounding.full
            containerColor: Appearance.colors.colLayer2
            stateLayerColor: Appearance.colors.colLayer2Hover
            pressedStateLayerColor: Appearance.colors.colLayer2Active
            rippleColor: Appearance.colors.colOnLayer2
            Accessible.name: qsTr("Expand tools")
            onClicked: root.setCollapsed(false)

            contentItem: MaterialSymbol {
                text: "keyboard_arrow_up"
                iconSize: 22
                color: Appearance.colors.colOnLayer1
            }

            StyledToolTip {
                text: qsTr("Expand tools")
                alternativeVisibleCondition: expandButton.activeFocus
            }
        }

        Text {
            id: collapsedText

            readonly property int remainingTasks: TodoService.list.filter(task => !task.done).length

            Layout.fillWidth: true
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            text: root.formattedDate(root.currentDate) + qsTr("   •   %1 tasks").arg(remainingTasks)
            color: Appearance.colors.colOnLayer1
            font.family: Fonts.ui
            font.pixelSize: 15
            elide: Text.ElideRight
        }
    }

    RowLayout {
        id: expandedRow

        anchors.fill: parent
        spacing: 12
        visible: opacity > 0

        Item {
            Layout.fillHeight: true
            Layout.leftMargin: 10
            Layout.topMargin: 10
            implicitWidth: 56

            RippleButton {
                id: collapseButton

                anchors.left: parent.left
                anchors.top: parent.top
                implicitWidth: 34
                implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                containerColor: Appearance.colors.colLayer2
                stateLayerColor: Appearance.colors.colLayer2Hover
                pressedStateLayerColor: Appearance.colors.colLayer2Active
                rippleColor: Appearance.colors.colOnLayer2
                Accessible.name: qsTr("Collapse tools")
                onClicked: root.setCollapsed(true)

                contentItem: MaterialSymbol {
                    text: "keyboard_arrow_down"
                    iconSize: 22
                    color: Appearance.colors.colOnLayer1
                }

                StyledToolTip {
                    text: qsTr("Collapse tools")
                    alternativeVisibleCondition: collapseButton.activeFocus
                }
            }

            Item {
                id: tabRail

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: tabColumn.height

                Rectangle {
                    x: 0
                    y: root.selectedTab * 56 + 12
                    width: 56
                    height: 32
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colSecondaryContainer

                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveFastSpatial.duration
                            easing.type: Appearance.animation.expressiveFastSpatial.type
                            easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                        }
                    }
                }

                Column {
                    id: tabColumn

                    width: 56

                    Repeater {
                        model: root.tabs

                        delegate: RippleButton {
                            id: tabButton

                            required property int index
                            required property var modelData

                            implicitWidth: 56
                            implicitHeight: 56
                            toggled: root.selectedTab === index
                            buttonRadius: Appearance.rounding.full
                            containerColor: "transparent"
                            stateLayerColor: Appearance.colors.colLayer1Hover
                            pressedStateLayerColor: Appearance.colors.colLayer1Active
                            rippleColor: Appearance.colors.colLayer1
                            Accessible.name: modelData.name
                            onClicked: root.setSelectedTab(index)

                            contentItem: Item {
                                MaterialSymbol {
                                    id: tabIcon

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tabButton.modelData.icon
                                    iconSize: 24
                                    fill: tabButton.toggled ? 1 : 0
                                    color: tabButton.toggled ? Appearance.colors.colOnSecondaryContainer :
                                                               Appearance.colors.colOnLayer1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Appearance.animation.expressiveDefaultEffects.duration
                                            easing.type: Appearance.animation.expressiveDefaultEffects.type
                                            easing.bezierCurve:
                                                Appearance.animation.expressiveDefaultEffects.bezierCurve
                                        }
                                    }
                                }

                                Text {
                                    anchors.top: tabIcon.bottom
                                    anchors.topMargin: 1
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tabButton.modelData.name
                                    color: tabButton.toggled ? Appearance.colors.colOnSecondaryContainer :
                                                               Appearance.colors.colOnLayer1
                                    font.family: Fonts.ui
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: pageLoader

                anchors.fill: parent
                anchors.rightMargin: 10
                anchors.bottomMargin: -anchors.topMargin
                sourceComponent: root.componentForIndex(root.displayedTab)

                onLoaded: Qt.callLater(root.focusCurrentPage)
            }
        }
    }

    SequentialAnimation {
        id: collapseTransition

        NumberAnimation {
            target: expandedRow
            property: "opacity"
            to: 0
            duration: Appearance.animation.expressiveDefaultSpatial.duration / 2
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }

        NumberAnimation {
            target: collapsedRow
            property: "opacity"
            to: 1
            duration: Appearance.animation.expressiveDefaultSpatial.duration / 2
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }

        ScriptAction {
            script: {
                root.collapseTransitionRunning = false;
                Qt.callLater(root.focusCurrentPage);
            }
        }
    }

    SequentialAnimation {
        id: expandTransition

        NumberAnimation {
            target: collapsedRow
            property: "opacity"
            to: 0
            duration: Appearance.animation.expressiveDefaultSpatial.duration / 2
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }

        NumberAnimation {
            target: expandedRow
            property: "opacity"
            to: 1
            duration: Appearance.animation.expressiveDefaultSpatial.duration / 2
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }

        ScriptAction {
            script: {
                root.collapseTransitionRunning = false;
                Qt.callLater(root.focusCurrentPage);
            }
        }
    }

    SequentialAnimation {
        id: pageSwitchAnimation

        property bool down: true

        ParallelAnimation {
            NumberAnimation {
                target: pageLoader
                property: "opacity"
                to: 0
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }

            NumberAnimation {
                target: pageLoader.anchors
                property: "topMargin"
                to: pageSwitchAnimation.down ? -10 : 10
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }
        }

        ScriptAction {
            script: root.displayedTab = root.selectedTab
        }

        PropertyAction {
            target: pageLoader.anchors
            property: "topMargin"
            value: pageSwitchAnimation.down ? 10 : -10
        }

        ParallelAnimation {
            NumberAnimation {
                target: pageLoader.anchors
                property: "topMargin"
                to: 0
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }

            NumberAnimation {
                target: pageLoader
                property: "opacity"
                to: 1
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }
        }

        ScriptAction {
            script: Qt.callLater(root.focusCurrentPage)
        }
    }

    Component {
        id: calendarComponent
        CalendarWidget {}
    }

    Component {
        id: todoComponent
        TodoWidget {}
    }

    Component {
        id: timerComponent
        TimerWidget {
            shortcutsEnabled: root.active && !root.collapsed && root.selectedTab === 2 && root.displayedTab
                              === 2
        }
    }
}
