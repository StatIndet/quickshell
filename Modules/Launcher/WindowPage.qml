import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Clavis.Niri 1.0
import qs.Common
import qs.Widgets.common

Item {
    id: root

    signal requestCloseLauncher()

    property string query: ""
    property var filteredWindows: []

    RofiStyle {
        id: rofiStyle
    }

    function decrementCurrentIndex() { setCurrentIndex(windowsList.currentIndex - 1) }
    function incrementCurrentIndex() { setCurrentIndex(windowsList.currentIndex + 1) }

    function setCurrentIndex(index) {
        if (filteredWindows.length === 0) {
            windowsList.currentIndex = -1
            windowsList.contentY = 0
            return
        }

        windowsList.currentIndex = Math.max(0, Math.min(index, filteredWindows.length - 1))
        ensureCurrentVisible()
    }

    function ensureCurrentVisible() {
        if (windowsList.currentIndex < 0)
            return

        let firstVisibleIndex = Math.round(windowsList.contentY / rofiStyle.listStep)
        if (windowsList.currentIndex < firstVisibleIndex)
            firstVisibleIndex = windowsList.currentIndex
        else if (windowsList.currentIndex >= firstVisibleIndex + rofiStyle.listRows)
            firstVisibleIndex = windowsList.currentIndex - rofiStyle.listRows + 1

        const maxFirstIndex = Math.max(0, filteredWindows.length - rofiStyle.listRows)
        firstVisibleIndex = Math.max(0, Math.min(firstVisibleIndex, maxFirstIndex))
        windowsList.contentY = firstVisibleIndex * rofiStyle.listStep
    }

    function cleanAppName(rawName, isAppId) {
        if (!rawName) return ""
        let name = rawName

        if (isAppId) {
            name = name.replace(/^([a-z0-9\-]+\.)+/gi, "")
            name = name.replace(/\.desktop$/gi, "")
        } else {
            name = name.replace(/\s*[-—|]\s*(Mozilla Firefox|Google Chrome|Chromium|Brave|Edge|Vivaldi|Visual Studio Code|Kate|KWrite).*$/gi, "")
        }

        return name
    }

    function search(text) {
        filteredWindows = Niri.searchWindows(text)
        windowsList.contentY = 0
        setCurrentIndex(0)
    }

    Connections {
        target: Niri
        function onWindowsChanged() {
            if (root.visible)
                root.search(root.query)
        }
    }

    onQueryChanged: search(query)

    onVisibleChanged: {
        if (visible)
            search(query)
    }

    function highlightText(fullText, query) {
        let safeText = fullText.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        if (!query || query.trim() === "") return safeText
        let escapedQuery = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        let regex = new RegExp("(" + escapedQuery + ")", "gi")
        return safeText.replace(regex, "<u><b>$1</b></u>")
    }

    Text {
        anchors.centerIn: parent
        text: "No windows opened."
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Sizes.fontFamilyMono
        font.pixelSize: rofiStyle.fontPixelSize
        visible: root.filteredWindows.length === 0
    }

    StyledListView {
        id: windowsList
        width: parent.width
        height: rofiStyle.listHeight
        anchors.top: parent.top
        clip: true
        spacing: rofiStyle.listSpacing
        animateAppearance: false
        animateMovement: false
        showVerticalScrollBar: false
        smoothWheelEnabled: false
        visible: root.filteredWindows.length > 0

        model: root.filteredWindows

        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        highlightFollowsCurrentItem: true
        highlightRangeMode: ListView.NoHighlightRange

        highlight: Rectangle {
            width: windowsList.width
            height: rofiStyle.rowHeight
            color: Appearance.colors.colPrimary
            radius: rofiStyle.controlRadius
        }
        highlightMoveDuration: 0

        delegate: Item {
            id: delegateItem
            width: ListView.view.width
            height: rofiStyle.rowHeight

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.setCurrentIndex(index)
                    focusSelectedWindow()
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: rofiStyle.itemPadding
                spacing: rofiStyle.itemSpacing

                Item {
                    Layout.preferredWidth: rofiStyle.iconSize
                    Layout.preferredHeight: rofiStyle.iconSize
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.fill: parent
                        sourceSize.width: rofiStyle.iconSize * 2
                        sourceSize.height: rofiStyle.iconSize * 2
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        source: modelData.iconPath || "image://icon/application-x-executable"
                    }
                }

                Text {
                    text: root.highlightText(root.cleanAppName(modelData.title, false), root.query)
                    textFormat: Text.StyledText
                    color: delegateItem.ListView.isCurrentItem ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: rofiStyle.fontPixelSize
                    font.bold: false
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.highlightText(root.cleanAppName(modelData.appName || modelData.appId, true), root.query)
                    textFormat: Text.StyledText
                    color: delegateItem.ListView.isCurrentItem ? Appearance.applyAlpha(Appearance.colors.colOnSecondary, 0.7) : Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: rofiStyle.secondaryFontPixelSize
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    function focusSelectedWindow() {
        if (root.filteredWindows.length > 0 && windowsList.currentIndex >= 0) {
            let win = root.filteredWindows[windowsList.currentIndex]
            Niri.focusWindow(win.id)
        }
    }
}
