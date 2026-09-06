import QtQuick
import Quickshell
import Quickshell.Wayland

// Standalone capture config, never a session lock. Keep its native context
// alive until process exit instead of destroying it inside frame callbacks.
ShellRoot {
    id: root
    readonly property string outputName: Quickshell.env("CLAVIS_SNAPSHOT_OUTPUT")
    readonly property string outputPath: Quickshell.env("CLAVIS_SNAPSHOT_PATH")
    readonly property var output: Quickshell.screens.find(screen => screen.name === outputName) || null
    property bool grabbing: false

    Timer {
        interval: 1200
        running: true
        onTriggered: Qt.quit()
    }

    PanelWindow {
        id: host
        screen: root.output
        visible: root.output !== null
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "clavis-lock-snapshot"
        mask: Region {}

        ScreencopyView {
            id: capture
            width: Math.max(1, sourceSize.width)
            height: Math.max(1, sourceSize.height)
            captureSource: root.output
            live: false
            paintCursor: false
            onHasContentChanged: {
                if (hasContent)
                    Qt.callLater(root.grab);
            }
        }
    }

    function grab() {
        if (grabbing || !capture.hasContent)
            return;
        grabbing = true;
        if (!capture.grabToImage(result => {
            result.saveToFile(root.outputPath);
            Qt.callLater(Qt.quit);
        }, capture.sourceSize))
            Qt.quit();
    }
}
