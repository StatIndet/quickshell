import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Common

Scope {
    id: root
    signal unlocked()
    signal failed()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    // 输入变化时隐藏错误提示
    onCurrentTextChanged: showFailure = false;

    function tryUnlock() {
        if (unlockInProgress) return;
        root.unlockInProgress = true;
        pam.start();
    }

    PamContext {
        id: pam
        configDirectory: Paths.shellDir + "/Modules/Lock/pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText);
            }
        }

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.unlocked();
            } else {
                root.currentText = ""; // 清空密码
                root.showFailure = true;
            }
            root.unlockInProgress = false;
        }
    }
}
