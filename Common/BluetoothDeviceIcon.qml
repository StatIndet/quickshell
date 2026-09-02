pragma Singleton
import QtQuick

QtObject {
    function iconName(deviceOrIcon) {
        const icon = String(typeof deviceOrIcon === "string" ? deviceOrIcon : deviceOrIcon && deviceOrIcon.icon || "").toLowerCase();
        if (icon.indexOf("head") >= 0 || icon.indexOf("headset") >= 0)
            return "headphones";

        if (icon.indexOf("speaker") >= 0 || icon.indexOf("audio") >= 0)
            return "speaker";

        if (icon.indexOf("keyboard") >= 0)
            return "keyboard";

        if (icon.indexOf("mouse") >= 0 || icon.indexOf("input") >= 0)
            return "mouse";

        if (icon.indexOf("phone") >= 0)
            return "smartphone";

        if (icon.indexOf("computer") >= 0 || icon.indexOf("laptop") >= 0)
            return "computer";

        return "bluetooth";
    }

}
