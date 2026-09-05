import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Services
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    required property SpotlightStyle style
    required property string mode
    required property bool modeRailExpanded
    required property int modeFocusIndex
    required property real railProgress
    required property real webProgress

    property alias text: searchInput.text
    property real requestedMainWidth: style.searchWidth
    readonly property real expandedMainWidth:
        Math.max(
            style.minimumExpandedSearchWidth,
            requestedMainWidth - style.railWidthContraction
        )
    readonly property real stableMainLeft:
        (width - requestedMainWidth) / 2
    readonly property real mainCenterX: morphSurface.mainCenterX
    readonly property real mainWidth: morphSurface.mainWidth
    readonly property real mainLeft: stableMainLeft
    readonly property real mainRight: mainLeft + mainWidth
    readonly property real webEngineProgress:
        style.smoothstep((webProgress - 0.36) / 0.44)
    readonly property real webTextProgress:
        style.smoothstep((webProgress - 0.5) / 0.5)
    readonly property real pressDepth:
        pressDepthForProgress(webProgress)
    readonly property real pressScaleX:
        pressScaleXForProgress(webProgress)
    readonly property real pressScaleY:
        pressScaleYForProgress(webProgress)
    readonly property real pressShadowBlur:
        shadowBlurForProgress(webProgress)
    readonly property real pressShadowVerticalOffset:
        shadowVerticalOffsetForProgress(webProgress)
    readonly property bool inputActiveFocus: searchInput.activeFocus
    readonly property var blurRegionItems:
        morphSurface.blurRegionItems

    signal routedKey(var event)
    signal modeClicked(int index)

    height: style.searchHeight + style.effectBleed * 2

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.pressScaleX
        yScale: root.pressScaleY
    }

    function pressDepthForProgress(progress) {
        if (progress <= 0.25)
            return style.smoothstep(progress / 0.25);
        if (progress <= 0.62)
            return 1 - style.smoothstep(
                (progress - 0.25) / 0.37);
        return 0;
    }

    function pressScaleXForProgress(progress) {
        return 1 - 0.015 * pressDepthForProgress(progress);
    }

    function pressScaleYForProgress(progress) {
        return 1 - 0.055 * pressDepthForProgress(progress);
    }

    function shadowBlurForProgress(progress) {
        return style.shadowBlur
            * (1 - 0.28 * pressDepthForProgress(progress));
    }

    function shadowVerticalOffsetForProgress(progress) {
        return style.shadowVerticalOffset
            - 3 * pressDepthForProgress(progress);
    }

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    function buttonCenterX(index) {
        return morphSurface.buttonCenterX(index);
    }

    function iconProgress(index) {
        return morphSurface.iconProgress(index);
    }

    function buttonBlend(index) {
        return morphSurface.buttonBlend(index);
    }

    function buttonBridgeRadius(index) {
        return morphSurface.buttonBridgeRadius(index);
    }

    function buttonRadius(index) {
        return morphSurface.buttonRadius(index);
    }

    SpotlightModeMorphSurface {
        id: morphSurface

        anchors.fill: parent
        railProgress: root.railProgress
        mainLeft: root.stableMainLeft
        collapsedMainWidth: root.requestedMainWidth
        expandedMainWidth: root.expandedMainWidth
        shapeCenterY: height / 2
        shapeHeight: root.style.searchHeight
        buttonDiameter: root.style.modeButtonDiameter
        buttonGap: root.style.modeButtonGap
        blurEdgeInset: root.style.blurEdgeInset
        edgeSoftness: root.style.edgeSoftness
        staggerFraction:
            root.style.railStagger / root.style.railDuration
        surfaceColor: root.style.surfaceColor
        shadowColor: root.style.shadowColor
        shadowBlur: root.pressShadowBlur
        shadowVerticalOffset: root.pressShadowVerticalOffset
    }

    Item {
        id: mainContent

        x: root.mainLeft
        y: root.style.effectBleed
        width: root.mainWidth
        height: root.style.searchHeight
        clip: true

        MaterialSymbol {
            id: searchIcon

            x: root.style.searchHorizontalPadding
            anchors.verticalCenter: parent.verticalCenter
            width: root.style.searchIconSize
            height: width
            text: "search"
            iconSize: root.style.searchIconSize
            color: Appearance.colors.colOnSurfaceVariant
        }

        Rectangle {
            id: enginePill

            x: searchIcon.x + searchIcon.width + 12
            anchors.verticalCenter: parent.verticalCenter
            width: root.style.enginePillWidth * root.webEngineProgress
            height: root.style.enginePillHeight
            radius: Appearance.rounding.full
            color: Appearance.colors.colSecondaryContainer
            opacity: root.webEngineProgress
            scale: 0.92 + 0.08 * root.webEngineProgress
            clip: true

            Text {
                anchors.centerIn: parent
                text: SpotlightSearchService.searchEngineName
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Fonts.ui
                font.pixelSize: 14
                font.weight: Font.DemiBold
                opacity: root.webEngineProgress
            }
        }

        Item {
            id: inputArea

            x: searchIcon.x + searchIcon.width + 14
                + (root.style.enginePillWidth + 10)
                    * root.webTextProgress
            width: parent.width - x - root.style.searchHorizontalPadding
            height: parent.height

            Text {
                anchors.fill: parent
                text: qsTr("搜索应用")
                color: Appearance.applyAlpha(
                    Appearance.colors.colOnSurfaceVariant, 0.72)
                font.family: Fonts.ui
                font.pixelSize: 20
                verticalAlignment: Text.AlignVCenter
                opacity: searchInput.text.length === 0
                    ? 1 - root.webTextProgress : 0
                elide: Text.ElideRight
            }

            Text {
                anchors.fill: parent
                text: qsTr("搜索网页")
                color: Appearance.applyAlpha(
                    Appearance.colors.colOnSurfaceVariant, 0.72)
                font.family: Fonts.ui
                font.pixelSize: 20
                verticalAlignment: Text.AlignVCenter
                opacity: searchInput.text.length === 0
                    ? root.webTextProgress : 0
                elide: Text.ElideRight
            }

            TextInput {
                id: searchInput

                anchors.fill: parent
                color: Appearance.colors.colOnSurface
                selectionColor: Appearance.colors.colPrimary
                selectedTextColor: Appearance.colors.colOnPrimary
                font.family: Fonts.ui
                font.pixelSize: 20
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                clip: true
                focus: true
                activeFocusOnTab: false

                Accessible.name: root.mode === "web"
                    ? qsTr("网页搜索") : qsTr("聚焦搜索")
                Accessible.role: Accessible.EditableText

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => root.routedKey(event)
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            onPressed: mouse => {
                root.focusInput();
                mouse.accepted = false;
            }
        }
    }

    Repeater {
        model: [
            { icon: "apps", label: qsTr("应用") },
            { icon: "wallpaper", label: qsTr("壁纸") },
            { icon: "content_paste", label: qsTr("剪贴板") }
        ]

        delegate: Item {
            id: modeButton

            required property int index
            required property var modelData
            readonly property real reveal: root.iconProgress(index)
            readonly property bool logicalFocus:
                root.modeRailExpanded && root.modeFocusIndex === index
            readonly property bool activeMode:
                (index === 0 && root.mode === "apps")
                || (index === 1 && root.mode === "wallpapers")
                || (index === 2 && root.mode === "clipboard")

            x: root.buttonCenterX(index)
                - root.style.modeButtonDiameter / 2
            y: root.height / 2 - root.style.modeButtonDiameter / 2
            width: root.style.modeButtonDiameter
            height: width
            opacity: reveal
            scale: 0.9 + reveal * 0.1

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: modeMouse.pressed
                    ? Appearance.applyAlpha(
                        root.style.selectedColor, 0.46)
                    : (modeButton.logicalFocus
                        ? Appearance.applyAlpha(
                            root.style.selectedColor, 0.34)
                        : (modeMouse.containsMouse
                            ? Appearance.applyAlpha(
                                root.style.hoverColor, 0.42)
                        : "transparent")
                    )
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: modeButton.modelData.icon
                iconSize: 23
                fill: modeButton.activeMode ? 1 : 0
                color: modeButton.logicalFocus || modeButton.activeMode
                    ? root.style.selectedContentColor
                    : Appearance.colors.colOnSurfaceVariant
            }

            MouseArea {
                id: modeMouse

                anchors.fill: parent
                enabled: modeButton.reveal > 0.55
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                Accessible.name: modeButton.modelData.label
                Accessible.role: Accessible.Button

                onClicked: {
                    root.modeClicked(modeButton.index);
                    root.focusInput();
                }
            }

            StyledToolTip {
                extraVisibleCondition:
                    modeMouse.containsMouse && modeMouse.enabled
                text: modeButton.modelData.label
            }
        }
    }
}
