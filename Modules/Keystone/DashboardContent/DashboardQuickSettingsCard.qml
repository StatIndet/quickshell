import QtQuick
import qs.Modules.QuickSettings

Item {
    id: root

    property var screen: null
    readonly property real logicalWidth: 420
    readonly property real logicalHeight: 572
    readonly property real contentScale: Math.min(width / logicalWidth, height / logicalHeight)

    clip: true

    function capturesWheelAt(x, y) {
        if (!quickSettings.capturesWheel)
            return false;

        const point = quickSettings.mapFromItem(root, x, y);
        return quickSettings.capturesWheelAt(point.x, point.y);
    }

    QuickSettingsSurface {
        id: quickSettings

        anchors.centerIn: parent
        width: root.logicalWidth
        height: root.logicalHeight
        scale: root.contentScale
        transformOrigin: Item.Center
        screen: root.screen
    }
}
