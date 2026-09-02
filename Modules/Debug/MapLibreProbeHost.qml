import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool openRequested: false

    function open() : string {
        root.openRequested = true;
        probeLoader.active = true;
        if (probeLoader.item)
            probeLoader.item.showWindow();

        return "OPENING";
    }

    function close() : string {
        root.openRequested = false;
        probeLoader.active = false;
        return "CLOSED";
    }

    function toggle() : string {
        if (probeLoader.active) {
            root.close();
            return "CLOSED";
        }
        return root.open();
    }

    function reload() : string {
        if (!probeLoader.item)
            return "CLOSED";

        probeLoader.item.reloadMap();
        return "RELOADING";
    }

    function status() : string {
        if (!probeLoader.item)
            return "UNLOADED";

        return probeLoader.item.probeStatus();
    }

    LazyLoader {
        id: probeLoader

        active: false
        source: Qt.resolvedUrl("MapLibreProbeWindow.qml")
        onItemChanged: {
            if (!item)
                return ;

            item.probeClosed.connect(root.close);
            if (root.openRequested)
                item.showWindow();

        }
    }

    IpcHandler {
        function open() : string {
            return root.open();
        }

        function close() : string {
            return root.close();
        }

        function toggle() : string {
            return root.toggle();
        }

        function reload() : string {
            return root.reload();
        }

        function status() : string {
            return root.status();
        }

        target: "maplibre-probe"
    }

}
