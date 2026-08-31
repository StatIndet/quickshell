pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Common

Singleton {
    id: root

    component Notif: QtObject {
        id: wrapper

        required property int notificationId
        property int serverNotificationId: -1
        property Notification notification
        property list<var> actions: []
        property bool popup: false
        property bool isTransient: false
        property string appIcon: ""
        property string appName: ""
        property string body: ""
        property string image: ""
        property string replaceKey: ""
        property string summary: ""
        property double time: Date.now()
        property string urgency: NotificationUrgency.Normal.toString()
        property Timer timer

        onNotificationChanged: {
            if (notification === null)
                root.detachNotification(notificationId);
        }
    }

    component NotifTimer: Timer {
        required property int notificationId
        interval: 7000
        running: true
        repeat: false

        onTriggered: {
            const index = root.list.findIndex((notif) => notif.notificationId === notificationId);
            const notifObject = root.list[index];
            if (!notifObject)
                return;

            if (notifObject.isTransient)
                root.discardNotification(notificationId);
            else
                root.timeoutNotification(notificationId);
            destroy();
        }
    }

    readonly property string notificationsDir: Paths.stateHome + "/notifications"
    readonly property string filePath: notificationsDir + "/notifications.json"
    readonly property bool silent: UiPreferences.dndEnabled
    readonly property bool popupInhibited: silent || (WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "info")
    readonly property bool hasNotifs: popupList.length > 0

    property int unread: 0
    property int idOffset: 0
    property list<Notif> list: []
    property var popupList: list.filter((notif) => notif.popup).sort((a, b) => b.time - a.time)
    property var latestTimeForApp: ({})
    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property list<string> appNameList: appNameListForGroups(root.groupsByAppName)
    property list<string> popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    signal notify(notification: var)
    signal discard(id: int)
    signal discardAll()
    signal timeout(id: var)
    signal initDone()

    Component { id: notifComponent; Notif {} }
    Component { id: notifTimerComponent; NotifTimer {} }

    Component.onCompleted: ensureStoreDir.running = true

    onListChanged: {
        const nextLatest = {};
        root.list.forEach((notif) => {
            if (!nextLatest[notif.appName] || notif.time > nextLatest[notif.appName])
                nextLatest[notif.appName] = notif.time;
        });
        root.latestTimeForApp = nextLatest;
    }

    Process {
        id: ensureStoreDir
        command: ["mkdir", "-p", root.notificationsDir]
        running: false
        onExited: root.refresh()
    }

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true;

            const now = Date.now();
            const replaceKey = root.replaceKeyForNotification(notification);
            root.removeNotificationsByReplaceKey(replaceKey);
            root.idOffset++;
            const newNotifObject = notifComponent.createObject(root, {
                "notificationId": root.idOffset,
                "serverNotificationId": notification.id,
                "notification": notification,
                "actions": root.actionsForNotification(notification),
                "appIcon": notification.appIcon || notification.desktopEntry || "",
                "appName": notification.appName || notification.desktopEntry || qsTr("系统"),
                "body": notification.body || "",
                "image": notification.image || "",
                "isTransient": notification.hints ? notification.hints.transient : false,
                "replaceKey": replaceKey,
                "summary": notification.summary || notification.appName || qsTr("通知"),
                "time": now,
                "urgency": notification.urgency ? notification.urgency.toString() : NotificationUrgency.Normal.toString(),
            });

            if (!root.popupInhibited) {
                newNotifObject.popup = true;
                if (notification.expireTimeout !== 0) {
                    newNotifObject.timer = notifTimerComponent.createObject(root, {
                        "notificationId": newNotifObject.notificationId,
                        "interval": notification.expireTimeout < 0 ? 7000 : notification.expireTimeout,
                    });
                }
                root.unread++;
            }

            root.list = [...root.list, newNotifObject];
            root.trimPopupList(3);
            root.saveNotifications();
            root.notify(newNotifObject);
        }
    }

    FileView {
        id: notifFileView
        path: root.filePath

        onLoaded: {
            try {
                const fileContents = notifFileView.text();
                const loaded = JSON.parse(fileContents && fileContents.trim() !== "" ? fileContents : "[]");
                if (!Array.isArray(loaded)) {
                    root.list = [];
                    root.initDone();
                    return;
                }

                let maxId = 0;
                root.list = loaded.map((notif) => {
                    const notificationId = Number(notif.notificationId || notif.id || 0);
                    maxId = Math.max(maxId, notificationId);
                    return notifComponent.createObject(root, {
                        "notificationId": notificationId,
                        "actions": [],
                        "appIcon": notif.appIcon || "",
                        "appName": notif.appName || qsTr("系统"),
                        "body": notif.body || "",
                        "image": notif.image || "",
                        "replaceKey": notif.replaceKey || root.replaceKeyForValues(notif.appName || "System", notif.summary || notif.appName || "Notification"),
                        "summary": notif.summary || notif.appName || qsTr("通知"),
                        "time": Number(notif.time) || Date.now(),
                        "urgency": notif.urgency || NotificationUrgency.Normal.toString(),
                    });
                });
                root.idOffset = maxId;
                root.initDone();
            } catch (error) {
                console.warn("NotificationManager failed to load history:", error);
                root.list = [];
                root.idOffset = 0;
                root.initDone();
            }
        }

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.list = [];
                root.saveNotifications();
                root.initDone();
            } else {
                console.warn("NotificationManager failed to load notification file:", error);
                root.initDone();
            }
        }
    }

    function notifToJSON(notif) {
        return {
            "notificationId": notif.notificationId,
            "actions": notif.actions,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "image": notif.image,
            "replaceKey": notif.replaceKey,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
        };
    }

    function stringifyList(notifications) {
        return JSON.stringify(notifications.map((notif) => root.notifToJSON(notif)), null, 2);
    }

    function actionsForNotification(notification) {
        if (!notification || !notification.actions)
            return [];
        return notification.actions.map((action) => ({
            "identifier": action.identifier,
            "text": action.text,
        }));
    }

    function replaceKeyForValues(appName, summary) {
        return `${appName || "System"}\u001f${summary || ""}`;
    }

    function replaceKeyForNotification(notification) {
        const appName = notification.appName || notification.desktopEntry || "System";
        const summary = notification.summary || notification.appName || notification.desktopEntry || "";
        return root.replaceKeyForValues(appName, summary);
    }

    function refresh() {
        notifFileView.reload();
    }

    function saveNotifications() {
        notifFileView.setText(root.stringifyList(root.list));
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => groups[b].time - groups[a].time);
    }

    function groupsForList(notifications) {
        const groups = {};
        notifications.forEach((notif) => {
            const appName = notif.appName || qsTr("系统");
            if (!groups[appName]) {
                groups[appName] = {
                    appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0,
                };
            }
            groups[appName].notifications.push(notif);
            groups[appName].time = root.latestTimeForApp[appName] || notif.time;
            if (!groups[appName].appIcon && notif.appIcon)
                groups[appName].appIcon = notif.appIcon;
        });
        return groups;
    }

    function triggerListChange() {
        root.list = root.list.slice(0);
    }

    function trimPopupList(maxCount) {
        const popups = root.list.filter((notif) => notif.popup).sort((a, b) => b.time - a.time);
        for (let i = maxCount; i < popups.length; i++)
            popups[i].popup = false;
        if (popups.length > maxCount)
            root.triggerListChange();
    }

    function setSilent(value) {
        UiPreferences.setDndEnabled(value);
    }

    function markAllRead() {
        root.unread = 0;
    }

    function removeByNotifId(targetId) {
        root.timeoutNotification(targetId);
    }

    function detachNotification(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (index === -1)
            return;

        const notif = root.list[index];
        if (notif.timer)
            notif.timer.stop();
        notif.popup = false;
        notif.actions = [];
        notif.serverNotificationId = -1;
        root.triggerListChange();
        root.saveNotifications();
    }

    function removeNotificationsByReplaceKey(replaceKey) {
        const removed = root.list.filter((notif) => notif.replaceKey === replaceKey);
        removed.forEach((notif) => {
            if (notif.timer)
                notif.timer.stop();
        });

        if (removed.length > 0)
            root.list = root.list.filter((notif) => notif.replaceKey !== replaceKey);
    }

    function discardNotification(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        const notifObject = index !== -1 ? root.list[index] : null;
        const serverNotificationId = notifObject ? notifObject.serverNotificationId : -1;
        const notifServerIndex = serverNotificationId !== -1
            ? notifServer.trackedNotifications.values.findIndex((notif) => notif.id === serverNotificationId)
            : -1;
        if (index !== -1) {
            const notif = root.list[index];
            if (notif.timer)
                notif.timer.stop();
            root.list = root.list.filter((candidate) => candidate.notificationId !== id);
            root.saveNotifications();
        }
        if (notifServerIndex !== -1)
            notifServer.trackedNotifications.values[notifServerIndex].dismiss();
        root.discard(id);
    }

    function discardAllNotifications() {
        root.list.forEach((notif) => {
            if (notif.timer)
                notif.timer.stop();
        });
        root.list = [];
        notifServer.trackedNotifications.values.forEach((notif) => notif.dismiss());
        root.saveNotifications();
        root.discardAll();
    }

    function cancelTimeout(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (index !== -1 && root.list[index].timer)
            root.list[index].timer.stop();
    }

    function timeoutNotification(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (index !== -1) {
            if (root.list[index].timer)
                root.list[index].timer.stop();
            root.list[index].popup = false;
            root.triggerListChange();
        }
        root.timeout(id);
    }

    function timeoutAll() {
        root.popupList.forEach((notif) => {
            root.timeout(notif.notificationId);
            if (notif.timer)
                notif.timer.stop();
            notif.popup = false;
        });
        root.triggerListChange();
    }

    function attemptInvokeAction(id, notifIdentifier) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        const notifObject = index !== -1 ? root.list[index] : null;
        const serverNotificationId = notifObject ? notifObject.serverNotificationId : -1;
        const notifServerIndex = serverNotificationId !== -1
            ? notifServer.trackedNotifications.values.findIndex((notif) => notif.id === serverNotificationId)
            : -1;
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const action = notifServerNotif.actions.find((candidate) => candidate.identifier === notifIdentifier);
            if (action)
                action.invoke();
        }
        root.discardNotification(id);
    }
}
