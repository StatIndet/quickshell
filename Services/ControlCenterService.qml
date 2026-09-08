pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    property var controlCenterLoader: null
    property var controlCenterWindow: null

    property bool _openRequested: false
    property string _pendingPage: ""

    readonly property bool loaded: controlCenterWindow !== null
    readonly property bool visible: loaded && controlCenterWindow.visible

    function registerLoader(loader) {
        root.controlCenterLoader = loader;
        if (loader && loader.item)
            root.registerWindow(loader.item);
    }

    function registerWindow(window) {
        if (!window)
            return;

        root.controlCenterWindow = window;
        if (root._openRequested)
            root.presentWindow(window);
    }

    function presentWindow(window) {
        if (!window)
            return;

        const page = root._pendingPage;
        root._pendingPage = "";
        if (page !== "" && window.openPage)
            window.openPage(page);

        if (window.showWindow)
            window.showWindow();
        else
            window.visible = true;
    }

    function open(pageId) {
        root._openRequested = true;
        if (pageId !== undefined && pageId !== null && String(pageId) !== "") {
            root._pendingPage = String(pageId);
        }

        if (!root.controlCenterLoader)
            return false;

        root.controlCenterLoader.active = true;
        if (root.controlCenterLoader.item) {
            if (root.controlCenterWindow !== root.controlCenterLoader.item)
                root.registerWindow(root.controlCenterLoader.item);
            else
                root.presentWindow(root.controlCenterWindow);
        }
        return true;
    }

    function openOrFocus() {
        if (root.visible) {
            const target = ToplevelManager.toplevels.values.find(window => window.title
                                                                           === root.controlCenterWindow.title);
            if (target) {
                target.activate();
                return true;
            }
        }
        return root.open();
    }

    function close() {
        root._openRequested = false;
        root._pendingPage = "";

        const window = root.controlCenterWindow || (root.controlCenterLoader ? root.controlCenterLoader.item :
                                                                               null);
        if (window) {
            if (window.hideWindow)
                window.hideWindow();
            else
                window.visible = false;
            return true;
        }

        if (root.controlCenterLoader)
            root.controlCenterLoader.active = false;
        return false;
    }

    function toggle(pageId) {
        if (root._openRequested || root.visible) {
            root.close();
            return false;
        }
        return root.open(pageId);
    }

    function windowClosed(window) {
        if (root.controlCenterWindow && root.controlCenterWindow !== window) {
            return;
        }

        root.controlCenterWindow = null;
        root._openRequested = false;
        root._pendingPage = "";
        if (root.controlCenterLoader)
            root.controlCenterLoader.active = false;
    }
}
