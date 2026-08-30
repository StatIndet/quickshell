import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property SpotlightStyle style
    required property string mode
    required property var results
    required property var wallpaperModel
    required property var clipboardModel
    required property int selectedIndex

    property bool expanded: mode !== "web"
    property bool loading: false
    property bool providerAvailable: true
    property bool canRestore: true
    property var providerError: null
    property string clipboardActionState: "idle"
    property string clipboardActionEntryId: ""
    property string clipboardActionError: ""
    property bool clipboardActionRunning: false
    property bool wallpaperHasMore: false
    property real availableHeight: 100000
    property real contentOpacity: 1
    readonly property int modeIndex: mode === "wallpapers"
        ? 1 : (mode === "clipboard" ? 2 : 0)
    readonly property int clipboardHeaderHeight:
        mode === "clipboard" ? 46 : 0
    readonly property int wallpaperColumnCount:
        style.wallpaperColumnsForWidth(wallpaperGrid.width)
    readonly property real wallpaperCellWidth:
        wallpaperGrid.width / Math.max(1, wallpaperColumnCount)
    readonly property real wallpaperPreviewWidth:
        Math.max(
            1,
            wallpaperCellWidth - style.wallpaperGridGap
        )
    readonly property real wallpaperPreviewHeight:
        wallpaperPreviewWidth / style.wallpaperPreviewAspectRatio
    readonly property real wallpaperCellHeight:
        wallpaperPreviewHeight
            + style.wallpaperLabelGap
            + style.wallpaperLabelHeight
            + style.wallpaperGridGap
    readonly property Item blurRegionItem: panelBlurRegion
    readonly property Item modalBlurRegionItem: clearDialog.blurRegionItem
    readonly property bool modalActive: clearDialog.visible
    readonly property int targetHeight: {
        if (!expanded)
            return 0;
        if (loading || !providerAvailable || results.length === 0)
            return style.emptyHeight + clipboardHeaderHeight;
        if (mode === "wallpapers")
            return Math.min(
                style.wallpaperGridHeight,
                Math.max(style.emptyHeight, availableHeight)
            );
        return Math.min(
            style.resultMaxHeight,
            results.length * style.resultRowHeight
                + style.resultPadding * 2 + clipboardHeaderHeight
        );
    }

    signal selectionRequested(int index)
    signal activationRequested(int index, bool keepOpen)
    signal deleteRequested(int index)
    signal clearRequested()
    signal inspectionRequested(string id)
    signal inspectionReleased(string id)
    signal modalClosed()
    signal wallpaperMoreRequested(int minimumCount)

    height: targetHeight
    opacity: expanded ? 1 : 0
    visible: height > 0.5 || opacity > 0.01

    Behavior on width {
        NumberAnimation {
            duration: root.style.panelDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.style.panelCurve
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: root.style.panelDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.style.panelCurve
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.style.panelDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.style.effectsCurve
        }
    }

    onModeChanged: {
        root.contentOpacity = 0;
        contentFade.restart();
    }

    onSelectedIndexChanged: ensureCurrentVisible()

    function fallbackIconSource() {
        const fallback =
            Quickshell.iconPath("application-x-executable", "");
        return fallback && fallback !== ""
            ? fallback : "image://icon/application-x-executable";
    }

    function iconSource(icon) {
        if (!icon)
            return fallbackIconSource();
        if (String(icon).startsWith("/"))
            return "file://" + icon;
        if (String(icon).startsWith("file://")
                || String(icon).startsWith("image://"))
            return icon;
        const resolved =
            Quickshell.iconPath(icon, "application-x-executable");
        return resolved && resolved !== ""
            ? resolved : fallbackIconSource();
    }

    function clipboardActivationAreaAt(index) {
        const delegate = clipboardList.itemAtIndex(index);
        return delegate ? delegate.activationArea : null;
    }

    function clipboardLayoutAt(index) {
        const delegate = clipboardList.itemAtIndex(index);
        if (!delegate)
            return null;
        return {
            textRight: delegate.textArea.x + delegate.textArea.width,
            actionLeft: delegate.actionArea.x,
            titleMaximumLineCount: delegate.titleLabel.maximumLineCount,
            subtitleMaximumLineCount: delegate.subtitleLabel.maximumLineCount,
            titleWrapMode: delegate.titleLabel.wrapMode,
            subtitleWrapMode: delegate.subtitleLabel.wrapMode,
            titleFontFamily: delegate.titleLabel.font.family,
            titleClip: delegate.titleLabel.clip,
            subtitleClip: delegate.subtitleLabel.clip
        };
    }

    function gridColumns() {
        return root.wallpaperColumnCount;
    }

    function navigationStep(direction) {
        return mode === "wallpapers"
            ? direction * gridColumns() : direction;
    }

    function ensureCurrentVisible() {
        if (root.selectedIndex < 0 || root.results.length === 0)
            return;
        if (root.mode === "wallpapers")
            wallpaperGrid.positionViewAtIndex(
                root.selectedIndex, GridView.Contain);
        else if (root.mode === "clipboard")
            clipboardList.positionViewAtIndex(
                root.selectedIndex, ListView.Contain);
        else
            appList.positionViewAtIndex(
                root.selectedIndex, ListView.Contain);
    }

    function requestMoreWallpapers() {
        if (root.mode !== "wallpapers" || !root.wallpaperHasMore)
            return;
        const remaining = wallpaperGrid.contentHeight
            - wallpaperGrid.contentY - wallpaperGrid.height;
        if (remaining > root.wallpaperCellHeight * 1.5)
            return;
        root.wallpaperMoreRequested(
            wallpaperGrid.count + root.wallpaperColumnCount * 4);
    }

    NumberAnimation {
        id: contentFade

        target: root
        property: "contentOpacity"
        from: 0
        to: 1
        duration: root.style.panelDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.style.effectsCurve
    }

    Item {
        id: panelBlurRegion

        anchors.fill: parent
        anchors.margins: root.style.blurEdgeInset
        property real radius: Math.max(0,
            root.style.resultRadius - root.style.blurEdgeInset)
    }

    Rectangle {
        id: panelSurface

        anchors.fill: parent
        radius: root.style.resultRadius
        color: root.style.panelColor
        visible: false
    }

    MultiEffect {
        anchors.fill: panelSurface
        source: panelSurface
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: root.style.shadowColor
        shadowBlur: root.style.shadowBlur
        shadowVerticalOffset: root.style.shadowVerticalOffset
        shadowHorizontalOffset: 0
    }

    StackLayout {
        anchors.fill: parent
        anchors.margins: root.mode === "wallpapers"
            ? root.style.wallpaperPanelPadding
            : root.style.resultPadding
        currentIndex: root.modeIndex
        opacity: root.contentOpacity

        ListView {
            id: appList

            clip: true
            spacing: 0
            model: root.mode === "apps" ? root.results : []
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: appDelegate

                required property int index
                required property var modelData
                width: ListView.view.width
                height: root.style.resultRowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.large
                    color: appDelegate.index === root.selectedIndex
                        ? root.style.selectedColor
                        : (appMouse.containsMouse
                            ? root.style.hoverColor
                            : "transparent")
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: 14

                    Image {
                        Layout.preferredWidth: root.style.resultIconSize
                        Layout.preferredHeight: root.style.resultIconSize
                        source: root.iconSource(appDelegate.modelData.icon)
                        sourceSize.width: root.style.resultIconSize * 2
                        sourceSize.height: root.style.resultIconSize * 2
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: appDelegate.modelData.title
                            color: appDelegate.index === root.selectedIndex
                                ? root.style.selectedContentColor
                                : Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: 17
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: appDelegate.modelData.subtitle
                            color: appDelegate.index === root.selectedIndex
                                ? root.style.selectedContentColor
                                : Appearance.colors.colOnSurfaceVariant
                            font.family: Fonts.ui
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    MaterialSymbol {
                        text: "keyboard_return"
                        iconSize: 19
                        color: root.style.selectedContentColor
                        opacity: appDelegate.index === root.selectedIndex
                            ? 0.78 : 0
                    }
                }

                MouseArea {
                    id: appMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.name: appDelegate.modelData.title
                    Accessible.role: Accessible.ListItem
                    onClicked: {
                        root.selectionRequested(appDelegate.index);
                        root.activationRequested(appDelegate.index, false);
                    }
                }
            }
        }

        GridView {
            id: wallpaperGrid

            clip: true
            model: root.mode === "wallpapers"
                ? root.wallpaperModel : null
            currentIndex: root.selectedIndex
            cellWidth: root.wallpaperCellWidth
            cellHeight: root.wallpaperCellHeight
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 0
            onContentYChanged: root.requestMoreWallpapers()
            onHeightChanged: Qt.callLater(root.requestMoreWallpapers)
            onCountChanged: Qt.callLater(root.requestMoreWallpapers)

            delegate: Item {
                id: wallpaperDelegate

                required property int index
                required property string wallpaperPath
                readonly property var entry:
                    root.results[wallpaperDelegate.index] || ({})
                readonly property bool isCurrentWallpaper:
                    WallpaperService.normalizedPath(
                        wallpaperDelegate.entry.path)
                    === WallpaperService.normalizedPath(
                        WallpaperService.currentWallpaper
                        || WallpaperService.wallpaperForScreen(""))
                property bool appeared: false
                readonly property real initialX:
                    ((index * 37) % 3 - 1) * 24
                readonly property real initialY:
                    ((index * 53) % 5 - 2) * 10
                width: wallpaperGrid.cellWidth
                height: wallpaperGrid.cellHeight
                opacity: appeared ? 1 : 0
                scale: appeared ? 1 : 0.76
                rotation: appeared ? 0 : ((index % 3) - 1) * 3
                transform: Translate {
                    x: wallpaperDelegate.appeared
                        ? 0 : wallpaperDelegate.initialX
                    y: wallpaperDelegate.appeared
                        ? 0 : wallpaperDelegate.initialY
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 190
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation
                            .expressiveDefaultSpatial.duration
                        easing.type: Appearance.animation
                            .expressiveDefaultSpatial.type
                        easing.bezierCurve: Appearance.animation
                            .expressiveDefaultSpatial.bezierCurve
                    }
                }

                Behavior on rotation {
                    NumberAnimation {
                        duration: Appearance.animation
                            .expressiveDefaultSpatial.duration
                        easing.type: Appearance.animation
                            .expressiveDefaultSpatial.type
                        easing.bezierCurve: Appearance.animation
                            .expressiveDefaultSpatial.bezierCurve
                    }
                }

                Timer {
                    interval: Math.min(
                        260,
                        (wallpaperDelegate.index
                            % Math.max(1,
                                root.wallpaperColumnCount * 3)) * 18
                    ) + ((wallpaperDelegate.index * 29) % 5) * 8
                    running: root.mode === "wallpapers"
                    onTriggered: wallpaperDelegate.appeared = true
                }

                Rectangle {
                    id: wallpaperCard

                    anchors.fill: parent
                    anchors.margins: root.style.wallpaperGridGap / 2
                    radius: Appearance.rounding.large
                    color:
                        wallpaperDelegate.index === root.selectedIndex
                        ? root.style.selectedColor
                        : (wallpaperMouse.containsMouse
                            ? root.style.hoverColor
                            : "transparent")

                    Item {
                        id: previewFrame

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: width
                            / root.style.wallpaperPreviewAspectRatio

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: previewFrame.width
                                height: previewFrame.height
                                radius: Appearance.rounding.large
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: root.style.surfaceColor
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "image"
                            iconSize: 34
                            fill: 1
                            color: Appearance.colors.colOutline
                        }

                        Image {
                            id: wallpaperImage

                            anchors.fill: parent
                            source: wallpaperDelegate.entry.preview
                            sourceSize.width:
                                Math.ceil(previewFrame.width * 2)
                            sourceSize.height:
                                Math.ceil(previewFrame.height * 2)
                            asynchronous: true
                            cache: true
                            smooth: true
                            fillMode: Image.PreserveAspectCrop
                            scale: wallpaperMouse.containsMouse
                                ? root.style.wallpaperHoverScale : 1

                            Behavior on scale {
                                NumberAnimation {
                                    duration:
                                        root.style.wallpaperHoverDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve:
                                        root.style.wallpaperHoverCurve
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Appearance.applyAlpha(
                                Appearance.colors.colOnSurface,
                                wallpaperMouse.pressed
                                    ? root.style
                                        .wallpaperPressedOverlayOpacity
                                    : (wallpaperMouse.containsMouse
                                        ? root.style
                                            .wallpaperHoverOverlayOpacity
                                        : 0)
                            )

                            Behavior on color {
                                ColorAnimation {
                                    duration:
                                        root.style.wallpaperHoverDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve:
                                        root.style.wallpaperHoverCurve
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            width: root.style.wallpaperCurrentMarkSize
                            height: width
                            radius: width / 2
                            color:
                                Appearance.colors.colPrimaryContainer
                            visible:
                                wallpaperDelegate.isCurrentWallpaper

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 19
                                fill: 1
                                color:
                                    Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    Text {
                        id: wallpaperLabel

                        anchors.top: previewFrame.bottom
                        anchors.topMargin: root.style.wallpaperLabelGap
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: root.style.wallpaperLabelHeight
                        text: wallpaperDelegate.entry.title
                        color:
                            wallpaperDelegate.index === root.selectedIndex
                            ? root.style.selectedContentColor
                            : Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize:
                            root.style.wallpaperLabelFontSize
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideMiddle
                        textFormat: Text.PlainText
                    }
                }

                MouseArea {
                    id: wallpaperMouse

                    anchors.fill: wallpaperCard
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    Accessible.name: wallpaperDelegate.entry.title
                    Accessible.role: Accessible.ListItem
                    onClicked: {
                        root.selectionRequested(wallpaperDelegate.index);
                        root.activationRequested(
                            wallpaperDelegate.index, false);
                    }
                }
            }
        }

        ColumnLayout {
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 46

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.providerAvailable && !root.canRestore
                        ? qsTr("缺少 wl-copy：恢复功能不可用")
                        : qsTr("剪贴板历史")
                    color: root.providerAvailable && !root.canRestore
                        ? Appearance.colors.colError
                        : Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                ActionButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: root.providerAvailable
                        && !root.loading && !root.clipboardActionRunning
                        && root.results.length > 0
                    filled: false
                    iconName: "delete_sweep"
                    text: qsTr("清空")
                    onClicked: clearDialog.open()
                }
            }

            ListView {
                id: clipboardList

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 0
                model: root.mode === "clipboard" ? root.clipboardModel : []
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: clipboardDelegate

                    required property int index
                    required property string clipboardEntryId
                    readonly property int detailsRevision:
                        ClipboardService.detailsRevision
                    readonly property var clipboardEntry: {
                        // The ListModel carries only the stable ID.  Keeping
                        // the result object in the provider's JS array avoids
                        // QVariant role type changes when a lightweight row
                        // is replaced by its inspected detail.
                        const currentResults = root.results;
                        const id = clipboardDelegate.clipboardEntryId;
                        for (let resultIndex = 0;
                                resultIndex < currentResults.length;
                                resultIndex += 1) {
                            const result = currentResults[resultIndex];
                            if (String(result.id || "") === id)
                                return result;
                        }
                        return {};
                    }
                    readonly property var displayData: {
                        // ClipboardService stores inspection results in a
                        // keyed object.  The revision is an explicit
                        // dependency because dynamic object keys do not
                        // produce QML notifications.
                        const ignoredRevision =
                            clipboardDelegate.detailsRevision;
                        const detail = ClipboardService.detail(
                            String(clipboardDelegate.clipboardEntry.id || ""));
                        if (!detail)
                            return clipboardDelegate.clipboardEntry;
                        return Object.assign(
                            {}, clipboardDelegate.clipboardEntry, detail);
                    }
                    readonly property bool actionForThis:
                        String(clipboardEntry.id)
                            === root.clipboardActionEntryId
                    readonly property alias activationArea: clipboardMouse
                    readonly property alias textArea: clipboardTextColumn
                    readonly property alias actionArea: clipboardActionArea
                    readonly property alias titleLabel: clipboardTitle
                    readonly property alias subtitleLabel: clipboardSubtitle
                    width: ListView.view.width
                    height: root.style.resultRowHeight

                    Component.onCompleted:
                        root.inspectionRequested(
                            String(clipboardDelegate.clipboardEntry.id))
                    Component.onDestruction:
                        root.inspectionReleased(
                            String(clipboardDelegate.clipboardEntry.id))

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color:
                            clipboardDelegate.index === root.selectedIndex
                            ? root.style.selectedColor
                            : (clipboardMouse.containsMouse
                                ? root.style.hoverColor
                                : "transparent")
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 6
                        spacing: 13

                        Item {
                            Layout.preferredWidth: 42
                            Layout.minimumWidth: 42
                            Layout.maximumWidth: 42
                            Layout.preferredHeight: 42
                            Layout.minimumHeight: 42
                            Layout.maximumHeight: 42

                            Item {
                                id: clipboardPreviewFrame

                                anchors.fill: parent
                                visible:
                                    String(clipboardDelegate
                                        .displayData.previewUrl || "") !== ""
                                layer.enabled: visible
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: clipboardPreviewFrame.width
                                        height: clipboardPreviewFrame.height
                                        radius: Appearance.rounding.large
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: root.style.hoverColor
                                }

                                Image {
                                    anchors.fill: parent
                                    source: clipboardDelegate
                                        .displayData.previewUrl || ""
                                    sourceSize.width: 96
                                    sourceSize.height: 96
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: !clipboardPreviewFrame.visible
                                text: clipboardDelegate.displayData.icon
                                iconSize: 24
                                color:
                                    clipboardDelegate.index
                                        === root.selectedIndex
                                    ? root.style.selectedContentColor
                                    : Appearance.colors.colPrimary
                            }
                        }

                        ColumnLayout {
                            id: clipboardTextColumn

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            clip: true
                            spacing: 1

                            Text {
                                id: clipboardTitle

                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: clipboardDelegate.displayData.title
                                color:
                                    clipboardDelegate.index
                                        === root.selectedIndex
                                    ? root.style.selectedContentColor
                                    : Appearance.colors.colOnSurface
                                font.family: Fonts.ui
                                textFormat: Text.PlainText
                                font.pixelSize: 16
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                                clip: true
                            }

                            Text {
                                id: clipboardSubtitle

                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: clipboardDelegate.actionForThis
                                    && root.clipboardActionState === "error"
                                    && root.clipboardActionError !== ""
                                    ? root.clipboardActionError
                                    : clipboardDelegate.displayData.subtitle
                                color:
                                    clipboardDelegate.index
                                        === root.selectedIndex
                                    ? root.style.selectedContentColor
                                    : Appearance.colors.colOnSurfaceVariant
                                font.family: Fonts.ui
                                textFormat: Text.PlainText
                                font.pixelSize: 12
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                                clip: true
                            }
                        }

                        Item {
                            id: clipboardActionArea

                            Layout.preferredWidth: 92
                            Layout.minimumWidth: 92
                            Layout.maximumWidth: 92
                            Layout.preferredHeight: 42
                            Layout.minimumHeight: 42
                            Layout.maximumHeight: 42

                            IconButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                controlSize: 42
                                visible: !clipboardDelegate.actionForThis
                                    || root.clipboardActionState === "idle"
                                enabled: !root.clipboardActionRunning
                                iconName: "delete"
                                iconSize: 20
                                iconColor:
                                    Appearance.colors.colOnSurfaceVariant
                                accessibleName:
                                    qsTr("删除剪贴板条目")
                                onClicked:
                                    root.deleteRequested(
                                        clipboardDelegate.index)
                            }

                            BusyIndicator {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                visible: clipboardDelegate.actionForThis
                                    && root.clipboardActionState
                                        === "copying"
                                running: visible
                                Material.accent:
                                    Appearance.colors.colPrimary
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                visible: clipboardDelegate.actionForThis
                                    && (root.clipboardActionState === "copied"
                                        || root.clipboardActionState
                                            === "error")

                                MaterialSymbol {
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    text: root.clipboardActionState
                                        === "copied" ? "check" : "error"
                                    iconSize: 18
                                    fill: 1
                                    color: root.clipboardActionState
                                        === "copied"
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colError
                                }

                                Text {
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    text: root.clipboardActionState
                                        === "copied"
                                        ? qsTr("已复制") : qsTr("复制失败")
                                    color: root.clipboardActionState
                                        === "copied"
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colError
                                    font.family: Fonts.ui
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: clipboardMouse

                        anchors.fill: parent
                        anchors.rightMargin: 96
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        Accessible.name: clipboardDelegate.displayData.title
                        Accessible.role: Accessible.ListItem
                        onClicked: mouse => {
                            root.selectionRequested(
                                clipboardDelegate.index);
                            root.activationRequested(
                                clipboardDelegate.index,
                                (mouse.modifiers
                                    & Qt.ControlModifier) !== 0);
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: root.clipboardHeaderHeight
        visible: root.loading || !root.providerAvailable
            || root.results.length === 0
        opacity: root.contentOpacity

        Column {
            anchors.centerIn: parent
            spacing: 10

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: root.loading
                visible: root.loading
                Material.accent: Appearance.colors.colPrimary
            }

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.loading
                text: !root.providerAvailable
                    ? "content_paste_off" : "search_off"
                iconSize: 32
                color: Appearance.colors.colOnSurfaceVariant
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(520, root.width - 48)
                text: root.loading
                    ? qsTr("正在读取…")
                    : (!root.providerAvailable
                        ? (root.providerError
                            ? root.providerError.message
                            : qsTr("当前 Provider 不可用"))
                        : qsTr("没有匹配结果"))
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 15
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }

    MaterialDialog {
        id: clearDialog

        anchors.centerIn: Overlay.overlay
        width: 380
        dialogTitle: qsTr("清空剪贴板历史？")
        messageText: qsTr("此操作会清除 cliphist 中的全部历史记录，无法撤销。")

        actionsComponent: Component {
            RowLayout {
                spacing: Metrics.spacingS

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    id: cancelButton

                    text: qsTr("取消")
                    Component.onCompleted:
                        clearDialog.initialFocusItem = cancelButton
                    onClicked: clearDialog.close()
                }

                ActionButton {
                    text: qsTr("清空")
                    onClicked: {
                        root.clearRequested();
                        clearDialog.close();
                    }
                }
            }
        }
        onClosed: root.modalClosed()
    }
}
