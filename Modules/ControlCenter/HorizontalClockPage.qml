import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Components
import qs.Widgets.common

StyledFlickable {
    id: root

    readonly property real pageContentWidth: 600
    property string selectedDigit: "h0"
    property string customColorDraft: ""
    readonly property int currentHourTens: clockPreview.h0
    readonly property int currentHourOnes: clockPreview.h1
    readonly property int currentMinuteTens: clockPreview.m0
    readonly property int currentMinuteOnes: clockPreview.m1
    readonly property string currentPeriodLead: clockPreview.periodLead

    function selectedDigitData() {
        const defaults = PersonalizationConfig.horizontalClockDigitDefaults;
        const configured = PersonalizationConfig.horizontalClockDigits;
        return configured && configured[selectedDigit] ? configured[selectedDigit] : defaults[selectedDigit];
    }

    function selectedDigitCustomColor() {
        const data = root.selectedDigitData();
        return String(data && data.customColor || "");
    }

    function updateCustomColorDraft() {
        root.customColorDraft = root.selectedDigitCustomColor();
        if (customColorField && !customColorField.activeFocus)
            customColorField.text = root.customColorDraft;
    }

    function selectedDigitThemeColor() {
        const data = root.selectedDigitData();
        return data && data.colorRole === "inversePrimary" ? Appearance.colors.colInversePrimary.toString() :
                                                             Appearance.colors.colPrimary.toString();
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 24
    Component.onCompleted: root.updateCustomColorDraft()
    onSelectedDigitChanged: root.updateCustomColorDraft()

    ColumnLayout {
        id: contentColumn

        width: root.pageContentWidth
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: 30

        KeystoneSection {
            title: qsTr("Horizontal clock style")
            iconName: "tune"

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(66, (width - 8) * 42 / 220 + 12)

                HorizontalClockPreview {
                    id: clockPreview

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Hide date")

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.keystoneHideDate
                    Accessible.name: qsTr("Hide date")
                    onToggled: PersonalizationConfig.setKeystoneHideDate(checked)
                }
            }

            ClockSliderSetting {
                title: qsTr("Font size")
                axisTag: "px"
                from: 16
                to: 28
                stepSize: 1
                value: PersonalizationConfig.horizontalClockFontSize
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockFontSize(value, false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockFontSize(value, true);
                }
            }

            ClockSliderSetting {
                title: qsTr("Weight")
                axisTag: "wght"
                from: 1
                to: 1000
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.wght
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("wght", value, false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("wght", value, true);
                }
            }

            ClockSliderSetting {
                title: qsTr("Width")
                axisTag: "wdth"
                from: 25
                to: 151
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.wdth
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("wdth", value, false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("wdth", value, true);
                }
            }

            ClockSliderSetting {
                title: qsTr("Optical size")
                axisTag: "opsz"
                from: 6
                to: 144
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.opsz
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("opsz", value, false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("opsz", value, true);
                }
            }

            ClockSliderSetting {
                title: qsTr("Grade")
                axisTag: "GRAD"
                from: 0
                to: 100
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.GRAD
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("GRAD", value, false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("GRAD", value, true);
                }
            }

            ClockSliderSetting {
                title: qsTr("Roundness")
                axisTag: "ROND"
                from: 0
                to: 100
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.ROND
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("ROND", value, false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("ROND", value, true);
                }
            }

            ClockSliderSetting {
                title: qsTr("Slant")
                axisTag: "slnt"
                from: -10
                to: 0
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.slnt
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("slnt", value, false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockAxis("slnt", value, true);
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Current digit")
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Fonts.ui
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            StyledButtonGroup {
                id: currentDigitGroup

                Layout.fillWidth: true
                model: [({
                             "value": "h0",
                             "label": String(root.currentHourTens)
                         }), ({
                                  "value": "h1",
                                  "label": String(root.currentHourOnes)
                              }), ({
                                       "value": "separator",
                                       "label": ":",
                                       "enabled": false,
                                       "width": 24
                                   }), ({
                                            "value": "m0",
                                            "label": String(root.currentMinuteTens)
                                        }), ({
                                                 "value": "m1",
                                                 "label": String(root.currentMinuteOnes)
                                             }), ({
                                                      "value": "ap",
                                                      "label": root.currentPeriodLead
                                                  }), ({
                                                           "value": "periodM",
                                                           "label": "M"
                                                       })]
                currentValue: root.selectedDigit
                buttonMinWidth: 52
                onValueSelected: value => {
                    root.selectedDigit = String(value);
                    root.updateCustomColorDraft();
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Color")
                supportingText: qsTr("Default theme colors follow the Matugen theme")

                trailing: StyledButtonGroup {
                    model: [({
                                 "value": "primary",
                                 "label": qsTr("Primary")
                             }), ({
                                      "value": "inversePrimary",
                                      "label": qsTr("Inverse")
                                  }), ({
                                           "value": "custom",
                                           "label": qsTr("Custom")
                                       })]
                    currentValue: root.selectedDigitData().colorRole
                    buttonMinWidth: 64
                    onValueSelected: value => {
                        const role = String(value);
                        const color = role === "custom" ? root.selectedDigitCustomColor()
                                                          || root.selectedDigitThemeColor() :
                                                          root.selectedDigitCustomColor();
                        PersonalizationConfig.setHorizontalClockDigitColor(root.selectedDigit, role, color,
                                                                           true);
                    }
                }
            }

            MaterialTextField {
                id: customColorField

                Layout.fillWidth: true
                visible: root.selectedDigitData().colorRole === "custom"
                text: root.customColorDraft
                placeholderText: qsTr("#RRGGBB or #RRGGBBAA")
                Accessible.name: qsTr("Custom color")
                onTextChanged: {
                    if (activeFocus)
                        root.customColorDraft = text;
                }
                onEditingFinished: PersonalizationConfig.setHorizontalClockDigitColor(root.selectedDigit,
                                                                                      "custom", text, true)
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Position: %1").arg(root.selectedDigit.toUpperCase())
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Fonts.ui
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            ClockSliderSetting {
                title: qsTr("X offset")
                axisTag: "x"
                from: -8
                to: 8
                stepSize: 1
                value: root.selectedDigitData().x
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockDigitValue(root.selectedDigit, "x", value,
                                                                              false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockDigitValue(root.selectedDigit, "x", value,
                                                                              true);
                }
            }

            ClockSliderSetting {
                title: qsTr("Y offset")
                axisTag: "y"
                from: -6
                to: 6
                stepSize: 1
                value: root.selectedDigitData().y
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockDigitValue(root.selectedDigit, "y", value,
                                                                              false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockDigitValue(root.selectedDigit, "y", value,
                                                                              true);
                }
            }

            ClockSliderSetting {
                title: qsTr("Rotation")
                axisTag: "°"
                from: -12
                to: 12
                stepSize: 1
                value: root.selectedDigitData().rotation
                suffix: "°"
                onMoved: value => {
                    return PersonalizationConfig.setHorizontalClockDigitValue(root.selectedDigit, "rotation",
                                                                              value, false);
                }
                onCommitted: value => {
                    return PersonalizationConfig.setHorizontalClockDigitValue(root.selectedDigit, "rotation",
                                                                              value, true);
                }
            }

            RippleButton {
                Layout.alignment: Qt.AlignLeft
                Layout.preferredWidth: 116
                Layout.preferredHeight: 40
                buttonRadius: Appearance.rounding.full
                containerColor: Appearance.colors.colSecondaryContainer
                stateLayerColor: Appearance.colors.colSecondaryContainerHover
                pressedStateLayerColor: Appearance.colors.colSecondaryContainerActive
                rippleColor: Appearance.colors.colOnSecondaryContainer
                Accessible.name: qsTr("Reset horizontal clock style")
                releaseAction: () => {
                    return PersonalizationConfig.resetHorizontalClock(true);
                }

                contentItem: RowLayout {
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: "restart_alt"
                        iconSize: 18
                        color: Appearance.colors.colOnSecondaryContainer
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Reset")
                        color: Appearance.colors.colOnSecondaryContainer
                        font.family: Fonts.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }

    Connections {
        function onHorizontalClockDigitsChanged() {
            if (!customColorField.activeFocus)
                root.updateCustomColorDraft();
        }

        target: PersonalizationConfig
    }
}
