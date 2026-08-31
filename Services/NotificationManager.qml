pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Common

Singleton {
    id: root

    readonly property int defaultPopupTimeoutMs: 7000
    readonly property string notificationsDir: Paths.stateHome + "/notifications"
    readonly property string filePath: notificationsDir + "/notifications.json"
    readonly property bool silent: UiPreferences.dndEnabled
    readonly property bool popupInhibited: silent || (WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "info")
    readonly property bool hasNotifs: popupList.length > 0

    property int unread: 0
    property int idOffset: 0
    property list<Notif> list: []
    property var popupList: list.filter((notif) => notif.popup).sort((a, b) => b.receivedAt - a.receivedAt)
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

    component Notif: QtObject {
        id: wrapper

        required property int notificationId
        property int serverNotificationId: -1
        property Notification notification: null
        property string appIcon: ""
        property string appName: ""
        property string body: ""
        property string desktopEntry: ""
        property string image: ""
        property bool isTransient: false
        property bool popup: false
        property double popupExpiresAt: 0
        property double popupStartedAt: 0
        property double receivedAt: Date.now()
        property string summary: ""
        property Timer timer: null
        property var urgency: NotificationUrgency.Normal
        property Connections closeConnection: Connections {
            target: wrapper.notification

            function onClosed(reason) {
                root.handleNativeClosed(wrapper.notificationId, reason);
            }
        }

        onNotificationChanged: {
            if (notification === null && serverNotificationId !== -1)
                root.detachNotification(notificationId);
        }
    }

    component NotifTimer: Timer {
        required property int notificationId
        running: true
        repeat: false

        onTriggered: {
            const notifObject = root.notificationById(notificationId);
            if (notifObject)
                notifObject.timer = null;
            destroy();
            root.expireNotification(notificationId);
        }
    }

    Component { id: notifComponent; Notif {} }
    Component { id: notifTimerComponent; NotifTimer {} }

    Component.onCompleted: ensureStoreDir.running = true

    onListChanged: {
        const nextLatest = {};
        root.list.forEach((notif) => {
            if (!nextLatest[notif.appName] || notif.receivedAt > nextLatest[notif.appName])
                nextLatest[notif.appName] = notif.receivedAt;
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
        actionIconsSupported: false
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        inlineReplySupported: false
        keepOnReload: false
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true;

            const replaced = root.list.filter((notif) => notif.serverNotificationId === notification.id);
            replaced.forEach((notif) => root.stopPopupTimer(notif));

            const now = Date.now();
            const timeoutMs = root.popupTimeoutMs(notification.expireTimeout);
            root.idOffset++;
            const newNotifObject = notifComponent.createObject(root, {
                "notificationId": root.idOffset,
                "serverNotificationId": notification.id,
                "notification": notification,
                "appIcon": notification.appIcon || "",
                "appName": notification.appName || notification.desktopEntry || qsTr("系统"),
                "body": notification.body || "",
                "desktopEntry": notification.desktopEntry || "",
                "image": notification.image || "",
                "isTransient": notification.transient,
                "summary": notification.summary || notification.appName || qsTr("通知"),
                "receivedAt": now,
                "urgency": notification.urgency,
            });

            if (timeoutMs > 0) {
                newNotifObject.popupStartedAt = now;
                newNotifObject.popupExpiresAt = now + timeoutMs;
                newNotifObject.timer = notifTimerComponent.createObject(root, {
                    "notificationId": newNotifObject.notificationId,
                    "interval": timeoutMs,
                });
            }

            if (!root.popupInhibited) {
                newNotifObject.popup = true;
                root.unread++;
            }

            root.list = [
                ...root.list.filter((notif) => notif.serverNotificationId !== notification.id),
                newNotifObject,
            ];
            replaced.forEach((notif) => Qt.callLater(() => notif.destroy()));
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
                        "appIcon": root.durableHistorySource(notif.appIcon),
                        "appName": notif.appName || qsTr("系统"),
                        "body": notif.body || "",
                        "desktopEntry": notif.desktopEntry || "",
                        "image": root.durableHistorySource(notif.image),
                        "summary": notif.summary || notif.appName || qsTr("通知"),
                        "receivedAt": Number(notif.receivedAt || notif.time) || Date.now(),
                        "urgency": notif.urgency ?? NotificationUrgency.Normal,
                    });
                });
                root.idOffset = maxId;
                root.saveNotifications();
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

    function notificationById(id) {
        return root.list.find((notif) => notif.notificationId === id) || null;
    }

    function popupTimeoutMs(expireTimeoutSeconds) {
        if (expireTimeoutSeconds === 0)
            return 0;
        if (expireTimeoutSeconds < 0)
            return root.defaultPopupTimeoutMs;
        return Math.max(1, Math.round(expireTimeoutSeconds * 1000));
    }

    function nativeActions(notifObject) {
        return notifObject && notifObject.notification && notifObject.notification.actions
            ? notifObject.notification.actions
            : [];
    }

    function defaultAction(notifObject) {
        return root.nativeActions(notifObject).find((action) => action.identifier === "default") || null;
    }

    function normalActions(notifObject) {
        return root.nativeActions(notifObject).filter((action) => action.identifier !== "default");
    }

    function durableHistorySource(source) {
        const value = source || "";
        return value.startsWith("image://qsimage/") ? "" : value;
    }

    function notifToJSON(notif) {
        return {
            "notificationId": notif.notificationId,
            "appIcon": root.durableHistorySource(notif.appIcon),
            "appName": notif.appName,
            "body": notif.body,
            "desktopEntry": notif.desktopEntry,
            "image": root.durableHistorySource(notif.image),
            "receivedAt": notif.receivedAt,
            "summary": notif.summary,
            "urgency": notif.urgency,
        };
    }

    function stringifyList(notifications) {
        return JSON.stringify(notifications.filter((notif) => !notif.isTransient).map((notif) => root.notifToJSON(notif)), null, 2);
    }

    function refresh() {
        notifFileView.reload();
    }

    function saveNotifications() {
        notifFileView.setText(root.stringifyList(root.list));
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => groups[b].receivedAt - groups[a].receivedAt);
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
                    receivedAt: 0,
                };
            }
            groups[appName].notifications.push(notif);
            groups[appName].receivedAt = root.latestTimeForApp[appName] || notif.receivedAt;
            if (!groups[appName].appIcon && notif.appIcon)
                groups[appName].appIcon = notif.appIcon;
        });
        return groups;
    }

    function triggerListChange() {
        root.list = root.list.slice(0);
    }

    function stopPopupTimer(notifObject) {
        if (!notifObject || !notifObject.timer)
            return;
        notifObject.timer.stop();
        notifObject.timer.destroy();
        notifObject.timer = null;
    }

    function hidePopup(notifObject) {
        if (notifObject)
            notifObject.popup = false;
    }

    function finishPopupLifetime(notifObject) {
        if (!notifObject)
            return;
        root.stopPopupTimer(notifObject);
        notifObject.popup = false;
        notifObject.popupStartedAt = 0;
        notifObject.popupExpiresAt = 0;
    }

    function trimPopupList(maxCount) {
        const popups = root.list.filter((notif) => notif.popup).sort((a, b) => b.receivedAt - a.receivedAt);
        for (let i = maxCount; i < popups.length; i++)
            root.hidePopup(popups[i]);
        if (popups.length > maxCount)
            root.triggerListChange();
    }

    function setSilent(value) {
        UiPreferences.setDndEnabled(value);
    }

    function markAllRead() {
        root.unread = 0;
    }

    function detachNotification(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        if (notifObject.isTransient) {
            root.removeSnapshot(id);
            return;
        }
        root.finishPopupLifetime(notifObject);
        notifObject.appIcon = root.durableHistorySource(notifObject.appIcon);
        notifObject.image = root.durableHistorySource(notifObject.image);
        notifObject.serverNotificationId = -1;
        notifObject.notification = null;
        root.triggerListChange();
        root.saveNotifications();
    }

    function handleNativeClosed(id, reason) {
        root.detachNotification(id);
    }

    function removeSnapshot(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        root.stopPopupTimer(notifObject);
        root.list = root.list.filter((candidate) => candidate.notificationId !== id);
        root.saveNotifications();
        Qt.callLater(() => notifObject.destroy());
    }

    function dismissPopup(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        const nativeNotification = notifObject.notification;
        root.finishPopupLifetime(notifObject);
        if (nativeNotification)
            nativeNotification.dismiss();
        else if (notifObject.isTransient)
            root.removeSnapshot(id);
        root.triggerListChange();
    }

    function expireNotification(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        const nativeNotification = notifObject.notification;
        root.finishPopupLifetime(notifObject);
        if (nativeNotification)
            nativeNotification.expire();
        else if (notifObject.isTransient)
            root.removeSnapshot(id);
        root.triggerListChange();
        root.timeout(id);
    }

    function discardNotification(id) {
        root.discardNotifications([id]);
    }

    function discardNotifications(ids) {
        const targetIds = new Set(ids || []);
        const removed = root.list.filter((notif) => targetIds.has(notif.notificationId));
        if (removed.length === 0)
            return;
        removed.forEach((notif) => root.stopPopupTimer(notif));
        root.list = root.list.filter((candidate) => !targetIds.has(candidate.notificationId));
        root.saveNotifications();
        removed.forEach((notif) => {
            if (notif.notification)
                notif.notification.dismiss();
            root.discard(notif.notificationId);
            Qt.callLater(() => notif.destroy());
        });
    }

    function discardAllNotifications() {
        const removed = root.list.slice();
        removed.forEach((notif) => root.stopPopupTimer(notif));
        root.list = [];
        root.saveNotifications();
        removed.forEach((notif) => {
            if (notif.notification)
                notif.notification.dismiss();
            Qt.callLater(() => notif.destroy());
        });
        root.discardAll();
    }

    function hideAllPopups() {
        root.popupList.forEach((notif) => root.hidePopup(notif));
        root.triggerListChange();
    }

    function invokeDefaultAction(id) {
        const action = root.defaultAction(root.notificationById(id));
        if (action)
            action.invoke();
    }

    function invokeAction(action) {
        if (action)
            action.invoke();
    }
}
