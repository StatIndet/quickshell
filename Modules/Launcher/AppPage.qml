import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets.common

import "../../Common/functions/AppManager.js" as AppManager

Item {
    id: root

    signal requestCloseLauncher()

    property string query: ""
    property var filteredAppsModel: []

    RofiStyle {
        id: rofiStyle
    }

    function decrementCurrentIndex() { setCurrentIndex(appsList.currentIndex - 1) }
    function incrementCurrentIndex() { setCurrentIndex(appsList.currentIndex + 1) }

    function setCurrentIndex(index) {
        if (filteredAppsModel.length === 0) {
            appsList.currentIndex = -1
            appsList.contentY = 0
            return
        }

        appsList.currentIndex = Math.max(0, Math.min(index, filteredAppsModel.length - 1))
        ensureCurrentVisible()
    }

    function ensureCurrentVisible() {
        if (appsList.currentIndex < 0)
            return

        let firstVisibleIndex = Math.round(appsList.contentY / rofiStyle.listStep)
        if (appsList.currentIndex < firstVisibleIndex)
            firstVisibleIndex = appsList.currentIndex
        else if (appsList.currentIndex >= firstVisibleIndex + rofiStyle.listRows)
            firstVisibleIndex = appsList.currentIndex - rofiStyle.listRows + 1

        const maxFirstIndex = Math.max(0, filteredAppsModel.length - rofiStyle.listRows)
        firstVisibleIndex = Math.max(0, Math.min(firstVisibleIndex, maxFirstIndex))
        appsList.contentY = firstVisibleIndex * rofiStyle.listStep
    }

    function search(text) {
        filteredAppsModel = AppManager.updateFilter(text, DesktopEntries)
        appsList.contentY = 0
        setCurrentIndex(0)
    }

    Timer {
        id: startupPollTimer
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (DesktopEntries.applications.values.length > 0) {
                root.search(root.query)
                running = false
            }
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

    function fallbackIconSource() {
        const fallback = Quickshell.iconPath("application-x-executable", "");
        return fallback && fallback !== "" ? fallback : "image://icon/application-x-executable";
    }

    function iconSource(icon) {
        if (!icon || icon === "")
            return fallbackIconSource();
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.startsWith("file://") || icon.startsWith("image://"))
            return icon;

        const resolved = Quickshell.iconPath(icon, "application-x-executable");
        return resolved && resolved !== "" ? resolved : fallbackIconSource();
    }

    StyledListView {
        id: appsList
        width: parent.width
        height: rofiStyle.listHeight
        anchors.top: parent.top
        clip: true
        spacing: rofiStyle.listSpacing
        animateAppearance: false
        animateMovement: false
        showVerticalScrollBar: false
        smoothWheelEnabled: false

        model: filteredAppsModel

        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        highlightFollowsCurrentItem: true
        highlightRangeMode: ListView.NoHighlightRange

        highlight: Rectangle {
            width: appsList.width
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
                    runSelectedApp()
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

                        property bool fallbackApplied: false
                        readonly property string requestedSource: root.iconSource(modelData.icon)
                        readonly property string fallbackSource: root.fallbackIconSource()

                        source: fallbackApplied ? fallbackSource : requestedSource

                        onRequestedSourceChanged: fallbackApplied = false

                        onStatusChanged: {
                            if (status === Image.Error && !fallbackApplied && source !== fallbackSource)
                                fallbackApplied = true
                        }
                    }
                }

                Text {
                    text: root.highlightText(modelData.name, root.query)
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
            }
        }
    }

    function runSelectedApp() {
        if (filteredAppsModel.length > 0 && appsList.currentIndex >= 0) {
            let appData = filteredAppsModel[appsList.currentIndex]
            if (appData && appData.appObj)
                appData.appObj.execute()
            root.requestCloseLauncher()
        }
    }
}
