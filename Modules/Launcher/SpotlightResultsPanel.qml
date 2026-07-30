import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Common
import qs.Components

Item {
    id: root

    required property SpotlightStyle style
    required property string mode
    required property var results
    required property int selectedIndex

    property bool expanded: mode !== "web"
    property bool loading: false
    property bool providerAvailable: true
    property bool canRestore: true
    property var providerError: null
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
    signal activationRequested(int index)
    signal deleteRequested(int index)
    signal clearRequested()

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
        property real radius: root.style.resultRadius
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
                            font.family: Sizes.fontFamily
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
                            font.family: Sizes.fontFamily
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
                        root.activationRequested(appDelegate.index);
                    }
                }
            }
        }

        GridView {
            id: wallpaperGrid

            clip: true
            model: root.mode === "wallpapers" ? root.results : []
            currentIndex: root.selectedIndex
            cellWidth: root.wallpaperCellWidth
            cellHeight: root.wallpaperCellHeight
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: wallpaperDelegate

                required property int index
                required property var modelData
                width: wallpaperGrid.cellWidth
                height: wallpaperGrid.cellHeight

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
                            source: wallpaperDelegate.modelData.preview
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
                                wallpaperDelegate.modelData.current === true

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
                        text: wallpaperDelegate.modelData.title
                        color:
                            wallpaperDelegate.index === root.selectedIndex
                            ? root.style.selectedContentColor
                            : Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
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
                    Accessible.name: wallpaperDelegate.modelData.title
                    Accessible.role: Accessible.ListItem
                    onClicked: {
                        root.selectionRequested(wallpaperDelegate.index);
                        root.activationRequested(wallpaperDelegate.index);
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
                    font.family: Sizes.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                ToolButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: root.providerAvailable
                        && !root.loading && root.results.length > 0
                    onClicked: clearDialog.open()

                    contentItem: Row {
                        spacing: 6

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "delete_sweep"
                            iconSize: 19
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("清空")
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Sizes.fontFamily
                            font.pixelSize: 13
                        }
                    }
                }
            }

            ListView {
                id: clipboardList

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 0
                model: root.mode === "clipboard" ? root.results : []
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: clipboardDelegate

                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    height: root.style.resultRowHeight

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

                        MaterialSymbol {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            text: clipboardDelegate.modelData.icon
                            iconSize: 23
                            color:
                                clipboardDelegate.index
                                    === root.selectedIndex
                                ? root.style.selectedContentColor
                                : Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: clipboardDelegate.modelData.title
                                color:
                                    clipboardDelegate.index
                                        === root.selectedIndex
                                    ? root.style.selectedContentColor
                                    : Appearance.colors.colOnSurface
                                font.family: Sizes.fontFamily
                                font.pixelSize: 16
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: clipboardDelegate.modelData.subtitle
                                color:
                                    clipboardDelegate.index
                                        === root.selectedIndex
                                    ? root.style.selectedContentColor
                                    : Appearance.colors.colOnSurfaceVariant
                                font.family: Sizes.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        ToolButton {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            onClicked:
                                root.deleteRequested(
                                    clipboardDelegate.index)
                            Accessible.name: qsTr("删除剪贴板条目")

                            contentItem: MaterialSymbol {
                                text: "delete"
                                iconSize: 20
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    MouseArea {
                        id: clipboardMouse

                        anchors.fill: parent
                        anchors.rightMargin: 46
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.canRestore
                        Accessible.name: clipboardDelegate.modelData.title
                        Accessible.role: Accessible.ListItem
                        onClicked: {
                            root.selectionRequested(
                                clipboardDelegate.index);
                            root.activationRequested(
                                clipboardDelegate.index);
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
                font.family: Sizes.fontFamily
                font.pixelSize: 15
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }

    Dialog {
        id: clearDialog

        anchors.centerIn: Overlay.overlay
        modal: true
        title: qsTr("清空剪贴板历史？")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: root.clearRequested()

        Text {
            width: 320
            text: qsTr("此操作会清除 cliphist 中的全部历史记录，无法撤销。")
            color: Appearance.colors.colOnSurface
            font.family: Sizes.fontFamily
            font.pixelSize: 14
            wrapMode: Text.Wrap
        }
    }
}
