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

    function applyApiKey() {
        const value = apiKeyField.text.trim();
        if (value.length < 16) {
            root.feedbackError = true;
            root.feedbackText = qsTr("请输入有效的 OpenWeather API key");
            apiKeyField.fieldItem.forceActiveFocus();
            return ;
        }
        const result = WeatherMapPlugin.storeApiKey(value);
        root.feedbackError = !result.ok;
        root.feedbackText = result.message || qsTr("无法更新 API key");
    }

    function clearApiKey() {
        const result = WeatherMapPlugin.clearApiKey();
        root.feedbackError = !result.ok;
        root.feedbackText = result.message || qsTr("无法清除 API key");
    }

    implicitHeight: content.implicitHeight + Metrics.spacingL * 2
    radius: Appearance.rounding.large
    color: Appearance.colors.colSurfaceContainer

    Connections {
        function onCredentialOperationFinished(operation, success, message) {
            if (operation !== "openweather_store" && operation !== "openweather_clear")
                return ;

            root.feedbackError = !success;
            root.feedbackText = message;
            if (success) {
                apiKeyField.text = "";
                root.revealApiKey = false;
            }
        }

        target: WeatherMapPlugin
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Metrics.spacingL
        spacing: Metrics.spacingM

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingM

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Appearance.rounding.full
                color: Appearance.colors.colPrimaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "rainy"
                    iconSize: 22
                    fill: 1
                    color: Appearance.colors.colOnPrimaryContainer
                }

            }

            Text {
                Layout.fillWidth: true
                text: "OpenWeather Weather Maps"
                color: Appearance.colors.colOnSurface
                font.family: Typography.titleMedium.family
                font.pixelSize: Typography.titleMedium.pixelSize
                font.weight: Typography.titleMedium.weight
            }

            Text {
                text: !WeatherMapPlugin.credentialsReady || WeatherMapPlugin.credentialBusy ? qsTr("正在检查") : WeatherMapPlugin.apiConfigured ? qsTr("已配置") : qsTr("未配置")
                color: WeatherMapPlugin.apiConfigured ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                font.family: Typography.labelMedium.family
                font.pixelSize: Typography.labelMedium.pixelSize
                font.weight: Font.DemiBold
            }

        }

        OutlinedTextField {
            id: apiKeyField

            Layout.fillWidth: true
            labelText: "OpenWeather API key"
            placeholderText: qsTr("输入 OpenWeather API key")
            echoMode: root.revealApiKey ? TextInput.Normal : TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            enabled: WeatherMapPlugin.credentialsReady && !WeatherMapPlugin.credentialBusy
            supportingText: qsTr("安全保存到系统密钥环")
            onAccepted: root.applyApiKey()
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                visible: root.feedbackText.length > 0
                text: root.feedbackText
                color: root.feedbackError ? Appearance.colors.colError : Appearance.colors.colPrimary
                font.family: Typography.bodySmall.family
                font.pixelSize: Typography.bodySmall.pixelSize
                wrapMode: Text.WordWrap
            }

            Button {
                text: root.revealApiKey ? qsTr("隐藏") : qsTr("显示")
                flat: true
                onClicked: root.revealApiKey = !root.revealApiKey
            }

            Button {
                text: qsTr("清除密钥")
                flat: true
                enabled: WeatherMapPlugin.apiConfigured && !WeatherMapPlugin.credentialBusy
                onClicked: root.clearApiKey()
            }

            Button {
                text: qsTr("保存密钥")
                highlighted: true
                enabled: WeatherMapPlugin.credentialsReady && !WeatherMapPlugin.credentialBusy && apiKeyField.text.trim().length >= 16
                Material.background: Appearance.colors.colPrimary
                Material.foreground: Appearance.colors.colOnPrimary
                onClicked: root.applyApiKey()
            }

        }

    }

}
