pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    required property var screen
    required property string edge
    required property bool expanded
    required property real targetWidth
    required property real targetHeight
    required property Item childItem
    required property Item cutoutItem
    required property real compactLength
    property real expandedRadius: 24
    property bool attached: false
    property bool cutoutVisible: false
    property color surfaceColor: Appearance.colors.colLayer0
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real length: mainBar.contentLength
    readonly property real screenMargin: attached ? 0 : PersonalizationConfig.keystoneEdgeSpacing
    readonly property real availableChildWidth: Math.max(24, screen.width - (horizontal ? 32 : thickness + gap
                                                                                          + screenMargin
                                                                                          + 24))
    readonly property real availableChildHeight: Math.max(24, screen.height - (horizontal ? thickness + gap + screenMargin
                                                                                            + 24 : 32))
    readonly property real thickness: PersonalizationConfig.keystoneThickness
    readonly property real gap: PersonalizationConfig.keystonePopupGap
    // Match the collapsed Pill surface. Only the child deforms; the status
    // bar and its clock remain fixed throughout the split and fusion.
    readonly property real pillWidth: horizontal ? root.compactLength : thickness
    readonly property real pillHeight: horizontal ? thickness : root.compactLength
    property real progress: 0
    property bool componentReady: false
    // Capture the visible pose when changing direction. Closing uses a single
    // contraction curve instead of playing the opening spring backwards.
    property bool closing: false
    property real legStart: 0
    property var legPose: ({
                               travel: 0,
                               along: 0,
                               inward: 0,
                               opacity: 0,
                               blend: 0
                           })
    readonly property real closingRemaining: smoothStep(progress / Math.max(0.0001, legStart))
    readonly property real openingCorrection: 1 - stage(legStart, Math.max(legStart + 0.0001, 1))
    property real heldWidth: pillWidth
    property real heldHeight: pillHeight
    // As in Spotlight, overlapping damped responses keep velocity through
    // emergence, separation and expansion instead of stopping at each pose.
    readonly property real travel: closing ? legPose.travel * closingRemaining : response(0, 6.4, 7.2) + (
                                                 legPose.travel - response(0, 6.4, 7.2, legStart))
                                             * openingCorrection
    readonly property real alongGrowth: closing ? legPose.along * closingRemaining : response(0.025, 6.8,
                                                                                              5.8) + (legPose.along
                                                                                                      - response(
                                                                                                          0.025, 6.8,
                                                                                                          5.8, legStart))
                                                  * openingCorrection
    readonly property real inwardGrowth: closing ? legPose.inward * closingRemaining : response(0.055, 6.4,
                                                                                                5.4) + (legPose.inward
                                                                                                        - response(
                                                                                                            0.055, 6.4,
                                                                                                            5.4, legStart))
                                                   * openingCorrection
    readonly property real childWidth: pillWidth + (heldWidth - pillWidth) * (horizontal ? alongGrowth :
                                                                                           inwardGrowth)
    readonly property real childHeight: pillHeight + (heldHeight - pillHeight) * (horizontal ? inwardGrowth :
                                                                                               alongGrowth)
    readonly property real childOffset: (thickness + gap) * travel
    readonly property real childRadius: Math.min(childWidth / 2, childHeight / 2, thickness / 2 + (
                                                     expandedRadius - thickness / 2) * Math.min(1,
                                                                                                inwardGrowth))
    readonly property real contentOpacity: closing ? legPose.opacity * closingRemaining : stage(0.12, 0.50) + (
                                                         legPose.opacity - smoothStep((legStart - 0.12)
                                                                                      / 0.38))
                                                     * openingCorrection
    readonly property real contentOffset: 10 * (1 - Math.min(1, inwardGrowth))
    readonly property real separation: Math.max(0, childOffset - thickness)
    // Expose the neck with the pill, then release it while both motion and
    // growth continue. The SDF itself determines when contact breaks.
    readonly property real blendRadius: closing ? legPose.blend * closingRemaining + 56 * Math.sin(Math.PI
                                                                                                   * closingRemaining)
                                                  * smoothStep(childOffset / thickness) : openingBlend(
                                                      progress, travel) + (legPose.blend - openingBlend(
                                                                               legStart, legPose.travel))
                                                  * openingCorrection
    readonly property alias mainItem: mainBar
    readonly property bool clockHovered: mainBar.clockHovered
    readonly property bool mainHovered: mainBar.hovered
    readonly property alias childBlurItem: childBlur
    readonly property alias cutoutBlurItem: cutoutBlur
    readonly property var blurItems: [mainBar, attachedCap, childBlur, neckBlur].concat(edgeStrips.instances)
    readonly property alias mainInputRegion: mainRegion
    readonly property vector2d inwardDirection: edge === "top" ? Qt.vector2d(0, 1) : edge === "bottom" ? Qt.vector2d(0,
                                                                                                                     -1) : edge
                                                                                                         === "left"
                                                                                                         ? Qt.vector2d(
                                                                                                               1, 0) : Qt.vector2d(
                                                                                                               -1, 0)

    signal clockClicked(int button)
    signal mediaRequested

    function smoothStep(value) {
        const p = Math.max(0, Math.min(1, value));
        return p * p * (3 - 2 * p);
    }

    function stage(start, end) {
        return smoothStep((progress - start) / (end - start));
    }

    // Zero initial velocity, a small natural overshoot, and an exact endpoint.
    // A decaying correction preserves the current pose when reopening midway.
    function response(delay, decay, frequency, position = progress) {
        const time = Math.max(0, Math.min(1, position) - delay);
        const end = 1 - delay;
        const phase = decay / frequency;
        const value = 1 - Math.exp(-decay * time) * (Math.cos(frequency * time) + phase * Math.sin(frequency
                                                                                                   * time));
        const terminal = 1 - Math.exp(-decay * end) * (Math.cos(frequency * end) + phase * Math.sin(frequency
                                                                                                    * end));
        return value / terminal;
    }

    function openingBlend(position, travelValue) {
        return 56 * smoothStep((thickness + gap) * travelValue / thickness) * (1 - smoothStep((position
                                                                                               - 0.25) / 0.40));
    }

    function updateSize() {
        if (!expanded)
            return;
        heldWidth = Math.min(targetWidth, availableChildWidth);
        heldHeight = Math.min(targetHeight, availableChildHeight);
    }

    // Coalesce layout changes so a collapsed target cannot replace the held
    // expanded size before the expanded binding has caught up in this turn.
    onAvailableChildWidthChanged: Qt.callLater(updateSize)
    onAvailableChildHeightChanged: Qt.callLater(updateSize)
    onTargetWidthChanged: Qt.callLater(updateSize)
    onTargetHeightChanged: Qt.callLater(updateSize)
    onExpandedChanged: {
        if (!componentReady)
            return;
        progressAnimation.stop();
        const pose = {
            travel,
            along: alongGrowth,
            inward: inwardGrowth,
            opacity: contentOpacity,
            blend: blendRadius
        };
        const start = progress;
        legPose = pose;
        legStart = start;
        closing = !expanded;
        Qt.callLater(updateSize);
        // Set timing before starting: a Behavior on a state-bound progress
        // can start with the previous state's duration during binding updates.
        progressAnimation.duration = expanded ? 580 : 210;
        progressAnimation.to = expanded ? 1 : 0;
        progressAnimation.start();
    }
    Component.onCompleted: {
        progress = expanded ? 1 : 0;
        updateSize();
        componentReady = true;
    }

    implicitWidth: horizontal ? Math.max(length, childWidth) : Math.max(thickness, childOffset + childWidth)
    implicitHeight: horizontal ? Math.max(thickness, childOffset + childHeight) : Math.max(length,
                                                                                           childHeight)

    NumberAnimation {
        id: progressAnimation
        target: root
        property: "progress"
        easing.type: Easing.Linear
    }
    Behavior on heldWidth {
        enabled: root.progress > 0.99
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on heldHeight {
        enabled: root.progress > 0.99
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    FullStatusBar {
        id: mainBar
        screen: root.screen
        edge: root.edge
        x: root.horizontal ? (root.width - width) / 2 : root.edge === "right" ? root.width - width : 0
        y: !root.horizontal ? (root.height - height) / 2 : root.edge === "bottom" ? root.height - height : 0
        width: root.horizontal ? root.length : root.thickness
        height: root.horizontal ? root.thickness : root.length
        property real radius: root.thickness / 2
        onClockClicked: button => root.clockClicked(button)
        onMediaRequested: root.mediaRequested()
        z: 2
    }

    Item {
        id: attachedCap
        visible: root.attached
        x: mainBar.x + (root.edge === "right" ? root.thickness / 2 : 0)
        y: mainBar.y + (root.edge === "bottom" ? root.thickness / 2 : 0)
        width: root.horizontal ? mainBar.width : root.thickness / 2
        height: root.horizontal ? root.thickness / 2 : mainBar.height
        property real radius: 0
    }

    // The attached shoulders extend 8 px along the edge and 14 px inward.
    // Rasterize only these static shoulders for matching input and blur regions.
    Variants {
        id: edgeStrips
        model: root.attached ? Array.from({
                                              length: 14
                                          }, (_, i) => i) : []
        Item {
            required property int modelData
            parent: root
            readonly property real extension: 8 * (1 - Math.sqrt(1 - Math.pow(1 - (modelData + 0.5) / 14, 2)))
            x: mainBar.x + (root.horizontal ? -extension : root.edge === "left" ? modelData : root.thickness
                                                                                  - modelData - 1)
            y: mainBar.y + (!root.horizontal ? -extension : root.edge === "top" ? modelData : root.thickness
                                                                                  - modelData - 1)
            width: root.horizontal ? mainBar.width + 2 * extension : 1
            height: root.horizontal ? 1 : mainBar.height + 2 * extension
            property real radius: 0
        }
    }

    Region {
        id: mainRegion
        regions: [barRegion, capRegion].concat(edgeRegions.instances)
    }
    Region {
        id: barRegion
        item: mainBar
        radius: root.thickness / 2
    }
    Region {
        id: capRegion
        item: root.attached ? attachedCap : null
    }
    Variants {
        id: edgeRegions
        model: edgeStrips.instances
        Region {
            required property var modelData
            item: modelData
        }
    }

    Item {
        id: childBlur
        x: root.childItem.x
        y: root.childItem.y
        width: root.childWidth
        height: root.childHeight
        property real radius: root.childRadius
        visible: root.progress > 0
    }

    Item {
        id: cutoutBlur
        // The fixed card and its hole move together; the growing child surface
        // reveals both by clipping, without a second, independent hole animation.
        x: root.childItem.x + root.cutoutItem.x
        y: root.childItem.y + root.cutoutItem.y
        width: root.cutoutItem.width
        height: root.cutoutItem.height
        property real radius: root.cutoutItem.radius
        visible: root.cutoutVisible && root.progress > 0 && width > 0 && height > 0
    }

    Item {
        // Only blur the interior of an actually connected neck. Detached
        // space is neither blurred nor included in the window input mask.
        id: neckBlur
        visible: root.separation > 0 && root.blendRadius > root.separation * 2.8
        x: root.horizontal ? root.width / 2 - 6 : root.edge === "left" ? root.thickness : root.width
                                                                         - root.childOffset
        y: !root.horizontal ? root.height / 2 - 6 : root.edge === "top" ? root.thickness : root.height
                                                                          - root.childOffset
        width: root.horizontal ? 12 : root.separation
        height: root.horizontal ? root.separation : 12
        property real radius: 0
    }

    Item {
        id: morphSurface
        x: -24
        y: -24
        width: root.width + 48
        height: root.height + 48
        // Render opaque once, then apply the configured alpha to the combined
        // surface and its shadow, preserving translucent shell backgrounds.
        opacity: root.surfaceColor.a
        layer.enabled: opacity < 1

        MorphShader {
            id: shadowSource
            fillColor: "black"
            visible: false
        }

        DropShadow {
            anchors.fill: shadowSource
            source: shadowSource
            horizontalOffset: root.edge === "left" ? 4 : root.edge === "right" ? -4 : 0
            verticalOffset: root.edge === "top" ? 4 : root.edge === "bottom" ? -4 : 0
            radius: 14
            samples: 29
            color: Appearance.colors.colShadow
            cached: false
        }

        MorphShader {}
    }

    component MorphShader: ShaderEffect {
        anchors.fill: parent
        property vector2d resolution: Qt.vector2d(width, height)
        property color fillColor: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 1)
        property vector2d mainCenter: Qt.vector2d(mainBar.x + mainBar.width / 2 + 24, mainBar.y
                                                  + mainBar.height / 2 + 24)
        property vector2d mainSize: Qt.vector2d(mainBar.width, mainBar.height)
        property real mainRadius: root.thickness / 2
        property real attached: root.attached ? 1 : 0
        property vector2d inwardDirection: root.inwardDirection
        property vector2d satelliteCenter: Qt.vector2d(root.childItem.x + root.childWidth / 2 + 24,
                                                       root.childItem.y + root.childHeight / 2 + 24)
        property vector2d satelliteSize: Qt.vector2d(root.childWidth, root.childHeight)
        property real satelliteRadius: root.childRadius
        property real blendRadius: root.blendRadius
        property real edgeSoftness: 0.8
        property vector4d cutoutRect: Qt.vector4d(cutoutBlur.x + 24, cutoutBlur.y + 24, cutoutBlur.visible
                                                  ? cutoutBlur.width : 0, cutoutBlur.height)
        property real cutoutRadius: cutoutBlur.radius
        fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/keystone/qsb/full_split.frag.qsb")
    }
}
