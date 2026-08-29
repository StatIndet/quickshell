pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common

ColumnLayout {
    id: root

    property alias text: field.text
    property alias labelText: field.labelText
    property alias placeholderText: field.placeholderText
    property alias echoMode: field.echoMode
    property alias validator: field.validator
    property alias inputMethodHints: field.inputMethodHints
    property alias readOnly: field.readOnly
    property string supportingText: ""
    property string errorText: ""
    property bool error: errorText.length > 0
    property bool passwordToggle: false
    property bool passwordVisible: false
    readonly property alias fieldItem: field

    signal accepted()
    signal editingFinished()

    spacing: Metrics.spacingXXS

    MaterialTextField {
        id: field

        Layout.fillWidth: true
        error: root.error
        echoMode: root.passwordToggle && !root.passwordVisible
            ? TextInput.Password : TextInput.Normal
        trailingContent: root.passwordToggle ? passwordButtonComponent : null
        onAccepted: root.accepted()
        onEditingFinished: root.editingFinished()
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: Metrics.spacingL
        Layout.rightMargin: Metrics.spacingL
        visible: root.error || root.supportingText.length > 0
        text: root.error ? root.errorText : root.supportingText
        color: root.error
            ? Appearance.colors.colError
            : Appearance.colors.colOnSurfaceVariant
        font.family: Typography.bodySmall.family
        font.pixelSize: Typography.bodySmall.pixelSize
        font.weight: Typography.bodySmall.weight
        wrapMode: Text.Wrap
    }

    Component {
        id: passwordButtonComponent

        IconButton {
            controlSize: Metrics.touchTarget
            iconName: root.passwordVisible ? "visibility_off" : "visibility"
            iconSize: Metrics.iconM
            accessibleName: root.passwordVisible
                ? qsTr("隐藏密码") : qsTr("显示密码")
            onClicked: root.passwordVisible = !root.passwordVisible
        }
    }
}
