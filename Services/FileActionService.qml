pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root
    signal finished(string action, string path, var response)

    function run(action, path) {
        if ((action !== "open" && action !== "reveal") || typeof path !== "string" || !path.startsWith("/"))
            return;
        operation.createObject(root, {
                                   action,
                                   filePath: path
                               });
    }

    Component {
        id: operation
        Process {
            id: request
            required property string action
            required property string filePath
            command: [Paths.stableKey, "file", action, filePath, "--format", "json"]
            running: true
            stdout: StdioCollector {
                id: output
            }
            onExited: exitCode => {
                let response = null;
                try {
                    response = JSON.parse(output.text);
                    if (!response || response.schemaVersion !== 1 || response.command !== "file." + action
                            || typeof response.ok !== "boolean" || (exitCode !== 0 && response.ok) || (response.ok && (
                                                                                                           response.error
                                                                                                           !== null
                                                                                                           || typeof response.fileExists
                                                                                                           !== "boolean"
                                                                                                           || ["open",
                                                                                                               "reveal", "directory"].indexOf(
                                                                                                               response.mode)
                                                                                                           === -1)))
                        response = null;
                } catch (error) {}
                root.finished(action, filePath, response);
                request.destroy();
            }
        }
    }
}
