import QtQuick
import qs.Common

Item {
    id: root

    property string sourcePath: ""
    property int imageFillMode: Image.PreserveAspectCrop
    property real shaderFillMode: 2
    property string transitionType: "fade"
    property var includedTransitions: []
    property int transitionDurationMs: 1000
    property string transitionEasingMode: "customBezier"
    property var transitionBezierCurve: [0.43, 1.19, 1.0, 0.4, 1.0, 1.0]
    property bool transitionsEnabled: true
    property bool panoramaEnabled: false
    property real horizontalProgress: 0.5
    property var sharedTransform: null
    property int textureWidth: Math.min(Math.max(1, Math.round(width)), 8192)
    property int textureHeight: Math.min(Math.max(1, Math.round(height)), 8192)

    property int currentViewportIndex: 0
    readonly property Item currentViewport: currentViewportIndex === 0 ? viewportA : viewportB
    readonly property Item nextViewport: currentViewportIndex === 0 ? viewportB : viewportA
    readonly property string currentSource: currentViewport ? currentViewport.sourcePath : ""
    readonly property string nextSource: nextViewport ? nextViewport.sourcePath : ""
    readonly property var currentViewportGeometry: currentViewport ? currentViewport.panoramaGeometry : ({})
    readonly property var nextViewportGeometry: nextViewport ? nextViewport.panoramaGeometry : ({})
    readonly property real currentViewportX: currentViewport ? currentViewport.wallpaperX : 0
    readonly property real nextViewportX: nextViewport ? nextViewport.wallpaperX : 0
    property string activeTransition: "none"
    property real transitionProgress: 0
    property bool effectActive: false
    property string pendingSource: ""
    property bool nextIsImmediate: false
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    property real edgeSmoothness: 0.1
    property real wipeDirection: 0
    property real discCenterX: 0.5
    property real discCenterY: 0.5
    property real stripesCount: 16
    property real stripesAngle: 0
    property int activeTransitionDurationMs: 1000
    property int activeTransitionEasingType: Easing.BezierSpline
    property var activeTransitionBezierCurve: [0.43, 1.19, 1.0, 0.4, 1.0, 1.0]
    property string lastError: ""

    readonly property bool sourceIsColor: root.isColorSource(root.sourcePath)
    readonly property bool ready: {
        if (root.sourcePath === "")
            return true;
        if (root.currentSource !== root.sourcePath)
            return false;
        if (root.isColorSource(root.currentSource))
            return true;
        return root.currentViewport.ready;
    }
    readonly property real imagePixelWidth: {
        if (root.nextViewport.ready && root.nextSource !== "")
            return root.nextViewport.imagePixelWidth;
        return root.currentViewport.imagePixelWidth;
    }
    readonly property real imagePixelHeight: {
        if (root.nextViewport.ready && root.nextSource !== "")
            return root.nextViewport.imagePixelHeight;
        return root.currentViewport.imagePixelHeight;
    }

    signal loadFailed(string source, string message)

    function isColorSource(path) {
        return /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(String(path || ""));
    }

    function chooseTransition() {
        let transition = root.transitionType;
        if (transition !== "random")
            return transition;

        const included = root.includedTransitions;
        if (!included || included.length === 0)
            return "fade";
        return included[Math.floor(Math.random() * included.length)];
    }

    function easingType(mode) {
        switch (mode) {
        case "linear":
            return Easing.Linear;
        case "quad":
            return Easing.InOutQuad;
        case "cubic":
            return Easing.InOutCubic;
        case "quart":
            return Easing.InOutQuart;
        case "quint":
            return Easing.InOutQuint;
        case "sine":
            return Easing.InOutSine;
        case "expo":
            return Easing.InOutExpo;
        case "circ":
            return Easing.InOutCirc;
        case "customBezier":
        default:
            return Easing.BezierSpline;
        }
    }

    function setImmediate(path) {
        transitionAnimation.stop();
        const requested = path || "";
        if (requested !== "" && requested === root.nextSource && root.nextViewport.ready) {
            root.currentViewportIndex = root.currentViewportIndex === 0 ? 1 : 0;
            root.nextViewport.sourcePath = "";
        } else {
            root.currentViewport.sourcePath = requested;
            root.nextViewport.sourcePath = "";
        }
        root.pendingSource = "";
        root.activeTransition = "none";
        root.transitionProgress = 0;
        root.effectActive = false;
        root.nextIsImmediate = false;
    }

    function prepareTransition(type) {
        switch (type) {
        case "wipe":
            root.wipeDirection = Math.random() * 4;
            break;
        case "disc":
        case "pixelate":
        case "portal":
            root.discCenterX = Math.random();
            root.discCenterY = Math.random();
            break;
        case "stripes":
            root.stripesCount = Math.round(Math.random() * 20 + 4);
            root.stripesAngle = Math.random() * 360;
            break;
        }
    }

    function startTransition() {
        if (!root.transitionsEnabled) {
            root.setImmediate(root.nextSource);
            return;
        }
        root.activeTransitionDurationMs = root.transitionDurationMs;
        root.activeTransitionEasingType = root.easingType(root.transitionEasingMode);
        root.activeTransitionBezierCurve = root.transitionEasingMode === "customBezier"
                ? root.transitionBezierCurve : [0, 0, 1, 1, 1, 1];
        root.effectActive = true;
        transitionDelayTimer.restart();
    }

    function acceptPreparedImage() {
        if (root.nextSource === "" || !root.nextViewport.ready)
            return;
        root.lastError = "";
        if (root.nextIsImmediate) {
            root.setImmediate(root.nextSource);
            return;
        }
        root.startTransition();
    }

    function requestWallpaper(path, immediate) {
        const requested = path || "";
        root.lastError = "";
        if (requested === "") {
            root.setImmediate("");
            return;
        }

        if (requested === root.currentSource && !root.nextSource)
            return;

        if (root.isColorSource(requested)) {
            root.setImmediate(requested);
            return;
        }

        // A newly created surface has no previous frame to preserve. Load the
        // target directly so backend handoff waits for one decode, not a
        // preload followed by a second decode of the same image.
        if (root.currentSource === "") {
            root.setImmediate(requested);
            return;
        }

        if (transitionAnimation.running || root.effectActive) {
            root.pendingSource = requested;
            return;
        }

        root.nextIsImmediate = root.currentSource === "" || root.isColorSource(root.currentSource) || immediate
                || !root.transitionsEnabled || root.transitionType === "none" || root.transitionDurationMs
                <= 0;
        root.activeTransition = root.nextIsImmediate ? "none" : root.chooseTransition();
        if (root.activeTransition === "none")
            root.nextIsImmediate = true;
        else
            root.prepareTransition(root.activeTransition);
        root.transitionProgress = 0;
        root.nextViewport.sourcePath = requested;
        if (root.nextViewport.ready)
            root.acceptPreparedImage();
    }

    function handleViewportReady(viewport) {
        if (viewport !== root.nextViewport || root.nextSource === "" || transitionAnimation.running
                || root.effectActive)

            return;
        root.acceptPreparedImage();
    }

    function handleViewportFailure(viewport, source) {
        const message = qsTr("Could not decode wallpaper: ") + source;
        root.lastError = message;
        if (viewport === root.nextViewport) {
            root.nextViewport.sourcePath = "";
            root.nextIsImmediate = false;
        }
        root.loadFailed(source, message);
    }

    onSourcePathChanged: requestWallpaper(sourcePath, false)
    onTransitionsEnabledChanged: {
        if (!root.transitionsEnabled && root.effectActive) {
            const target = root.nextSource !== "" ? root.nextSource : (root.pendingSource !== ""
                                                                       ? root.pendingSource :
                                                                         root.currentSource);
            root.setImmediate(target);
        }
    }
    Component.onCompleted: requestWallpaper(sourcePath, true)

    WallpaperImageViewport {
        id: viewportA

        anchors.fill: parent
        sourcePath: ""
        imageFillMode: root.imageFillMode
        panoramaEnabled: root.panoramaEnabled
        horizontalProgress: root.horizontalProgress
        sharedTransform: root.sharedTransform
        textureWidth: root.textureWidth
        textureHeight: root.textureHeight
        visible: root.currentViewport === viewportA || (root.effectActive && root.nextViewport === viewportA)

        onReadyChanged: root.handleViewportReady(viewportA)
        onLoadFailed: source => root.handleViewportFailure(viewportA, source)
    }

    WallpaperImageViewport {
        id: viewportB

        anchors.fill: parent
        sourcePath: ""
        imageFillMode: root.imageFillMode
        panoramaEnabled: root.panoramaEnabled
        horizontalProgress: root.horizontalProgress
        sharedTransform: root.sharedTransform
        textureWidth: root.textureWidth
        textureHeight: root.textureHeight
        visible: root.currentViewport === viewportB || (root.effectActive && root.nextViewport === viewportB)

        onReadyChanged: root.handleViewportReady(viewportB)
        onLoadFailed: source => root.handleViewportFailure(viewportB, source)
    }

    ShaderEffectSource {
        id: srcCurrent

        sourceItem: root.effectActive ? root.currentViewport : null
        hideSource: root.effectActive
        live: root.effectActive
        mipmap: false
        recursive: false
        textureSize: Qt.size(root.textureWidth, root.textureHeight)
    }

    ShaderEffectSource {
        id: srcNext

        sourceItem: root.effectActive ? root.nextViewport : null
        hideSource: root.effectActive
        live: root.effectActive
        mipmap: false
        recursive: false
        textureSize: Qt.size(root.textureWidth, root.textureHeight)
    }

    Loader {
        id: effectLoader

        anchors.fill: parent
        active: root.effectActive

        function transitionComponent(type) {
            switch (type) {
            case "wipe":
                return wipeComp;
            case "disc":
                return discComp;
            case "stripes":
                return stripesComp;
            case "iris bloom":
                return irisComp;
            case "pixelate":
                return pixelateComp;
            case "portal":
                return portalComp;
            case "fade":
            default:
                return fadeComp;
            }
        }

        sourceComponent: transitionComponent(root.activeTransition)
    }

    Component {
        id: fadeComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real fillMode: root.shaderFillMode
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/wallpaper/qsb/wp_fade.frag.qsb")
        }
    }

    Component {
        id: wipeComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real smoothness: root.edgeSmoothness
            property real direction: root.wipeDirection
            property real fillMode: root.shaderFillMode
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/wallpaper/qsb/wp_wipe.frag.qsb")
        }
    }

    Component {
        id: discComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real smoothness: root.edgeSmoothness
            property real aspectRatio: root.width / Math.max(1, root.height)
            property real centerX: root.discCenterX
            property real centerY: root.discCenterY
            property real fillMode: root.shaderFillMode
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/wallpaper/qsb/wp_disc.frag.qsb")
        }
    }

    Component {
        id: stripesComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real smoothness: root.edgeSmoothness
            property real aspectRatio: root.width / Math.max(1, root.height)
            property real stripeCount: root.stripesCount
            property real angle: root.stripesAngle
            property real fillMode: root.shaderFillMode
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/wallpaper/qsb/wp_stripes.frag.qsb")
        }
    }

    Component {
        id: irisComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real smoothness: root.edgeSmoothness
            property real centerX: 0.5
            property real centerY: 0.5
            property real aspectRatio: root.width / Math.max(1, root.height)
            property real fillMode: root.shaderFillMode
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/wallpaper/qsb/wp_iris_bloom.frag.qsb")
        }
    }

    Component {
        id: pixelateComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real smoothness: root.edgeSmoothness
            property real fillMode: root.shaderFillMode
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            property real centerX: root.discCenterX
            property real centerY: root.discCenterY
            property real aspectRatio: root.width / Math.max(1, root.height)
            fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/wallpaper/qsb/wp_pixelate.frag.qsb")
        }
    }

    Component {
        id: portalComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real smoothness: root.edgeSmoothness
            property real aspectRatio: root.width / Math.max(1, root.height)
            property real centerX: root.discCenterX
            property real centerY: root.discCenterY
            property real fillMode: root.shaderFillMode
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/wallpaper/qsb/wp_portal.frag.qsb")
        }
    }

    Timer {
        id: transitionDelayTimer

        interval: 16
        repeat: false
        onTriggered: transitionAnimation.restart()
    }

    NumberAnimation {
        id: transitionAnimation

        target: root
        property: "transitionProgress"
        from: 0
        to: 1
        duration: root.activeTransitionDurationMs
        easing.type: root.activeTransitionEasingType
        easing.bezierCurve: root.activeTransitionBezierCurve
        onFinished: {
            root.currentViewportIndex = root.currentViewportIndex === 0 ? 1 : 0;
            root.nextViewport.sourcePath = "";
            root.transitionProgress = 0;
            root.effectActive = false;

            if (root.pendingSource !== "") {
                const pending = root.pendingSource;
                root.pendingSource = "";
                Qt.callLater(() => root.requestWallpaper(pending, false));
            }
        }
    }
}
