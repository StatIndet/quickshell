import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Quickshell
import Clavis.Weather 1.0
import Clavis.WeatherMap 1.0
import qs.Common
import qs.Components
import qs.Modules.Keystone.WeatherContent
import qs.Services
import qs.Widgets.common

// Loaded on demand so a missing native plugin cannot block Control Center.
StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 28

    readonly property real pageContentWidth: 600
    property bool revealApiKey: false
    property string feedbackText: ""
    property bool feedbackError: false
    property string selectedMapMode: "temp"
    property string locationFeedback: ""
    property bool locationFeedbackError: false

    Component.onCompleted: {
        if (!WeatherPlugin.hasValidData && !WeatherPlugin.loading)
            WeatherPlugin.refresh()
    }

    function applyApiKey() {
        const value = apiKeyField.text.trim()
        if (value.length < 16) {
            feedbackError = true
            feedbackText = qsTr("请输入有效的 OpenWeather API key")
            apiKeyField.forceActiveFocus()
            return
        }

        const result = WeatherMapPlugin.storeApiKey(value)
        feedbackError = !result.ok
        feedbackText = result.message || qsTr("无法更新 API key")
    }

    function clearApiKey() {
        const result = WeatherMapPlugin.clearApiKey()
        feedbackError = !result.ok
        feedbackText = result.message || qsTr("无法清除 API key")
    }

    function notifyLocation(latitude, longitude, name) {
        Quickshell.execDetached([
            "qs", "--path", Paths.shellDir + "/shell.qml",
            "ipc", "call", "weather", "setLocation",
            String(latitude), String(longitude), name
        ])
    }

    function applyLocation(latitude, longitude, name) {
        const lat = Number(latitude)
        const lon = Number(longitude)
        const label = String(name || "").trim()
        if (!label.length || !isFinite(lat) || lat < -90 || lat > 90
                || !isFinite(lon) || lon < -180 || lon > 180) {
            locationFeedbackError = true
            locationFeedback = qsTr("请输入有效的位置名称、纬度和经度")
            return
        }
        WeatherPlugin.setManualLocation(lat, lon, label)
        notifyLocation(lat, lon, label)
        locationFeedbackError = false
        locationFeedback = qsTr("天气位置已更新：") + label
    }

    function useIpLocation() {
        WeatherPlugin.clearManualLocation()
        Quickshell.execDetached([
            "qs", "--path", Paths.shellDir + "/shell.qml",
            "ipc", "call", "weather", "useIpLocation"
        ])
        locationFeedbackError = false
        locationFeedback = qsTr("已切换为 IP 自动定位")
    }

    function notifyMainShell() {
        Quickshell.execDetached([
            "qs",
            "--path",
            Paths.shellDir + "/shell.qml",
            "ipc",
            "call",
            "weather-map",
            "reloadCredentials"
        ])
    }

    Connections {
        target: WeatherMapPlugin

        function onCredentialOperationFinished(operation, success, message) {
            if (operation !== "openweather_store"
                && operation !== "openweather_clear") {
                return
            }

            root.feedbackError = !success
            root.feedbackText = message
            if (success
                && (operation === "openweather_store"
                    || operation === "openweather_clear")) {
                apiKeyField.clear()
                root.revealApiKey = false
                root.notifyMainShell()
            }
        }
    }

    ColumnLayout {
        id: contentColumn

        width: root.pageContentWidth
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: 24

        WeatherMapCard {
            id: weatherMap

            Layout.fillWidth: true
            Layout.preferredHeight: 320
            latitude: Number(WeatherPlugin.latitude)
            longitude: Number(WeatherPlugin.longitude)
            locationAvailable: WeatherPlugin.hasValidData
            active: root.visible
            selectedMode: root.selectedMapMode
            showLayerSelector: false
        }

        WeatherMapLayerSelector {
            Layout.alignment: Qt.AlignHCenter
            currentMode: root.selectedMapMode
            onModeSelected: mode => root.selectedMapMode = mode
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialSymbol {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                text: "partly_cloudy_day"
                iconSize: 30
                fill: 1
                color: Appearance.colors.colOnSecondaryContainer
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: qsTr("天气")
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("配置 Keystone 天气地图服务")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    textFormat: Text.PlainText
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: locationContent.implicitHeight + 48
            radius: Appearance.rounding.large
            color: Appearance.colors.colSurfaceContainer

            ColumnLayout {
                id: locationContent
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimaryContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "location_on"
                            iconSize: 22
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("天气位置")
                            color: Appearance.colors.colOnSurface
                            font.family: Sizes.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (WeatherPlugin.locationName || qsTr("未知"))
                                + "  ·  "
                                + Number(WeatherPlugin.latitude).toFixed(4)
                                + ", "
                                + Number(WeatherPlugin.longitude).toFixed(4)
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Sizes.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    Button {
                        text: qsTr("使用 IP 定位")
                        flat: true
                        onClicked: root.useIpLocation()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                Text {
                    text: qsTr("搜索地点")
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialTextField {
                        id: locationSearchField
                        Layout.fillWidth: true
                        placeholderText: qsTr("输入地点，例如：上海五角场")
                        Material.containerStyle: Material.Outlined
                        onAccepted: WeatherPlugin.searchLocations(text)
                    }

                    Button {
                        text: WeatherPlugin.locationSearchLoading
                            ? qsTr("搜索中") : qsTr("搜索")
                        highlighted: true
                        enabled: !WeatherPlugin.locationSearchLoading
                            && locationSearchField.text.trim().length >= 2
                        onClicked:
                            WeatherPlugin.searchLocations(locationSearchField.text)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: WeatherPlugin.locationSearchError.length > 0
                    text: WeatherPlugin.locationSearchError
                    color: Appearance.colors.colError
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                }

                Repeater {
                    model: WeatherPlugin.locationSearchResults

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: Appearance.rounding.normal
                        color: resultMouse.containsMouse
                            ? Appearance.colors.colSurfaceContainerHighest
                            : Appearance.colors.colSurfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 10

                            MaterialSymbol {
                                text: "location_on"
                                iconSize: 20
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: Appearance.colors.colOnSurface
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: Number(modelData.latitude).toFixed(5)
                                        + ", "
                                        + Number(modelData.longitude).toFixed(5)
                                    color: Appearance.colors.colOnSurfaceVariant
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: 11
                                }
                            }

                            MaterialSymbol {
                                text: "chevron_right"
                                iconSize: 20
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }

                        MouseArea {
                            id: resultMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyLocation(
                                modelData.latitude, modelData.longitude,
                                modelData.name)
                        }
                    }
                }

                Text {
                    text: qsTr("手动输入坐标")
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialTextField {
                        id: manualNameField
                        Layout.fillWidth: true
                        placeholderText: qsTr("位置名称")
                        Material.containerStyle: Material.Outlined
                    }

                    MaterialTextField {
                        id: manualLatitudeField
                        Layout.preferredWidth: 125
                        placeholderText: qsTr("纬度")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        Material.containerStyle: Material.Outlined
                    }

                    MaterialTextField {
                        id: manualLongitudeField
                        Layout.preferredWidth: 125
                        placeholderText: qsTr("经度")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        Material.containerStyle: Material.Outlined
                    }

                    Button {
                        text: qsTr("应用")
                        highlighted: true
                        onClicked: root.applyLocation(
                            manualLatitudeField.text,
                            manualLongitudeField.text,
                            manualNameField.text)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight:
                        locationFeedbackRow.implicitHeight + 20
                    radius: Appearance.rounding.small
                    visible: root.locationFeedback.length > 0
                    color: root.locationFeedbackError
                        ? Appearance.colors.colErrorContainer
                        : Appearance.colors.colPrimaryContainer

                    RowLayout {
                        id: locationFeedbackRow
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        MaterialSymbol {
                            text: root.locationFeedbackError
                                ? "error" : "check_circle"
                            iconSize: 18
                            fill: 1
                            color: root.locationFeedbackError
                                ? Appearance.colors.colOnErrorContainer
                                : Appearance.colors.colOnPrimaryContainer
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.locationFeedback
                            color: root.locationFeedbackError
                                ? Appearance.colors.colOnErrorContainer
                                : Appearance.colors.colOnPrimaryContainer
                            font.family: Sizes.fontFamily
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: serviceContent.implicitHeight + 48
            radius: Appearance.rounding.large
            color: Appearance.colors.colSurfaceContainer

            ColumnLayout {
                id: serviceContent

                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimaryContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "key"
                            iconSize: 22
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "OpenWeather Weather Maps"
                            color: Appearance.colors.colOnSurface
                            font.family: Sizes.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            textFormat: Text.PlainText
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("用于天气数据覆盖层")
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Sizes.fontFamily
                            font.pixelSize: 12
                            textFormat: Text.PlainText
                        }
                    }

                    Rectangle {
                        implicitWidth: statusContent.implicitWidth + 24
                        implicitHeight: 34
                        radius: Appearance.rounding.full
                        color: WeatherMapPlugin.apiConfigured
                            ? Appearance.colors.colPrimaryContainer
                            : Appearance.colors.colSurfaceContainerHighest

                        RowLayout {
                            id: statusContent

                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                text: !WeatherMapPlugin.credentialsReady
                                    || WeatherMapPlugin.credentialBusy
                                    ? "sync"
                                    : WeatherMapPlugin.apiConfigured
                                        ? "check_circle"
                                        : "key_off"
                                iconSize: 17
                                fill: WeatherMapPlugin.apiConfigured ? 1 : 0
                                color: WeatherMapPlugin.apiConfigured
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colOnSurfaceVariant
                            }

                            Text {
                                id: serviceStatus

                                text: !WeatherMapPlugin.credentialsReady
                                    ? qsTr("正在检查")
                                    : WeatherMapPlugin.credentialBusy
                                        ? qsTr("处理中")
                                        : WeatherMapPlugin.apiConfigured
                                            ? qsTr("已配置")
                                            : qsTr("未配置")
                                color: WeatherMapPlugin.apiConfigured
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colOnSurfaceVariant
                                font.family: Sizes.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                textFormat: Text.PlainText
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                Text {
                    Layout.fillWidth: true
                    text: "OpenWeather API key"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    textFormat: Text.PlainText
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56

                    MaterialTextField {
                        id: apiKeyField

                        anchors.fill: parent
                        placeholderText: qsTr("输入 OpenWeather API key")
                        echoMode: root.revealApiKey
                            ? TextInput.Normal
                            : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                            | Qt.ImhNoPredictiveText
                            | Qt.ImhNoAutoUppercase
                        maximumLength: 128
                        rightPadding: 52
                        enabled: WeatherMapPlugin.credentialsReady
                            && !WeatherMapPlugin.credentialBusy
                        color: Appearance.colors.colOnSurface
                        placeholderTextColor: Appearance.colors.colOnSurfaceVariant
                        Material.theme: PersonalizationConfig.themeMode === "light"
                            ? Material.Light
                            : Material.Dark
                        Material.containerStyle: Material.Outlined
                        Material.foreground: Appearance.colors.colOnSurface
                        Accessible.name: "OpenWeather API key"
                        Accessible.description: qsTr("安全保存到系统密钥环")
                        onTextChanged: {
                            if (root.feedbackError) {
                                root.feedbackError = false
                                root.feedbackText = ""
                            }
                        }
                        onAccepted: root.applyApiKey()
                    }

                    ToolButton {
                        id: visibilityButton

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: root.revealApiKey
                            ? qsTr("隐藏 API key")
                            : qsTr("显示 API key")
                        onClicked: root.revealApiKey = !root.revealApiKey

                        background: Rectangle {
                            radius: Appearance.rounding.full
                            color: visibilityButton.down
                                ? Appearance.colors.colLayer3Active
                                : visibilityButton.hovered
                                    || visibilityButton.activeFocus
                                    ? Appearance.colors.colLayer3Hover
                                    : "transparent"
                        }

                        contentItem: MaterialSymbol {
                            text: root.revealApiKey
                                ? "visibility_off"
                                : "visibility"
                            iconSize: 20
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        StyledToolTip {
                            extraVisibleCondition: visibilityButton.hovered
                            text: root.revealApiKey
                                ? qsTr("隐藏 API key")
                                : qsTr("显示 API key")
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("密钥保存在系统密钥环中，保存后立即生效。")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: feedbackRow.implicitHeight + 20
                    radius: Appearance.rounding.small
                    visible: root.feedbackText !== ""
                    color: root.feedbackError
                        ? Appearance.colors.colErrorContainer
                        : Appearance.colors.colPrimaryContainer

                    RowLayout {
                        id: feedbackRow

                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        MaterialSymbol {
                            text: WeatherMapPlugin.credentialBusy
                                ? "sync"
                                : root.feedbackError
                                    ? "error"
                                    : "check_circle"
                            iconSize: 18
                            fill: WeatherMapPlugin.credentialBusy ? 0 : 1
                            color: root.feedbackError
                                ? Appearance.colors.colOnErrorContainer
                                : Appearance.colors.colOnPrimaryContainer
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.feedbackText
                            color: root.feedbackError
                                ? Appearance.colors.colOnErrorContainer
                                : Appearance.colors.colOnPrimaryContainer
                            font.family: Sizes.fontFamily
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            textFormat: Text.PlainText
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        text: qsTr("清除密钥")
                        flat: true
                        enabled: WeatherMapPlugin.apiConfigured
                            && !WeatherMapPlugin.credentialBusy
                        focusPolicy: Qt.StrongFocus
                        Material.foreground: Appearance.colors.colOnSurfaceVariant
                        Accessible.description: qsTr("从系统密钥环移除 OpenWeather API key")
                        onClicked: root.clearApiKey()
                    }

                    Button {
                        id: saveButton

                        text: qsTr("保存密钥")
                        highlighted: true
                        enabled: WeatherMapPlugin.credentialsReady
                            && !WeatherMapPlugin.credentialBusy
                            && apiKeyField.text.trim().length >= 16
                        focusPolicy: Qt.StrongFocus
                        Material.background: Appearance.colors.colPrimary
                        Material.foreground: Appearance.colors.colOnPrimary
                        Material.elevation: 2
                        Accessible.description: qsTr("安全保存并立即应用，无需重启")
                        onClicked: root.applyApiKey()

                        contentItem: Text {
                            text: saveButton.text
                            color: saveButton.enabled
                                ? Appearance.colors.colOnPrimary
                                : Appearance.applyAlpha(
                                    Appearance.colors.colOnSurface,
                                    0.72
                                )
                            font: saveButton.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }

        MapTilerApiSettingsCard {
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: helpContent.implicitHeight + 32
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: helpContent

                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                MaterialSymbol {
                    Layout.alignment: Qt.AlignTop
                    text: "info"
                    iconSize: 21
                    color: Appearance.colors.colPrimary
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("密钥仅保存在系统密钥环中，不会写入项目配置或显示在界面中。")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
