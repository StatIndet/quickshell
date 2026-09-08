pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    property url source
    property string route: ""
    property int navigationDepth: 0
    property bool presentationActive: false
    property Component headerComponent: null
    readonly property var item: currentLayer ? currentLayer.page : null
    property var currentLayer: null
    property var pendingLayer: null

    signal loaded

    function loadPage() {
        if (pendingLayer) {
            pendingLayer.destroy();
            pendingLayer = null;
        }
        if (!source.toString().length || (currentLayer && currentLayer.pageSource === source))
            return;
        const next = pageComponent.createObject(root, {
                                                    route: root.route,
                                                    navigationDepth: root.navigationDepth,
                                                    header: root.headerComponent
                                                });
        pendingLayer = next;
        next.load(source);
    }

    function present(layer) {
        if (pendingLayer !== layer || layer.pageSource !== root.source)
            return;
        const previous = currentLayer;
        // Peers fade in place; deeper routes and back navigation share an axis.
        const direction = previous ? Math.sign(layer.navigationDepth - previous.navigationDepth) : 0;
        const readingDirection = root.LayoutMirroring.enabled ? -1 : 1;
        layer.enterOffset = direction * readingDirection * Metrics.spacingL;
        layer.animate = previous !== null;
        currentLayer = layer;
        pendingLayer = null;
        loaded();
        layer.active = true;
        if (previous) {
            previous.exitOffset = -direction * readingDirection * Metrics.spacingL;
            previous.animate = true;
            previous.retired = true;
            previous.active = false;
            if (!previous.visible)
                previous.destroy();
        }
    }

    onSourceChanged: Qt.callLater(loadPage)
    clip: true

    Component {
        id: pageComponent

        Item {
            id: layer

            required property string route
            required property int navigationDepth
            property bool active: false
            property bool animate: false
            property real enterOffset: 0
            property real exitOffset: 0
            property Component header
            property bool retired: false
            readonly property var page: loader.item
            readonly property url pageSource: loader.source

            function load(url) {
                loader.source = url;
            }

            // Animate visual properties only; page geometry stays fixed.
            width: root.width
            height: root.height
            enabled: active
            visible: active || opacity > 0
            opacity: active ? 1 : 0
            x: active ? 0 : (retired ? exitOffset : enterOffset)
            z: active ? 1 : 0

            Behavior on opacity {
                enabled: root.presentationActive && layer.animate
                NumberAnimation {
                    duration: layer.active ? Appearance.animation.expressiveDefaultEffects.duration :
                                             Appearance.animation.expressiveFastEffects.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: layer.active ? Animations.curves.standardDecel :
                                                       Animations.curves.standardAccel
                }
            }

            Behavior on x {
                enabled: root.presentationActive && layer.animate
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }
            onVisibleChanged: {
                if (retired && !visible)
                    destroy();
            }

            Loader {
                id: headerLoader

                readonly property string route: layer.route
                width: parent.width
                sourceComponent: layer.header
            }

            Loader {
                id: loader

                anchors.fill: parent
                anchors.topMargin: headerLoader.height
                asynchronous: true
                onLoaded: root.present(layer)
            }
        }
    }
}
