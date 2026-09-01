pragma Singleton
import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    readonly property int historyLimit: SystemMonitorService.historyLimit
    property var downloadHistories: ({
    })
    property var uploadHistories: ({
    })

    function appendHistory(values, value) {
        if (typeof value !== "number" || !isFinite(value))
            return values;

        const next = values.slice(Math.max(0, values.length - root.historyLimit + 1));
        next.push(value);
        return next;
    }

    function clear() {
        root.downloadHistories = ({
        });
        root.uploadHistories = ({
        });
    }

    function update(network) {
        const interfaces = Array.isArray(network.interfaces) ? network.interfaces : [];
        const nextDownloads = ({
        });
        const nextUploads = ({
        });
        for (let index = 0; index < interfaces.length; index += 1) {
            const networkInterface = interfaces[index];
            const name = String(networkInterface.name || "");
            if (name === "")
                continue;

            nextDownloads[name] = root.appendHistory(root.downloadHistories[name] || [], networkInterface.downloadBytesPerSecond);
            nextUploads[name] = root.appendHistory(root.uploadHistories[name] || [], networkInterface.uploadBytesPerSecond);
        }
        root.downloadHistories = nextDownloads;
        root.uploadHistories = nextUploads;
    }

    Connections {
        function onConfiguredIntervalMsChanged() {
            root.clear();
        }

        function onEffectiveModulesChanged() {
            if (SystemMonitorService.effectiveModules.indexOf("network") < 0)
                root.clear();

        }

        function onNetworkChanged() {
            root.update(SystemMonitorService.network);
        }

        target: SystemMonitorService
    }

}
