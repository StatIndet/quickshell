import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Modules.SystemCards

StyledFlickable {
    id: root

    property bool presentationActive: false
    readonly property bool cookieClockActive: UiPreferences.sidebarClockStyle === "cookie"
    readonly property var gpuOptions: buildGpuOptions()
    readonly property var capacityDiskOptions: buildCapacityDiskOptions()

    function gpuPciLabel(gpu) {
        const pciId = String(gpu.pciId || "");
        if (pciId !== "")
            return pciId;

        const id = String(gpu.id || "");
        return id.indexOf("pci:") === 0 ? id.slice(4) : id;
    }

    function buildGpuOptions() {
        const options = [
                  {
                      "value": "auto",
                      "label": qsTr("Auto")
                  }
              ];
        const names = ({});
        for (let index = 0; index < SystemMonitorService.gpus.length; index += 1) {
            const name = String(SystemMonitorService.gpus[index].name || qsTr("Graphics device"));
            names[name] = Number(names[name] || 0) + 1;
        }
        for (let index = 0; index < SystemMonitorService.gpus.length; index += 1) {
            const gpu = SystemMonitorService.gpus[index];
            const id = String(gpu.id || "");
            if (id === "")
                continue;

            const name = String(gpu.name || qsTr("Graphics device"));
            options.push({
                             "value": id,
                             "label": names[name] > 1 ? name + " · " + root.gpuPciLabel(gpu) : name
                         });
        }
        const preferred = UiPreferences.systemMonitorGpuId;
        if (preferred !== "auto") {
            let found = false;
            for (let index = 1; index < options.length; index += 1) {
                if (options[index].value === preferred) {
                    found = true;
                    break;
                }
            }
            if (!found)
                options.push({
                                 "value": preferred,
                                 "label": preferred + " · " + qsTr("Currently unavailable")
                             });
        }
        return options;
    }

    function buildCapacityDiskOptions() {
        const language = I18nService.language;
        const options = [
                  {
                      "value": "follow-io",
                      "label": qsTr("Follow Disk I/O card")
                  }
              ];
        for (let index = 0; index < SystemMonitorService.disks.length; index += 1) {
            const device = String(SystemMonitorService.disks[index].device || "");
            if (device !== "")
                options.push({
                                 "value": device,
                                 "label": device
                             });
        }
        const preferred = UiPreferences.storageCapacityDiskDevice;
        if (preferred !== "follow-io") {
            let found = false;
            for (let index = 1; index < options.length; index += 1) {
                if (options[index].value === preferred) {
                    found = true;
                    break;
                }
            }
            if (!found)
                options.push({
                                 "value": preferred,
                                 "label": preferred + " · " + qsTr("Currently unavailable")
                             });
        }
        return options;
    }

    onPresentationActiveChanged: SystemMonitorService.setConsumerModules("general-sidebar-settings",
                                                                         root.presentationActive ? ["gpu",
                                                                                                    "disk"] : [])
    Component.onCompleted: SystemMonitorService.setConsumerModules("general-sidebar-settings",
                                                                   root.presentationActive ? ["gpu", "disk"] :
                                                                                             [])
    Component.onDestruction: SystemMonitorService.clearConsumer("general-sidebar-settings")
    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("Desktop cards")
            iconName: "dashboard_customize"

            SettingsRow {
                Layout.fillWidth: true
                iconName: "side_navigation"
                title: qsTr("Keep sidebar loaded")
                supportingText: qsTr("Opens faster next time, but uses more memory")

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.keepSidebarsLoaded
                    Accessible.name: qsTr("Keep sidebar loaded")
                    onToggled: PersonalizationConfig.setKeepSidebarsLoaded(checked)
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("Desktop card layout")
            iconName: "dashboard_customize"

            StyledButtonGroup {
                Layout.fillWidth: true
                model: [
                    {
                        "value": "free",
                        "label": qsTr("Free drag")
                    },
                    {
                        "value": "leastBusy",
                        "label": qsTr("Least busy")
                    },
                    {
                        "value": "mostBusy",
                        "label": qsTr("Most busy")
                    }
                ]
                currentValue: SystemCardService.globalDesktopLayoutMode
                onValueSelected: value => {
                    return SystemCardService.setGlobalDesktopLayoutMode(value);
                }
            }

            StyledButtonGroup {
                Layout.fillWidth: true
                model: [
                    {
                        "value": "screenTopLeft",
                        "label": qsTr("Top left")
                    },
                    {
                        "value": "screenTopRight",
                        "label": qsTr("Top right")
                    },
                    {
                        "value": "screenBottomLeft",
                        "label": qsTr("Bottom left")
                    },
                    {
                        "value": "screenBottomRight",
                        "label": qsTr("Bottom right")
                    },
                    {
                        "value": "screenCenter",
                        "label": qsTr("Center")
                    }
                ]
                currentValue: SystemCardService.globalDesktopLayoutMode
                buttonMinWidth: 0
                onValueSelected: value => {
                    return SystemCardService.setGlobalDesktopLayoutMode(value);
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "grid_4x4"
                title: qsTr("Snap desktop cards to grid")

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.desktopCardGridSnapEnabled
                    Accessible.name: qsTr("Snap desktop cards to grid")
                    onToggled: PersonalizationConfig.setDesktopCardGridSnapEnabled(checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "grid_on"
                title: qsTr("Show desktop grid while dragging")

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.desktopCardGridVisibleWhileDragging
                    Accessible.name: qsTr("Show desktop grid while dragging")
                    onToggled: PersonalizationConfig.setDesktopCardGridVisibleWhileDragging(checked)
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("Clock style")
            iconName: "schedule"

            StyledButtonGroup {
                Layout.fillWidth: true
                model: [
                    {
                        "value": "digital",
                        "label": qsTr("Digital"),
                        "icon": "timer_10"
                    },
                    {
                        "value": "cookie",
                        "label": qsTr("Cookie"),
                        "icon": "cookie"
                    }
                ]
                currentValue: UiPreferences.sidebarClockStyle
                buttonMinWidth: 120
                onValueSelected: value => {
                    return UiPreferences.setSidebarClockStyle(value);
                }
            }

            ColumnLayout {
                id: cookieSettings

                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacingM
                spacing: Metrics.spacingS
                enabled: root.cookieClockActive
                opacity: root.cookieClockActive ? 1 : 0.42

                SettingsRow {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    iconName: "add_triangle"
                    title: qsTr("Sides")
                    supportingText: qsTr("0 or 1 produces a circle; up to 40 sides")

                    trailing: MaterialStepper {
                        enabled: root.cookieClockActive
                        value: UiPreferences.sidebarCookieSides
                        from: 0
                        to: 40
                        stepSize: 1
                        onValueModified: value => {
                            return UiPreferences.setSidebarCookieSides(value);
                        }
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    iconName: "autoplay"
                    title: qsTr("Constantly rotate")

                    trailing: StyledSwitch {
                        enabled: root.cookieClockActive
                        checked: UiPreferences.sidebarCookieConstantlyRotate
                        Accessible.name: qsTr("Constantly rotate")
                        onToggled: UiPreferences.setSidebarCookieConstantlyRotate(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive && (UiPreferences.sidebarCookieDialStyle === "dots"
                                                        || UiPreferences.sidebarCookieDialStyle === "full")
                    iconName: "brightness_7"
                    title: qsTr("Hour marks")
                    supportingText: qsTr("Available with Dots or Full dials")

                    trailing: StyledSwitch {
                        checked: UiPreferences.sidebarCookieHourMarks
                        Accessible.name: qsTr("Hour marks")
                        onToggled: UiPreferences.setSidebarCookieHourMarks(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive && UiPreferences.sidebarCookieDialStyle !== "numbers"
                    iconName: "timer_10"
                    title: qsTr("Digits in the middle")
                    supportingText: qsTr("Unavailable with the Numbers dial")

                    trailing: StyledSwitch {
                        checked: UiPreferences.sidebarCookieTimeIndicators
                        Accessible.name: qsTr("Digits in the middle")
                        onToggled: UiPreferences.setSidebarCookieTimeIndicators(checked)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("Dial style")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [
                        {
                            "value": "none",
                            "label": qsTr("None"),
                            "icon": "block"
                        },
                        {
                            "value": "dots",
                            "label": qsTr("Dots"),
                            "icon": "graph_6"
                        },
                        {
                            "value": "full",
                            "label": qsTr("Full"),
                            "icon": "history_toggle_off"
                        },
                        {
                            "value": "numbers",
                            "label": qsTr("Digital"),
                            "icon": "counter_1"
                        }
                    ]
                    currentValue: UiPreferences.sidebarCookieDialStyle
                    horizontalPadding: Metrics.spacingXL
                    onValueSelected: value => {
                        return UiPreferences.setSidebarCookieDialStyle(value);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("Hour hand")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [
                        {
                            "value": "hide",
                            "label": qsTr("None"),
                            "icon": "block"
                        },
                        {
                            "value": "classic",
                            "label": qsTr("Classic"),
                            "icon": "radio"
                        },
                        {
                            "value": "hollow",
                            "label": qsTr("Hollow"),
                            "icon": "circle"
                        },
                        {
                            "value": "fill",
                            "label": qsTr("Fill"),
                            "icon": "eraser_size_5"
                        }
                    ]
                    currentValue: UiPreferences.sidebarCookieHourHandStyle
                    horizontalPadding: Metrics.spacingXL
                    onValueSelected: value => {
                        return UiPreferences.setSidebarCookieHourHandStyle(value);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("Minute hand")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [
                        {
                            "value": "hide",
                            "label": qsTr("None"),
                            "icon": "block"
                        },
                        {
                            "value": "classic",
                            "label": qsTr("Classic"),
                            "icon": "radio"
                        },
                        {
                            "value": "thin",
                            "label": qsTr("Thin"),
                            "icon": "line_end"
                        },
                        {
                            "value": "medium",
                            "label": qsTr("Medium"),
                            "icon": "eraser_size_2"
                        },
                        {
                            "value": "bold",
                            "label": qsTr("Bold"),
                            "icon": "eraser_size_4"
                        }
                    ]
                    currentValue: UiPreferences.sidebarCookieMinuteHandStyle
                    horizontalPadding: Metrics.spacingM * 2
                    contentSpacing: Metrics.spacingXS
                    onValueSelected: value => {
                        return UiPreferences.setSidebarCookieMinuteHandStyle(value);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("Second hand")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [
                        {
                            "value": "hide",
                            "label": qsTr("None"),
                            "icon": "block"
                        },
                        {
                            "value": "classic",
                            "label": qsTr("Classic"),
                            "icon": "radio"
                        },
                        {
                            "value": "line",
                            "label": qsTr("Line"),
                            "icon": "line_end"
                        },
                        {
                            "value": "dot",
                            "label": qsTr("Dots"),
                            "icon": "adjust"
                        }
                    ]
                    currentValue: UiPreferences.sidebarCookieSecondHandStyle
                    horizontalPadding: Metrics.spacingXL
                    onValueSelected: value => {
                        return UiPreferences.setSidebarCookieSecondHandStyle(value);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("Date style")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [
                        {
                            "value": "hide",
                            "label": qsTr("None"),
                            "icon": "block"
                        },
                        {
                            "value": "bubble",
                            "label": qsTr("Bubble"),
                            "icon": "bubble_chart"
                        },
                        {
                            "value": "border",
                            "label": qsTr("Border"),
                            "icon": "rotate_right"
                        },
                        {
                            "value": "rect",
                            "label": qsTr("Rect"),
                            "icon": "rectangle"
                        }
                    ]
                    currentValue: UiPreferences.sidebarCookieDateStyle
                    horizontalPadding: Metrics.spacingXL
                    onValueSelected: value => {
                        return UiPreferences.setSidebarCookieDateStyle(value);
                    }
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("System cards")
            iconName: "widgets"

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Metrics.spacingS
                rowSpacing: Metrics.spacingS

                Repeater {
                    model: SystemCardService.cardIds

                    delegate: SettingsRow {
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        iconName: SystemCardService.cardIcon(modelData)
                        title: SystemCardService.cardName(modelData)
                        supportingText: {
                            const cards = SystemCardService.cards;
                            const state = cards ? cards[modelData] : null;
                            return state && state.container === "desktop" ? qsTr("Desktop") : qsTr("Sidebar");
                        }

                        trailing: StyledSwitch {
                            checked: {
                                const cards = SystemCardService.cards;
                                const state = cards ? cards[modelData] : null;
                                return state ? state.enabled : true;
                            }
                            Accessible.name: SystemCardService.cardName(modelData)
                            onToggled: SystemCardService.setCardEnabled(modelData, checked)
                        }
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "developer_board"
                title: qsTr("GPU")
                supportingText: qsTr("Select the graphics device shown by the GPU card")

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 220
                    options: root.gpuOptions
                    value: UiPreferences.systemMonitorGpuId
                    placeholder: qsTr("Auto")
                    closeOnAccept: true
                    onAccepted: value => {
                        return UiPreferences.setSystemMonitorGpuId(value);
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "speed"
                title: qsTr("System monitor snapshot interval")

                trailing: MaterialFilledTextField {
                    id: intervalField

                    Layout.preferredWidth: 150
                    labelText: qsTr("Interval")
                    text: String(UiPreferences.systemMonitorIntervalMs)
                    error: text.length === 0 || !acceptableInput
                    inputMethodHints: Qt.ImhDigitsOnly
                    trailingContentWidth: 40
                    onEditingFinished: {
                        UiPreferences.setSystemMonitorIntervalMs(text);
                        text = String(UiPreferences.systemMonitorIntervalMs);
                    }

                    validator: IntValidator {
                        bottom: 100
                        top: 60000
                    }

                    trailingContent: Component {
                        Text {
                            anchors.fill: parent
                            text: qsTr("ms")
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Typography.bodyMedium.family
                            font.pixelSize: Typography.bodyMedium.pixelSize
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "data_usage"
                title: qsTr("Disk capacity")
                supportingText: qsTr("Select the physical disk shown by the capacity card")

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 260
                    options: root.capacityDiskOptions
                    value: UiPreferences.storageCapacityDiskDevice
                    placeholder: qsTr("Follow Disk I/O card")
                    closeOnAccept: true
                    onAccepted: value => {
                        return UiPreferences.setStorageCapacityDiskDevice(value);
                    }
                }
            }
        }
    }
}
