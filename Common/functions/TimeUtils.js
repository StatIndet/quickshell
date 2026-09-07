.pragma library

function getRelativeTime(timestampMs) {
    if (!timestampMs) return qsTr("Just now");

    var now = Date.now();
    var diffSeconds = Math.floor((now - timestampMs) / 1000);

    if (diffSeconds < 60) {
        return qsTr("Just now");
    }

    var diffMinutes = Math.floor(diffSeconds / 60);
    if (diffMinutes < 60) {
        return qsTr("%n minute(s) ago", "", diffMinutes);
    }

    var diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) {
        return qsTr("%n hour(s) ago", "", diffHours);
    }

    return qsTr("More than a day ago");
}
