import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Clavis.WeatherMap
import qs.Common
import qs.Components
import qs.Widgets.common

Rectangle {
    id: root

    property bool revealApiKey: false
    property string feedbackText: ""
    property bool feedbackError: false
    readonly property bool statusError: WeatherMapPlugin.mapTilerStatus === "keychain_error"

    function applyApiKey() {
        const value = mapTilerApiKeyField.text.trim();
        if (value.length < 16) {
            feedbackError = true;
            feedbackText = qsTr("请输入有效的 MapTiler API key");
            mapTilerApiKeyField.forceActiveFocus();
            return ;
        }
        const result = WeatherMapPlugin.storeMapTilerApiKey(value);
        feedbackError = !result.ok;
        feedbackText = result.message || qsTr("无法更新 MapTiler API key");
    }

    function clearApiKey() {
        const result = WeatherMapPlugin.clearMapTilerApiKey();
        feedbackError = !result.ok;
        feedbackText = result.message || qsTr("无法清除 MapTiler API key");
    }

    implicitHeight: serviceContent.implicitHeight + 48
    radius: Appearance.rounding.large
    color: Appearance.colors.colSurfaceContainer

    Connections {
        function onCredentialOperationFinished(operation, success, message) {
            if (operation !== "maptiler_store" && operation !== "maptiler_clear")
                return ;

            root.feedbackError = !success;
            root.feedbackText = message;
            if (success) {
                mapTilerApiKeyField.clear();
                root.revealApiKey = false;
            }
        }

        target: WeatherMapPlugin
    }

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
                    text: "map"
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
                    text: "MapTiler Dataviz"
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    textFormat: Text.PlainText
                }

            }

            Rectangle {
                implicitWidth: statusContent.implicitWidth + 24
                implicitHeight: 34
                radius: Appearance.rounding.full
                color: root.statusError ? Appearance.colors.colErrorContainer : WeatherMapPlugin.mapTilerConfigured ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest

                RowLayout {
                    id: statusContent

                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: !WeatherMapPlugin.credentialsReady || WeatherMapPlugin.mapTilerStatus === "loading_credentials" || WeatherMapPlugin.credentialBusy ? "sync" : root.statusError ? "error" : WeatherMapPlugin.mapTilerConfigured ? "check_circle" : "key_off"
                        iconSize: 17
                        fill: WeatherMapPlugin.mapTilerConfigured ? 1 : 0
                        color: root.statusError ? Appearance.colors.colOnErrorContainer : WeatherMapPlugin.mapTilerConfigured ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                    }

                    Text {
                        text: !WeatherMapPlugin.credentialsReady || WeatherMapPlugin.mapTilerStatus === "loading_credentials" ? qsTr("正在检查") : WeatherMapPlugin.credentialBusy ? qsTr("处理中") : root.statusError ? qsTr("读取失败") : WeatherMapPlugin.mapTilerConfigured ? qsTr("已配置") : qsTr("未配置")
                        color: root.statusError ? Appearance.colors.colOnErrorContainer : WeatherMapPlugin.mapTilerConfigured ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
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
            text: "MapTiler API key"
            color: Appearance.colors.colOnSurface
            font.family: Fonts.ui
            font.pixelSize: 14
            font.weight: Font.Medium
            textFormat: Text.PlainText
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56

            MaterialTextField {
                id: mapTilerApiKeyField

                anchors.fill: parent
                placeholderText: qsTr("输入 MapTiler API key")
                echoMode: root.revealApiKey ? TextInput.Normal : TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                maximumLength: 128
                enabled: WeatherMapPlugin.credentialsReady && !WeatherMapPlugin.credentialBusy
                Accessible.name: "MapTiler API key"
                Accessible.description: qsTr("安全保存到系统密钥环")
                onTextChanged: {
                    if (root.feedbackError) {
                        root.feedbackError = false;
                        root.feedbackText = "";
                    }
                }
                onAccepted: root.applyApiKey()

                trailingContent: Component {
                    IconButton {
                        anchors.fill: parent
                        iconName: root.revealApiKey ? "visibility_off" : "visibility"
                        iconSize: 20
                        iconColor: Appearance.colors.colOnSurfaceVariant
                        accessibleName: root.revealApiKey ? qsTr("隐藏 API key") : qsTr("显示 API key")
                        hoverStateLayerColor: Appearance.colors.colLayer3Hover
                        pressedStateLayerColor: Appearance.colors.colLayer3Active
                        onClicked: root.revealApiKey = !root.revealApiKey
                    }

                }

            }

        }

        Text {
            Layout.fillWidth: true
            text: qsTr("密钥保存在系统密钥环中，保存后立即生效。")
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Fonts.ui
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
            color: root.feedbackError ? Appearance.colors.colErrorContainer : Appearance.colors.colPrimaryContainer

            RowLayout {
                id: feedbackRow

                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                MaterialSymbol {
                    text: WeatherMapPlugin.credentialBusy ? "sync" : root.feedbackError ? "error" : "check_circle"
                    iconSize: 18
                    fill: WeatherMapPlugin.credentialBusy ? 0 : 1
                    color: root.feedbackError ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                }

                Text {
                    Layout.fillWidth: true
                    text: root.feedbackText
                    color: root.feedbackError ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                    font.family: Fonts.ui
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
                enabled: WeatherMapPlugin.mapTilerConfigured && !WeatherMapPlugin.credentialBusy
                focusPolicy: Qt.StrongFocus
                Material.foreground: Appearance.colors.colOnSurfaceVariant
                Accessible.description: qsTr("从系统密钥环移除 MapTiler API key")
                onClicked: root.clearApiKey()
            }

            Button {
                id: saveButton

                text: qsTr("保存密钥")
                highlighted: true
                enabled: WeatherMapPlugin.credentialsReady && !WeatherMapPlugin.credentialBusy && mapTilerApiKeyField.text.trim().length >= 16
                focusPolicy: Qt.StrongFocus
                Material.background: Appearance.colors.colPrimary
                Material.foreground: Appearance.colors.colOnPrimary
                Material.elevation: 2
                Accessible.description: qsTr("安全保存并立即应用，无需重启")
                onClicked: root.applyApiKey()

                contentItem: Text {
                    text: saveButton.text
                    color: saveButton.enabled ? Appearance.colors.colOnPrimary : Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.72)
                    font: saveButton.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    textFormat: Text.PlainText
                }

            }

        }

    }

}
