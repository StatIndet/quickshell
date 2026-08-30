import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property bool submitting: false
    property string errorMessage: ""
    readonly property bool secure: securitySelect.value === "personal"
    readonly property int ssidBytes: utf8Length(ssidField.text)
    readonly property bool validPassword: !secure || (passwordField.text.length >= 8 && passwordField.text.length <= 63) || /^[0-9A-Fa-f]{64}$/.test(passwordField.text)
    readonly property bool valid: ssidBytes > 0 && ssidBytes <= 32 && validPassword

    signal completed()

    function utf8Length(value) {
        try {
            return encodeURIComponent(String(value || "")).replace(/%[0-9A-Fa-f]{2}|./g, "x").length;
        } catch (error) {
            return 33;
        }
    }

    function clearSensitiveData() {
        passwordField.text = "";
    }

    function resetForm() {
        root.submitting = false;
        root.errorMessage = "";
        ssidField.text = "";
        hiddenSwitch.checked = false;
        securitySelect.value = "personal";
        root.clearSensitiveData();
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2
    Component.onDestruction: root.clearSensitiveData()

    Connections {
        function onAddWifiFinished(success, result, errorMessage) {
            if (!root.submitting)
                return ;

            root.submitting = false;
            if (success) {
                root.resetForm();
                root.completed();
            } else {
                root.errorMessage = errorMessage;
            }
        }

        target: NetworkService
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("网络信息")
            iconName: "add_link"
            contentSpacing: Metrics.spacingL

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingXS

                OutlinedTextField {
                    id: ssidField

                    Layout.fillWidth: true
                    labelText: qsTr("SSID")
                    errorText: root.ssidBytes > 32 ? qsTr("SSID 最多 32 个 UTF-8 字节") : ""
                }

            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("隐藏网络")
                supportingText: qsTr("即使扫描列表中没有该 SSID 也尝试连接")

                trailing: StyledSwitch {
                    id: hiddenSwitch
                }

            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("安全类型")

                trailing: SearchSelectMenuField {
                    id: securitySelect

                    Layout.preferredWidth: 240
                    value: "personal"
                    closeOnAccept: true
                    options: [{
                        "value": "personal",
                        "label": qsTr("WPA/WPA2 Personal")
                    }, {
                        "value": "open",
                        "label": qsTr("无 / 开放")
                    }]
                    onAccepted: (value) => {
                        return securitySelect.value = value;
                    }
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.secure
                spacing: Metrics.spacingXS

                OutlinedTextField {
                    id: passwordField

                    Layout.fillWidth: true
                    labelText: qsTr("密码")
                    passwordToggle: true
                    supportingText: qsTr("仅用于本次连接，不会保存到 Clavis 配置")
                    errorText: text.length > 0 && !root.validPassword ? qsTr("密码需为 8–63 个字符，或 64 位十六进制 PSK") : ""
                }

            }

        }

        InlineStatusBanner {
            Layout.fillWidth: true
            radius: Metrics.cornerM
            visible: root.errorMessage.length > 0
            tone: "error"
            message: root.errorMessage
        }

        RowLayout {
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }

            MaterialLoadingIndicator {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                contained: false
                visible: root.submitting
            }

            ActionButton {
                text: qsTr("连接并添加")
                iconName: "add_link"
                filled: true
                enabled: root.valid && !root.submitting
                onClicked: {
                    root.errorMessage = "";
                    root.submitting = true;
                    NetworkService.addWifiNetwork(ssidField.text, hiddenSwitch.checked, root.secure, passwordField.text);
                }
            }

        }

    }

}
