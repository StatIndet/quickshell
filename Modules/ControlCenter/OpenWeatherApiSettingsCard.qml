import QtQuick
import Clavis.WeatherMap

WeatherServiceApiKeyCard {
    id: root

    serviceName: "OpenWeather Weather Maps"
    iconName: "rainy"
    fieldLabel: "OpenWeather API key"
    placeholderText: qsTr("输入 OpenWeather API key")
    invalidKeyText: qsTr("请输入有效的 OpenWeather API key")
    clearDescription: qsTr("从系统密钥环移除 OpenWeather API key")
    configured: WeatherMapPlugin.apiConfigured
    credentialsReady: WeatherMapPlugin.credentialsReady
    busy: WeatherMapPlugin.credentialBusy
    checking: !WeatherMapPlugin.credentialsReady || WeatherMapPlugin.status === "loading_credentials"
    statusError: WeatherMapPlugin.status === "keychain_error"
    storeAction: (value) => {
        return WeatherMapPlugin.storeApiKey(value);
    }
    clearAction: () => {
        return WeatherMapPlugin.clearApiKey();
    }

    Connections {
        function onCredentialOperationFinished(operation, success, message) {
            if (operation === "openweather_store" || operation === "openweather_clear")
                root.completeOperation(success, message);

        }

        target: WeatherMapPlugin
    }

}
