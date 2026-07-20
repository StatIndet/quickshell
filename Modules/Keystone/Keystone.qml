import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.FilePicker
import qs.Modules.Keystone.Styles.Bangs
import qs.Modules.Keystone.Styles.Pill

Item {
    id: root

    function invoke(methodName): string {
        if (!styleLoader.item || typeof styleLoader.item[methodName] !== "function")
            return "KEYSTONE_UNAVAILABLE";
        return styleLoader.item[methodName]();
    }

    function openAvatarPicker(screen) {
        avatarFilePicker.targetScreen = screen;
        Qt.callLater(() => avatarFilePicker.openAt(
            avatarFilePicker.picturesDir !== ""
                ? avatarFilePicker.picturesDir
                : Paths.homeDir
        ));
    }

    Loader {
        id: styleLoader

        sourceComponent: PersonalizationConfig.keystoneStyle === "pill"
            ? pillStyle
            : bangsStyle
    }

    FilePickerWindow {
        id: avatarFilePicker

        title: "选择用户头像"
        description: "图片将复制到 ~/.face，并同步用于 Dashboard 与锁屏"
        onAccepted: path => AvatarService.setAvatar(path)
    }

    IpcHandler {
        target: "keystone"

        function cancelRecord(): string { return root.invoke("cancelRecord"); }
        function closeAllOthers(): string { return root.invoke("closeAllOthers"); }
        function currentStyle(): string { return PersonalizationConfig.keystoneStyle; }
        function hub(): string { return root.invoke("hub"); }
        function tools(): string { return root.invoke("tools"); }
    }

    IpcHandler {
        target: "island"

        function cancelRecord(): string { return root.invoke("cancelRecord"); }
        function closeAllOthers(): string { return root.invoke("closeAllOthers"); }
        function currentStyle(): string { return PersonalizationConfig.keystoneStyle; }
        function hub(): string { return root.invoke("hub"); }
        function tools(): string { return root.invoke("tools"); }
    }

    Component {
        id: bangsStyle

        Bangs {
            onAvatarEditRequested: screen => root.openAvatarPicker(screen)
        }
    }

    Component {
        id: pillStyle

        Pill {
            onAvatarEditRequested: screen => root.openAvatarPicker(screen)
        }
    }
}
