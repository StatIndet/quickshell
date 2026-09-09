import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common
import "../../Common/functions/ZenPalette.js" as Zen

Item {
    id: root
    property var parentModal: null
    property int sessionToken: 0
    property bool shouldBeVisible: false
    function showFor(target, output) {
        if (!root.parentModal)
            return;
        root.sessionToken = WallpaperPaletteSession.begin(target, output);
        root.shouldBeVisible = root.sessionToken !== 0;
    }
    function close() {
        WallpaperPaletteSession.cancel(root.sessionToken);
        root.shouldBeVisible = false;
        root.sessionToken = 0;
    }
    Component.onDestruction: root.close()
    Connections {
        target: root.parentModal
        function onVisibleChanged() {
            if (!root.parentModal.visible)
                root.close();
        }
    }
    Connections {
        target: WallpaperPaletteSession
        function onInvalidated(token) {
            if (token === root.sessionToken)
                root.close();
        }
    }
    FloatingWindow {
        id: window
        parentWindow: root.parentModal
        title: "clavis-control-center-color-picker"
        visible: root.shouldBeVisible
        color: "transparent"
        implicitWidth: 470
        implicitHeight: 650
        minimumSize: Qt.size(430, 610)
        onClosed: root.close()
        Rectangle {
            id: background
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: BlurService.backgroundColor(Appearance.m3colors.m3surfaceContainerLow)
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
        }
        CompositorBlurRegion {
            targetWindow: window
            backgroundItem: background
            radius: background.radius
        }
        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Wallpaper palette")
                        font.family: Fonts.ui
                        font.pixelSize: 20
                        color: Appearance.colors.colOnSurface
                    }
                    IconButton {
                        iconName: "close"
                        tooltipText: qsTr("Close")
                        onClicked: root.close()
                    }
                }
                ZenPaletteEditor {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    paletteState: WallpaperPaletteSession.draft || Zen.initial()
                    onEdited: value => WallpaperPaletteSession.update(root.sessionToken, value)
                }
                Text {
                    Layout.fillWidth: true
                    visible: WallpaperPaletteSession.error !== ""
                    text: WallpaperPaletteSession.error
                    color: Appearance.colors.colError
                    wrapMode: Text.Wrap
                    font.family: Fonts.ui
                }
                RowLayout {
                    Layout.fillWidth: true
                    Item {
                        Layout.fillWidth: true
                    }
                    ActionButton {
                        text: qsTr("Save")
                        onClicked: {
                            if (WallpaperPaletteSession.commit(root.sessionToken)) {
                                root.shouldBeVisible = false;
                                root.sessionToken = 0;
                            }
                        }
                    }
                }
            }
        }
    }
}
