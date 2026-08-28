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
        property bool read: false
        property string appIcon: ""
        property string appName: ""
        property string desktopEntry: ""
        property string body: ""
        property string image: ""
        property string replaceKey: ""
        property string summary: ""
        property bool hasInlineReply: false
        property string inlineReplyPlaceholder: ""
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

    readonly property int historyRetentionMs: 7 * 24 * 60 * 60 * 1000
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
        actionIconsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        inlineReplySupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true;

            const now = Date.now();
            const replaceKey = root.replaceKeyForNotification(notification);
            root.removeNotificationsByReplaceKey(replaceKey);
            root.idOffset++;

            const urgencyValue = notification.urgency !== undefined && notification.urgency !== null
                ? notification.urgency
                : NotificationUrgency.Normal;
            const urgency = urgencyValue.toString();
            const isCritical = urgencyValue === NotificationUrgency.Critical;
            const isLow = urgencyValue === NotificationUrgency.Low;

            // Inline reply: Quickshell распознаёт action "inline-reply" (нативно).
            // KDE-стиль hint "x-kde-reply-placeholder-text" (Telegram) — fallback:
            // показываем поле, но отправка возможна только через нативный путь.
            const kdeReplyHint = notification.hints && notification.hints["x-kde-reply-placeholder-text"];
            const hasInlineReply = notification.hasInlineReply || !!kdeReplyHint;
            const inlineReplyPlaceholder = notification.inlineReplyPlaceholder || kdeReplyHint || qsTr("回复");

            const newNotifObject = notifComponent.createObject(root, {
                "notificationId": root.idOffset,
                "serverNotificationId": notification.id,
                "notification": notification,
                "actions": root.actionsForNotification(notification),
                "appIcon": notification.appIcon || notification.desktopEntry || "",
                "appName": notification.appName || notification.desktopEntry || qsTr("系统"),
                "desktopEntry": notification.desktopEntry || "",
                "body": notification.body || "",
                "image": notification.image || "",
                "isTransient": notification.hints && notification.hints.transient ? true : false,
                "replaceKey": replaceKey,
                "summary": notification.summary || notification.appName || qsTr("通知"),
                "time": now,
                "urgency": urgency,
                "hasInlineReply": hasInlineReply,
                "inlineReplyPlaceholder": inlineReplyPlaceholder,
            });

            // 按优先级决定弹出行为
            if (!root.popupInhibited && !isLow) {
                newNotifObject.popup = true;
                if (notification.expireTimeout !== 0 && !isCritical) {
                    newNotifObject.timer = notifTimerComponent.createObject(root, {
                        "notificationId": newNotifObject.notificationId,
                        "interval": notification.expireTimeout < 0 ? 7000 : notification.expireTimeout,
                    });
                }
                root.unread++;
            }

            root.list = [...root.list, newNotifObject].sort((a, b) => {
                const urgencies = {
                    [NotificationUrgency.Critical.toString()]: 0,
                    [NotificationUrgency.Normal.toString()]: 1,
                    [NotificationUrgency.Low.toString()]: 2
                };
                const aU = urgencies[a.urgency] ?? 1;
                const bU = urgencies[b.urgency] ?? 1;
                if (aU !== bU) return aU - bU;
                return b.time - a.time;
            });

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
                if (!fileContents || fileContents.trim() === "") {
                    root.list = [];
                    root.initDone();
                    return;
                }

                const parsed = JSON.parse(fileContents);
                const loadedData = parsed.version === 1 ? parsed.data : (Array.isArray(parsed) ? parsed : []);

                if (!Array.isArray(loadedData)) {
                    root.list = [];
                    root.initDone();
                    return;
                }

                const now = Date.now();
                const retentionLimit = now - root.historyRetentionMs;

                let maxId = 0;
                root.list = loadedData
                    .filter(notif => (Number(notif.time) || 0) > retentionLimit)
                    .map((notif) => {
                        const notificationId = Number(notif.notificationId || notif.id || 0);
                        maxId = Math.max(maxId, notificationId);
                        return notifComponent.createObject(root, {
                            "notificationId": notificationId,
                            "actions": [],
                            "appIcon": notif.appIcon || "",
                            "appName": notif.appName || qsTr("系统"),
                            "desktopEntry": notif.desktopEntry || "",
                            "body": notif.body || "",
                            "image": notif.image || "",
                            "replaceKey": notif.replaceKey || root.replaceKeyForValues(notif.appName || "System", notif.summary || notif.appName || "Notification"),
                            "summary": notif.summary || notif.appName || qsTr("通知"),
                            "time": Number(notif.time) || Date.now(),
                            "urgency": notif.urgency || NotificationUrgency.Normal.toString(),
                            "read": !!notif.read,
                            "hasInlineReply": !!notif.hasInlineReply,
                            "inlineReplyPlaceholder": notif.inlineReplyPlaceholder || "",
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
            "desktopEntry": notif.desktopEntry,
            "body": notif.body,
            "image": notif.image,
            "replaceKey": notif.replaceKey,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
            "read": notif.read,
            "hasInlineReply": notif.hasInlineReply,
            "inlineReplyPlaceholder": notif.inlineReplyPlaceholder,
        };
    }

    function stringifyList(notifications) {
        return JSON.stringify({
            "version": 1,
            "data": notifications.map((notif) => root.notifToJSON(notif))
        }, null, 2);
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
        // 关键通知不受数量上限约束，仅裁剪低优先级弹出
        const critical = root.list.filter((notif) => notif.popup && notif.urgency === NotificationUrgency.Critical.toString());
        const nonCritical = root.list.filter((notif) => notif.popup && notif.urgency !== NotificationUrgency.Critical.toString())
            .sort((a, b) => b.time - a.time);
        const keepCount = Math.max(0, maxCount - critical.length);
        for (let i = keepCount; i < nonCritical.length; i++)
            nonCritical[i].popup = false;
        if (nonCritical.length > keepCount)
            root.triggerListChange();
    }

    function setSilent(value) {
        UiPreferences.setDndEnabled(value);
    }

    function markAllRead() {
        root.unread = 0;
        let changed = false;
        root.list.forEach((notif) => {
            if (!notif.read) {
                notif.read = true;
                changed = true;
            }
        });
        if (changed) {
            root.triggerListChange();
            root.saveNotifications();
        }
    }

    function markAsRead(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (index === -1 || root.list[index].read)
            return;
        root.list[index].read = true;
        root.triggerListChange();
        root.saveNotifications();
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
        let changed = false;
        for (let i = root.list.length - 1; i >= 0; i--) {
            const notif = root.list[i];
            if (notif.replaceKey !== replaceKey)
                continue;
            if (notif.timer)
                notif.timer.stop();
            root.list.splice(i, 1);
            changed = true;
        }

        if (changed)
            root.triggerListChange();
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
            root.list.splice(index, 1);
            root.triggerListChange();
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

    // Перезапуск автоскрытия после ухода курсора с попапа.
    function resumeTimeout(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        const notif = index !== -1 ? root.list[index] : null;
        if (!notif || !notif.timer)
            return;
        if (notif.urgency === NotificationUrgency.Critical.toString())
            return;
        notif.timer.interval = notif.timer.interval;
        notif.timer.start();
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
        // 关键通知不会被 timeoutAll 清除，需用户显式确认
        root.popupList.forEach((notif) => {
            if (notif.urgency === NotificationUrgency.Critical.toString())
                return;
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

    // Клик по телу уведомления: стандартное поведение всех DE — активировать
    // приложение. Спецификация freedesktop: первое действие с идентификатором
    // "default" (или просто первое действие) возвращает фокус приложению.
    // Без действий — закрываем уведомление.
    function invokeDefaultAction(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        const notifObject = index !== -1 ? root.list[index] : null;
        const serverNotificationId = notifObject ? notifObject.serverNotificationId : -1;
        const notifServerIndex = serverNotificationId !== -1
            ? notifServer.trackedNotifications.values.findIndex((notif) => notif.id === serverNotificationId)
            : -1;
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const actions = notifServerNotif.actions;
            const defaultAction = actions.find((candidate) => candidate.identifier === "default")
                || (actions.length > 0 ? actions[0] : null);
            if (defaultAction) {
                defaultAction.invoke();
                root.discardNotification(id);
                return;
            }
        }
        // Нет действий (или уведомление из истории без живого серверного объекта) —
        // активируем приложение по desktopEntry (freedesktop: клик по телу возвращает
        // фокус приложению). gtk-launch запускает .desktop-файл по имени без расширения.
        // Quickshell заполняет desktopEntry только из явного DBus-hint "desktop-entry",
        // который большинство приложений не передаёт — поэтому fallback на appName
        // (он почти всегда совпадает с desktop-id, напр. "org.telegram.desktop") и на
        // heuristicLookup по нему.
        const rawEntry = String((notifObject && notifObject.desktopEntry) || "");
        const rawAppName = String((notifObject && notifObject.appName) || "");
        let entryName = "";
        if (rawEntry.length > 0) {
            entryName = rawEntry.endsWith(".desktop")
                ? rawEntry.slice(0, -".desktop".length)
                : rawEntry;
        } else if (rawAppName.length > 0) {
            const lookup = DesktopEntries.heuristicLookup(rawAppName);
            if (lookup && lookup.id)
                entryName = String(lookup.id).replace(/\.desktop$/, "");
            else
                entryName = rawAppName.replace(/\.desktop$/, "");
        }
        if (entryName.length > 0) {
            Quickshell.execDetached(["gtk-launch", entryName]);
            root.discardNotification(id);
            return;
        }
        root.discardNotification(id);
    }

    // Inline reply (быстрый ответ из попапа, напр. Telegram).
    // Возвращает false, если у уведомления нет inline reply.
    function sendInlineReply(id, replyText) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        const notifObject = index !== -1 ? root.list[index] : null;
        const serverNotificationId = notifObject ? notifObject.serverNotificationId : -1;
        const notifServerIndex = serverNotificationId !== -1
            ? notifServer.trackedNotifications.values.findIndex((notif) => notif.id === serverNotificationId)
            : -1;
        if (notifServerIndex === -1)
            return false;
        const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
        if (!notifServerNotif.hasInlineReply)
            return false;
        notifServerNotif.sendInlineReply(replyText);
        root.discardNotification(id);
        return true;
    }
}