import QtQuick
import QtQuick.Layouts
import Clavis.Niri
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool vertical: false
    property real maximumTitleWidth: 250
    readonly property string edge: PersonalizationConfig.barPosition
    readonly property var activeWindow: Niri.focusedWindow
    readonly property string activeTitle: activeWindow.title || qsTr("桌面")
    readonly property string activeIcon: activeWindow.iconPath || ""
    readonly property string activeAppName: activeWindow.appName || activeWindow.appId || ""
    readonly property bool isDesktop: !activeWindow.id
    readonly property string verticalAppName: activeAppName || qsTr("桌面")
    readonly property bool verticalAppNameIsCjk: root.containsCjk(verticalAppName)
    readonly property string detailedTooltipText: activeAppName && activeAppName !== activeTitle
                                                  ? activeAppName + "\n" + activeTitle : activeTitle

    function containsCjk(value) {
        const cjkPattern =
              /[\u2e80-\u2fff\u3040-\u30ff\u31f0-\u31ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af\uf900-\ufaff]/;
        return cjkPattern.test(String(value || ""));
    }

    function limitedVerticalTitle(value) {
        const characters = Array.from(String(value || ""));
        const limit = 14;
        if (characters.length > limit)
            return characters.slice(0, limit - 1).concat(["…"]).join("");

        return characters.join("");
    }

    function stackedVerticalTitle(value) {
        return Array.from(root.limitedVerticalTitle(value)).join("\n");
    }

    implicitHeight: vertical ? layout.implicitHeight + 16 : Sizes.barPillThickness
    implicitWidth: vertical ? Sizes.barVisualThickness : layout.implicitWidth + 24

    TopBarPillBackground {
        anchors.fill: parent
    }

    GridLayout {
        id: layout

        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        rowSpacing: root.vertical ? 6 : 0
        columnSpacing: root.vertical ? 0 : 10

        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignCenter
            visible: root.vertical || root.isDesktop || root.activeIcon !== "" || root.activeAppName !== ""

            Image {
                id: appIcon

                anchors.fill: parent
                source: root.activeIcon
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                visible: root.activeIcon !== "" && status !== Image.Error
            }

            MaterialSymbol {
                anchors.fill: parent
                text: "desktop_windows"
                iconSize: 18
                color: Appearance.colors.colPrimary
                visible: root.isDesktop
            }

            Text {
                anchors.centerIn: parent
                text: root.activeAppName.charAt(0).toUpperCase()
                color: Appearance.colors.colPrimary
                font.pixelSize: 13
                font.bold: true
                visible: !root.isDesktop && !appIcon.visible
            }
        }

        Item {
            implicitWidth: root.vertical ? (root.verticalAppNameIsCjk ? verticalCjkTitle.implicitWidth :
                                                                        verticalRotatedTitle.implicitHeight) :
                                           horizontalTitle.implicitWidth
            implicitHeight: root.vertical ? (root.verticalAppNameIsCjk ? verticalCjkTitle.implicitHeight :
                                                                         verticalRotatedTitle.implicitWidth) :
                                            horizontalTitle.implicitHeight
            Layout.maximumWidth: root.maximumTitleWidth
            Layout.alignment: Qt.AlignCenter

            Text {
                id: horizontalTitle

                anchors.fill: parent
                text: root.activeTitle
                font.family: Fonts.ui
                font.pointSize: 11
                color: Appearance.colors.colOnSurface
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                visible: !root.vertical
            }

            Text {
                id: verticalCjkTitle

                anchors.centerIn: parent
                text: root.stackedVerticalTitle(root.verticalAppName)
                font.family: Fonts.ui
                font.pointSize: 11
                color: Appearance.colors.colOnSurface
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 0.9
                visible: root.vertical && root.verticalAppNameIsCjk
            }

            Text {
                id: verticalRotatedTitle

                anchors.centerIn: parent
                text: root.limitedVerticalTitle(root.verticalAppName)
                font.family: Fonts.ui
                font.pointSize: 11
                color: Appearance.colors.colOnSurface
                rotation: root.edge === "left" ? -90 : 90
                visible: root.vertical && !root.verticalAppNameIsCjk
            }
        }
    }

    MouseArea {
        id: activeHover

        anchors.fill: parent
        enabled: root.vertical
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    PopupToolTip {
        extraVisibleCondition: root.vertical && activeHover.containsMouse
        text: root.detailedTooltipText
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
}
