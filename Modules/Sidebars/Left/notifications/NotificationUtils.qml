import QtQuick

QtObject {
    function getFriendlyNotifTimeString(timestamp, currentTime) {
        if (!timestamp)
            return "";

        const messageTime = new Date(timestamp);
        const now = new Date(currentTime || Date.now());
        const diffMs = now.getTime() - messageTime.getTime();
        if (diffMs < 60000)
            return qsTr("刚刚");

        if (messageTime.toDateString() === now.toDateString()) {
            const diffMinutes = Math.floor(diffMs / 60000);
            const diffHours = Math.floor(diffMs / 3.6e+06);
            return diffHours > 0 ? `${diffHours}h` : `${diffMinutes}m`;
        }
        if (messageTime.toDateString() === new Date(now.getTime() - 8.64e+07).toDateString())
            return qsTr("昨天");

        if (messageTime.getFullYear() !== now.getFullYear())
            return Qt.formatDateTime(messageTime, "yyyy MMMM dd");

        return Qt.formatDateTime(messageTime, "MMMM dd");
    }

    function processNotificationBody(body) {
        return (body || "").replace(/<img\b[^>]*>/gi, "");
    }

}
