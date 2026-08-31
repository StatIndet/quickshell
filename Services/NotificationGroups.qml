pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property var groupCache: []
    property var popupGroupCache: []
    property var groups: []
    property var popupGroups: []

    function sameObjectList(current, next) {
        if (current.length !== next.length)
            return false;

        for (let i = 0; i < current.length; i++) {
            if (current[i] !== next[i])
                return false;

        }
        return true;
    }

    function latestTimeForApp(appName) {
        return NotificationManager.list.reduce((latestTime, notif) => {
            const notifAppName = notif.appName || qsTr("系统");
            return notifAppName === appName ? Math.max(latestTime, notif.time) : latestTime;
        }, 0);
    }

    function updateGroups(notifications, cache) {
        const groupedNotifications = [];
        notifications.forEach((notif) => {
            const appName = notif.appName || qsTr("系统");
            let entry = groupedNotifications.find((candidate) => {
                return candidate.appName === appName;
            });
            if (!entry) {
                entry = {
                    "appName": appName,
                    "notifications": []
                };
                groupedNotifications.push(entry);
            }
            entry.notifications.push(notif);
        });
        const nextGroups = groupedNotifications.map((entry) => {
            let group = cache.find((candidate) => {
                return candidate.key === entry.appName;
            });
            if (!group) {
                group = notificationGroupStateComponent.createObject(root, {
                    "key": entry.appName,
                    "appName": entry.appName
                });
                cache.push(group);
            }
            const appIconNotification = entry.notifications.find((notif) => {
                return notif.appIcon;
            });
            const appIcon = appIconNotification ? appIconNotification.appIcon : "";
            const latestTime = root.latestTimeForApp(entry.appName);
            if (group.appIcon !== appIcon)
                group.appIcon = appIcon;

            if (group.time !== latestTime)
                group.time = latestTime;

            if (!root.sameObjectList(group.notifications, entry.notifications))
                group.notifications = entry.notifications;

            return group;
        }).sort((a, b) => {
            return b.time - a.time;
        });
        cache.forEach((group) => {
            if (!nextGroups.includes(group) && group.notifications.length > 0)
                group.notifications = [];

        });
        return nextGroups;
    }

    function syncGroups() {
        const nextGroups = root.updateGroups(NotificationManager.list, root.groupCache);
        if (!root.sameObjectList(root.groups, nextGroups))
            root.groups = nextGroups;

    }

    function syncPopupGroups() {
        const nextGroups = root.updateGroups(NotificationManager.popupList, root.popupGroupCache);
        if (!root.sameObjectList(root.popupGroups, nextGroups))
            root.popupGroups = nextGroups;

    }

    Component.onCompleted: {
        root.syncGroups();
        root.syncPopupGroups();
    }

    Component {
        id: notificationGroupStateComponent

        NotificationGroupState {
        }

    }

    Connections {
        function onListChanged() {
            root.syncGroups();
        }

        function onPopupListChanged() {
            root.syncPopupGroups();
        }

        target: NotificationManager
    }

}
