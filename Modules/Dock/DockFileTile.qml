import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root
    required property var fileInfo
    property bool compact: false
    property bool fan: false
    property bool verticalLabel: false
    property bool labelsLeft: true
    property real labelReveal: 1
    property string actionIcon: ""
    property real tileIconSize: compact ? 22 : fan ? 48 : 64
    signal activated(var info)
    readonly property bool hovered: pointer.hovered
    readonly property alias iconItem: artwork
    readonly property alias glassItem: background
    readonly property alias actionGlassItem: actionBackground
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: fileInfo.name || ""
    Accessible.onPressAction: root.activated(fileInfo)
    Keys.onReturnPressed: root.activated(fileInfo)
    Keys.onSpacePressed: root.activated(fileInfo)
    implicitHeight: compact ? 34 : fan ? 68 : 112
    Rectangle {
        id: background
        y: root.verticalLabel ? parent.height - height : (parent.height - height) / 2
        width: root.fan && !root.verticalLabel ? Math.min(parent.width - root.tileIconSize - 18, Math.ceil(
                                                              label.implicitWidth) + 20) : parent.width
        height: root.fan ? 28 : parent.height
        x: root.fan && !root.verticalLabel ? root.labelsLeft ? artwork.x - width - 12 : artwork.x
                                                               + artwork.width + 12 : 0
        opacity: root.labelReveal
        radius: 7
        color: root.fan ? BlurService.backgroundColor(Appearance.colors.colSurfaceContainer) :
                          pointer.hovered ? Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.12) :
                                            "transparent"
        border.width: root.fan ? 1 : 0
        border.color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.16)
    }
    DockFileIcon {
        id: artwork
        width: root.tileIconSize
        height: width
        info: root.fileInfo
        transformed: root.fan
        visible: root.actionIcon === ""
        x: root.verticalLabel ? (parent.width - width) / 2 : root.compact ? 8 : root.fan ? (root.labelsLeft
                                                                                            ? parent.width
                                                                                              - width - 6 :
                                                                                              6) : (parent.width
                                                                                                    - width)
                                                                                           / 2
        y: root.verticalLabel ? 0 : root.compact || root.fan ? (parent.height - height) / 2 : 6
    }
    Rectangle {
        id: actionBackground
        visible: root.actionIcon !== ""
        x: artwork.x + 7
        y: artwork.y + 7
        width: root.tileIconSize - 14
        height: width
        radius: width / 2
        antialiasing: root.fan
        color: BlurService.backgroundColor(Appearance.colors.colSurfaceContainer)
        MaterialSymbol {
            anchors.centerIn: parent
            anchors.alignWhenCentered: false
            text: root.actionIcon
            // Native glyph bitmaps become jagged when the fan rotates them.
            renderType: root.fan ? Text.QtRendering : Text.NativeRendering
            iconSize: Math.max(22, actionBackground.width * 0.55)
            color: Appearance.colors.colOnSurface
        }
    }
    Text {
        id: label
        x: root.compact ? 38 : root.fan && !root.verticalLabel ? background.x + 10 : 10

        y: root.verticalLabel ? root.height - 28 : root.compact || root.fan ? 0 : root.tileIconSize + 12
        width: root.compact ? parent.width - 62 : root.fan && !root.verticalLabel ? background.width - 20 :
                                                                                    parent.width - 20
        height: root.verticalLabel ? 28 : root.compact || root.fan ? parent.height : 32
        text: root.fileInfo.name || ""
        textFormat: Text.PlainText
        color: Appearance.colors.colOnSurface
        font.family: Fonts.ui
        font.pixelSize: 12
        horizontalAlignment: root.compact || root.fan ? Text.AlignLeft : Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideMiddle
        wrapMode: root.compact || root.fan ? Text.NoWrap : Text.Wrap
        maximumLineCount: 2
        opacity: root.labelReveal
    }
    HoverHandler {
        id: pointer
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onPressedChanged: {
            if (pressed)
                fileDrag.dragged = false;
        }
        onTapped: {
            if (!fileDrag.dragged)
                root.activated(root.fileInfo);
        }
    }
    StyledToolTip {
        text: root.fileInfo.name || ""
        textFormat: Text.PlainText
        extraVisibleCondition: root.visible && root.opacity === 1 && root.labelReveal === 1 && pointer.hovered
                               && label.truncated && !fileDrag.dragged && !DockService.fileDragActive
    }
    DockFileDrag {
        id: fileDrag
        enabled: fileUrl !== ""
        fileUrl: String(root.fileInfo.url || "")
        iconItem: artwork
    }
}
