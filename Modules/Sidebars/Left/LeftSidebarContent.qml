import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string screenName: ""
    property bool foreground: false
    property bool presentationActive: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.spacing.panelPadding
        spacing: Appearance.spacing.panelPadding

        Item {
            id: tabToolbar

            readonly property var tabs: [
                { id: "info", icon: "info", label: qsTr("信息") },
                { id: "sys", icon: "monitoring", label: qsTr("系统") },
                { id: "weather", icon: "cloud", label: qsTr("天气") }
            ]
            readonly property int currentIndex: Math.max(0,
                tabs.findIndex(tab =>
                    tab.id === WidgetState.leftSidebarView))
            readonly property real buttonWidth: 112
            readonly property real targetLeft:
                Appearance.spacing.small
                    + currentIndex * buttonWidth
            readonly property real targetRight:
                targetLeft + buttonWidth
            property real leftFast: targetLeft
            property real leftSlow: targetLeft
            property real rightFast: targetRight
            property real rightSlow: targetRight

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredWidth:
                buttonWidth * tabs.length
                    + Appearance.spacing.small * 2
            Layout.preferredHeight: 56

            Behavior on leftFast {
                NumberAnimation {
                    duration: 50
                    easing.type: Easing.OutSine
                }
            }
            Behavior on rightFast {
                NumberAnimation {
                    duration: 50
                    easing.type: Easing.OutSine
                }
            }
            Behavior on leftSlow {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutSine
                }
            }
            Behavior on rightSlow {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutSine
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Appearance.colors.colSurfaceContainer
            }

            Rectangle {
                id: activeIndicator

                z: 1
                x: Math.min(tabToolbar.leftFast,
                    tabToolbar.leftSlow)
                y: Appearance.spacing.small
                width: Math.max(tabToolbar.rightFast,
                    tabToolbar.rightSlow) - x
                height: parent.height
                    - Appearance.spacing.small * 2
                radius: height / 2
                color: Appearance.colors.colSecondaryContainer
            }

            Row {
                z: 2
                x: Appearance.spacing.small
                y: Appearance.spacing.small
                height: parent.height
                    - Appearance.spacing.small * 2

                Repeater {
                    model: tabToolbar.tabs

                    delegate: Item {
                        id: tabButton

                        required property var modelData
                        readonly property bool active:
                            WidgetState.leftSidebarView
                                === modelData.id

                        width: tabToolbar.buttonWidth
                        height: parent.height
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.label

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: tabHover.containsMouse
                                && !tabButton.active
                                ? Appearance.applyAlpha(
                                    Appearance.colors.colOnSurface,
                                    0.05)
                                : "transparent"
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Appearance.spacing.small

                            MaterialSymbol {
                                anchors.verticalCenter:
                                    parent.verticalCenter
                                text: tabButton.modelData.icon
                                iconSize: 22
                                fill: tabButton.active ? 1 : 0
                                color: tabButton.active
                                    ? Appearance.colors
                                        .colOnSecondaryContainer
                                    : Appearance.colors
                                        .colOnSurfaceVariant
                            }

                            Text {
                                anchors.verticalCenter:
                                    parent.verticalCenter
                                text: tabButton.modelData.label
                                color: tabButton.active
                                    ? Appearance.colors
                                        .colOnSecondaryContainer
                                    : Appearance.colors
                                        .colOnSurfaceVariant
                                font.family: Sizes.fontFamily
                                font.pixelSize: Sizes.typeBodyMedium
                                font.weight: tabButton.active
                                    ? Font.DemiBold : Font.Medium
                            }
                        }

                        MouseArea {
                            id: tabHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked:
                                WidgetState.leftSidebarView
                                    = tabButton.modelData.id
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices:
                    PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const delta = event.angleDelta.y < 0 ? 1 : -1;
                    const next = (tabToolbar.currentIndex + delta
                        + tabToolbar.tabs.length)
                        % tabToolbar.tabs.length;
                    WidgetState.leftSidebarView
                        = tabToolbar.tabs[next].id;
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true 
            color: "transparent"
            radius: Appearance.rounding.large

            Loader {
                anchors.fill: parent
                asynchronous: true
                sourceComponent: WidgetState.leftSidebarView === "info"
                    ? infoComponent
                    : WidgetState.leftSidebarView === "sys"
                        ? systemComponent : weatherComponent
            }

            Component {
                id: infoComponent
                InfoView {
                    screenName: root.screenName
                    foreground: root.foreground
                }
            }

            Component {
                id: systemComponent
                SystemView {
                    foreground: root.foreground
                }
            }

            Component {
                id: weatherComponent
                WeatherView {
                    foreground: root.foreground
                    presentationActive: root.presentationActive
                }
            }
        }
    }
}
