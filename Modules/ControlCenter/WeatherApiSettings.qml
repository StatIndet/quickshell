import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Clavis.WeatherMap 1.0
import qs.Common
import qs.Components
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

    function applyApiKey() {
        const value = apiKeyField.text.trim()
        if (value.length < 16) {
            feedbackError = true
            feedbackText = "请输入有效的 OpenWeather API key"
            apiKeyField.forceActiveFocus()
            return
        }

        const result = WeatherMapPlugin.setSessionApiKey(value)
        feedbackError = !result.ok
        feedbackText = result.message || "无法更新 API key"
        if (result.ok) {
            apiKeyField.clear()
            revealApiKey = false
        }
    }

    function clearApiKey() {
        const result = WeatherMapPlugin.clearSessionApiKey()
        feedbackError = !result.ok
        feedbackText = result.message || "无法清除 API key"
        if (result.ok) {
            apiKeyField.clear()
            revealApiKey = false
        }
    }

    ColumnLayout {
        id: contentColumn

        width: root.pageContentWidth
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: 24

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
                    text: "天气"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    text: "配置 Keystone 天气地图服务"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    textFormat: Text.PlainText
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: serviceContent.implicitHeight + 48
            radius: Appearance.rounding.large
            color: Appearance.m3colors.m3surfaceContainer
            border.width: 1
            border.color: Appearance.applyAlpha(
                Appearance.colors.colOutlineVariant,
                0.72
            )

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
                            text: "用于 Temperature 与 Rain 地图覆盖层"
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
                                text: WeatherMapPlugin.apiConfigured
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

                                text: WeatherMapPlugin.apiConfigured
                                    ? "已配置"
                                    : "未配置"
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
                        placeholderText: "输入 OPENWEATHER_API_KEY"
                        echoMode: root.revealApiKey
                            ? TextInput.Normal
                            : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                            | Qt.ImhNoPredictiveText
                            | Qt.ImhNoAutoUppercase
                        maximumLength: 128
                        rightPadding: 52
                        Accessible.name: "OpenWeather API key"
                        Accessible.description: "会话级密钥，不写入磁盘"
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
                            ? "隐藏 API key"
                            : "显示 API key"
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
                                ? "隐藏 API key"
                                : "显示 API key"
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "密钥只导入当前 systemd 用户会话环境，不写入项目或普通配置文件。保存或清除后需重启 Quickshell；注销后需要重新设置。"
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
                            text: root.feedbackError
                                ? "error"
                                : "check_circle"
                            iconSize: 18
                            fill: 1
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
                        text: "清除会话密钥"
                        flat: true
                        enabled: WeatherMapPlugin.apiConfigured
                        focusPolicy: Qt.StrongFocus
                        Material.foreground: Appearance.colors.colOnSurfaceVariant
                        Accessible.description: "从当前 systemd 用户会话移除环境变量"
                        onClicked: root.clearApiKey()
                    }

                    Button {
                        text: "保存到本次会话"
                        highlighted: true
                        enabled: apiKeyField.text.trim().length >= 16
                        focusPolicy: Qt.StrongFocus
                        Material.background: Appearance.colors.colPrimary
                        Material.foreground: Appearance.colors.colOnPrimary
                        Accessible.description: "保存后重启 Quickshell 生效"
                        onClicked: root.applyApiKey()
                    }
                }
            }
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
                    text: "AQI 数据仍由 Open-Meteo 提供，不需要此密钥。环境变量名称固定为 OPENWEATHER_API_KEY；界面不会读取或回显已经保存的明文。"
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
