pragma Singleton

import Quickshell

Singleton {
    function toggle() {
        Quickshell.execDetached([
            "qs", "-c", "clavis", "ipc", "call", "launcher", "toggle"
        ]);
    }
}
