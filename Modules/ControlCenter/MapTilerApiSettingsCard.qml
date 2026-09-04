import QtQuick
import Clavis.WeatherMap

WeatherServiceApiKeyCard {
    id: root

    serviceName: "MapTiler Dataviz"
    iconName: "map"
    fieldLabel: "MapTiler API key"
    placeholderText: qsTr("输入 MapTiler API key")
    invalidKeyText: qsTr("请输入有效的 MapTiler API key")
    clearDescription: qsTr("从系统密钥环移除 MapTiler API key")
    configured: WeatherMapPlugin.mapTilerConfigured
    credentialsReady: WeatherMapPlugin.credentialsReady
    busy: WeatherMapPlugin.credentialBusy
    checking: !WeatherMapPlugin.credentialsReady || WeatherMapPlugin.mapTilerStatus === "loading_credentials"
    statusError: WeatherMapPlugin.mapTilerStatus === "keychain_error"
    storeAction: (value) => {
        return WeatherMapPlugin.storeMapTilerApiKey(value);
    }
    clearAction: () => {
        return WeatherMapPlugin.clearMapTilerApiKey();
    }

    Connections {
        function onCredentialOperationFinished(operation, success, message) {
            if (operation === "maptiler_store" || operation === "maptiler_clear")
                root.completeOperation(success, message);

        }

        target: WeatherMapPlugin
    }

}
