import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    required property real railProgress
    required property real mainLeft
    required property real collapsedMainWidth
    required property real expandedMainWidth
    required property real shapeCenterY
    required property real shapeHeight
    required property real buttonDiameter
    required property real buttonGap

    property color surfaceColor: Appearance.colors.colSurfaceContainerHigh
    property real edgeSoftness: 0.9
    property real staggerFraction: 0.0875
    property color shadowColor: Appearance.colors.colShadow
    property real shadowBlur: 0.72
    property real shadowVerticalOffset: 7
    readonly property var blurRegionItems: [
        mainBlurRegion,
        button0BlurRegion,
        button1BlurRegion,
        button2BlurRegion,
        bridge0BlurRegion,
        bridge1BlurRegion,
        bridge2BlurRegion
    ]

    // The reference motion is intentionally staged. The pill first makes
    // room, then the satellites are squeezed from its new trailing edge.
    // Keeping these phases separate makes the liquid chain readable instead
    // of reducing the whole transition to three circles translating at once.
    readonly property real mainGeometryProgress:
        mainProgressForRail(railProgress)
    readonly property real mainWidth: interpolate(
        collapsedMainWidth,
        expandedMainWidth,
        mainGeometryProgress
    )
    readonly property real mainCenterX: mainLeft + mainWidth / 2
    readonly property real mainRight: mainLeft + mainWidth
    readonly property real collapsedMainRight:
        mainLeft + collapsedMainWidth
    readonly property real expandedMainRight:
        mainLeft + expandedMainWidth
    readonly property real buttonSpawnProgress: 0.18
    readonly property real buttonSpawnCenterX:
        mainLeft + interpolate(
            collapsedMainWidth,
            expandedMainWidth,
            mainProgressForRail(buttonSpawnProgress)
        ) - buttonDiameter / 2 + 4

    function clamp(value) {
        return Math.max(0, Math.min(1, value));
    }

    function smooth(value) {
        const progress = clamp(value);
        return progress * progress * (3 - 2 * progress);
    }

    function interpolate(from, to, progress) {
        return from + (to - from) * progress;
    }

    function mainProgressForRail(progress) {
        const bounded = clamp(progress);
        if (bounded <= 0.22)
            return 0.70 * smooth(bounded / 0.22);
        if (bounded <= 0.70)
            return 0.70 + 0.345
                * smooth((bounded - 0.22) / 0.48);
        return 1.045 - 0.045
            * smooth((bounded - 0.70) / 0.30);
    }

    function rawButtonProgress(index) {
        const start = index * root.staggerFraction;
        return clamp((root.railProgress - start) / (1 - start));
    }

    function buttonProgress(index) {
        // railProgress already follows the rail's bounded Bézier curve.
        // Keeping the provider progress raw avoids compressing most visible
        // geometry into the middle of the animation a second time.
        return rawButtonProgress(index);
    }

    function stageProgress(progress, start, end) {
        return smooth((progress - start) / (end - start));
    }

    function iconProgress(index) {
        return stageProgress(buttonProgress(index), 0.68, 0.94);
    }

    function buttonCenterX(index) {
        const progress = root.railProgress;
        const stagger = index * root.staggerFraction;
        const start = root.buttonSpawnProgress + stagger;
        const overshootAt = Math.min(0.80, 0.70 + stagger);
        const finalCenter =
            root.expandedMainRight
            + root.buttonGap + root.buttonDiameter / 2
            + index * (root.buttonDiameter + root.buttonGap);
        const overshootCenter = interpolate(
            root.buttonSpawnCenterX,
            finalCenter,
            1.045
        );
        if (progress <= overshootAt)
            return interpolate(
                root.buttonSpawnCenterX,
                overshootCenter,
                stageProgress(progress, start, overshootAt)
            );
        return interpolate(
            overshootCenter,
            finalCenter,
            stageProgress(progress, overshootAt, 1)
        );
    }

    function buttonRadius(index) {
        const stagger = index * root.staggerFraction;
        return interpolate(
            3,
            root.buttonDiameter / 2,
            stageProgress(
                root.railProgress,
                0.16 + stagger,
                0.46 + stagger
            )
        );
    }

    function bridgeProximity(index) {
        const radius = buttonRadius(index);
        const leftEdge = buttonCenterX(index) - radius;
        const previousRightEdge = index === 0
            ? root.mainRight
            : buttonCenterX(index - 1)
                + buttonRadius(index - 1);
        const gap = Math.max(0, leftEdge - previousRightEdge);
        return 1 - stageProgress(
            gap,
            root.buttonDiameter * 0.04,
            root.buttonDiameter * 0.28
        );
    }

    function bridgeStartX(index) {
        if (index === 0) {
            return root.mainCenterX + root.mainWidth / 2
                - root.shapeHeight / 2 * 0.42;
        }
        return root.buttonCenterX(index - 1);
    }

    function bridgeLeft(index) {
        const radius = root.buttonBridgeRadius(index);
        return Math.min(
            root.bridgeStartX(index),
            root.buttonCenterX(index)
        ) - radius;
    }

    function bridgeWidth(index) {
        const radius = root.buttonBridgeRadius(index);
        return Math.abs(
            root.buttonCenterX(index)
                - root.bridgeStartX(index)
        ) + radius * 2;
    }

    function buttonBlend(index) {
        const progress = root.railProgress;
        const stagger = index * root.staggerFraction;
        const growStart = 0.16 + stagger;
        const peakAt = 0.34 + stagger;
        const holdUntil = 0.44 + stagger;
        const detachAt = [0.60, 0.69, 0.77][index];
        const peakBlend = root.buttonDiameter
            * (index === 0 ? 0.20 : 0.27);
        const neckBlend = root.buttonDiameter
            * (index === 0 ? 0.07 : 0.11);

        if (progress <= growStart || progress >= detachAt)
            return 0;
        if (progress <= peakAt)
            return interpolate(
                0,
                peakBlend,
                stageProgress(progress, growStart, peakAt)
            );
        if (progress <= holdUntil)
            return interpolate(
                peakBlend,
                neckBlend,
                stageProgress(progress, peakAt, holdUntil)
            );
        return interpolate(
            neckBlend,
            0,
            stageProgress(progress, holdUntil, detachAt)
        );
    }

    // Capsules make the neck legible only while two surfaces are genuinely
    // close. They taper out before the positional rebound, so overshoot breaks
    // the connection cleanly instead of stretching a thread across the gap.
    function buttonBridgeRadius(index) {
        const progress = root.railProgress;
        const stagger = index * root.staggerFraction;
        const growStart = 0.18 + stagger;
        const peakAt = 0.35 + stagger;
        const holdUntil = 0.45 + stagger;
        const detachAt = [0.60, 0.69, 0.77][index];
        const peakRadius = root.buttonDiameter
            * (index === 0 ? 0.13 : 0.19);
        const neckRadius = root.buttonDiameter
            * (index === 0 ? 0.045 : 0.075);

        if (progress <= growStart || progress >= detachAt)
            return 0;
        let scheduledRadius = 0;
        if (progress <= peakAt) {
            scheduledRadius = interpolate(
                0,
                peakRadius,
                stageProgress(progress, growStart, peakAt)
            );
        } else if (progress <= holdUntil) {
            scheduledRadius = interpolate(
                peakRadius,
                neckRadius,
                stageProgress(progress, peakAt, holdUntil)
            );
        } else {
            scheduledRadius = interpolate(
                neckRadius,
                0,
                stageProgress(progress, holdUntil, detachAt)
            );
        }
        return scheduledRadius * bridgeProximity(index);
    }

    ShaderEffect {
        id: surfaceSource

        anchors.fill: parent
        visible: false

        property vector2d resolution: Qt.vector2d(width, height)
        property color fillColor: root.surfaceColor
        property vector2d mainCenter:
            Qt.vector2d(root.mainCenterX, root.shapeCenterY)
        property vector2d mainSize:
            Qt.vector2d(root.mainWidth, root.shapeHeight)
        property real mainRadius: root.shapeHeight / 2
        property vector2d button0Center:
            Qt.vector2d(root.buttonCenterX(0), root.shapeCenterY)
        property vector2d button1Center:
            Qt.vector2d(root.buttonCenterX(1), root.shapeCenterY)
        property vector2d button2Center:
            Qt.vector2d(root.buttonCenterX(2), root.shapeCenterY)
        property real button0Radius: root.buttonRadius(0)
        property real button1Radius: root.buttonRadius(1)
        property real button2Radius: root.buttonRadius(2)
        property real button0Blend: root.buttonBlend(0)
        property real button1Blend: root.buttonBlend(1)
        property real button2Blend: root.buttonBlend(2)
        property real button0BridgeRadius:
            root.buttonBridgeRadius(0)
        property real button1BridgeRadius:
            root.buttonBridgeRadius(1)
        property real button2BridgeRadius:
            root.buttonBridgeRadius(2)
        property real edgeSoftness: root.edgeSoftness

        fragmentShader: Qt.resolvedUrl(
            "../../assets/shaders/launcher/qsb/spotlight_mode_morph.frag.qsb"
        )
    }

    MultiEffect {
        anchors.fill: surfaceSource
        source: surfaceSource
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: root.shadowColor
        shadowBlur: root.shadowBlur
        shadowVerticalOffset: root.shadowVerticalOffset
        shadowHorizontalOffset: 0
    }

    Item {
        id: mainBlurRegion

        x: root.mainLeft
        y: root.shapeCenterY - root.shapeHeight / 2
        width: root.mainWidth
        height: root.shapeHeight
        property real radius: root.shapeHeight / 2
    }

    Item {
        id: button0BlurRegion

        readonly property real shapeRadius: root.buttonRadius(0)
        x: root.buttonCenterX(0) - shapeRadius
        y: root.shapeCenterY - shapeRadius
        width: shapeRadius * 2
        height: width
        property real radius: shapeRadius
    }

    Item {
        id: button1BlurRegion

        readonly property real shapeRadius: root.buttonRadius(1)
        x: root.buttonCenterX(1) - shapeRadius
        y: root.shapeCenterY - shapeRadius
        width: shapeRadius * 2
        height: width
        property real radius: shapeRadius
    }

    Item {
        id: button2BlurRegion

        readonly property real shapeRadius: root.buttonRadius(2)
        x: root.buttonCenterX(2) - shapeRadius
        y: root.shapeCenterY - shapeRadius
        width: shapeRadius * 2
        height: width
        property real radius: shapeRadius
    }

    Item {
        id: bridge0BlurRegion

        readonly property real shapeRadius:
            root.buttonBridgeRadius(0)
        x: root.bridgeLeft(0)
        y: root.shapeCenterY - shapeRadius
        width: root.bridgeWidth(0)
        height: shapeRadius * 2
        property real radius: shapeRadius
        visible: shapeRadius > 0.001
    }

    Item {
        id: bridge1BlurRegion

        readonly property real shapeRadius:
            root.buttonBridgeRadius(1)
        x: root.bridgeLeft(1)
        y: root.shapeCenterY - shapeRadius
        width: root.bridgeWidth(1)
        height: shapeRadius * 2
        property real radius: shapeRadius
        visible: shapeRadius > 0.001
    }

    Item {
        id: bridge2BlurRegion

        readonly property real shapeRadius:
            root.buttonBridgeRadius(2)
        x: root.bridgeLeft(2)
        y: root.shapeCenterY - shapeRadius
        width: root.bridgeWidth(2)
        height: shapeRadius * 2
        property real radius: shapeRadius
        visible: shapeRadius > 0.001
    }
}
