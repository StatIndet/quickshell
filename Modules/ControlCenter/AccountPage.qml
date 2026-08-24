pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import qs.Common
import qs.Components
import qs.Modules.FilePicker
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property var parentModal: null
    property bool presentationActive: false
    signal navigateRequested(string pageId)

    onPresentationActiveChanged: SystemIdentityService.setUptimeConsumer("account-page", root.presentationActive)
    Component.onCompleted: SystemIdentityService.setUptimeConsumer("account-page", root.presentationActive)
    Component.onDestruction: SystemIdentityService.setUptimeConsumer("account-page", false)

    function closeChildWindows() {
        avatarPicker.dismiss();
        backupPicker.dismiss();
    }

    readonly property bool wideLayout: width >= 880
    readonly property real cardGap: Appearance.spacing.medium
    readonly property real columnWidth: wideLayout
        ? (cardLayout.width - cardGap) / 2 : cardLayout.width
    readonly property real wallpaperPreviewMaximumWidth: 152
    readonly property real wallpaperPreviewWidth: Math.min(
        wallpaperPreviewMaximumWidth,
        Math.floor((personalizationCard.width
            - Appearance.spacing.large * 2
            - Appearance.spacing.medium * 2
            - Appearance.spacing.small * 2) / 3))
    readonly property real wallpaperPreviewHeight:
        Math.round(wallpaperPreviewWidth / 1.25)
    readonly property var pairedBluetoothDevices: {
        const result = [];
        const seen = {};
        const groups = [
            BluetoothService.connectedDevices.filter(device =>
                device.paired || device.bonded || device.trusted),
            BluetoothService.pairedDevices
        ];
        for (const group of groups) {
            for (const device of group) {
                const key = String(device.address || device.id || device.name || "");
                if (seen[key])
                    continue;
                seen[key] = true;
                result.push(device);
            }
        }
        return result;
    }
    readonly property var wallpaperChoices: {
        const values = [];
        const current = WallpaperService.currentWallpaper;
        if (current)
            values.push(current);
        for (const path of WallpaperService.wallpapers) {
            if (values.indexOf(path) < 0)
                values.push(path);
            if (values.length >= 6)
                break;
        }
        return values;
    }

    function formatBytes(value) {
        const bytes = Number(value);
        if (!isFinite(bytes) || bytes < 0)
            return qsTr("未知");
        const units = [qsTr("B"), qsTr("KB"), qsTr("MB"), qsTr("GB"), qsTr("TB"), qsTr("PB")];
        let amount = bytes;
        let unit = 0;
        while (amount >= 1024 && unit < units.length - 1) {
            amount /= 1024;
            unit += 1;
        }
        const digits = unit === 0 || amount >= 100 ? 0 : amount >= 10 ? 1 : 2;
        return amount.toFixed(digits) + " " + units[unit];
    }

    function providerName(remote) {
        if (!remote)
            return qsTr("未连接云存储");
        const type = String(remote.type || "").toLowerCase();
        const name = String(remote.name || "").toLowerCase();
        switch (type) {
        case "drive": return "Google Drive";
        case "onedrive": return "Microsoft OneDrive";
        case "dropbox": return "Dropbox";
        case "s3":
            return name.indexOf("r2") >= 0 || name.indexOf("cloudflare") >= 0
                ? "Cloudflare R2" : "Amazon S3";
        case "http": return "HTTP";
        case "smb": return "SMB";
        case "ftp": return "FTP";
        case "sftp": return "SFTP";
        case "webdav": return "WebDAV";
        default:
            return remote.type || qsTr("其他云存储");
        }
    }

    function bluetoothIcon(device) {
        const icon = String(device && device.icon || "").toLowerCase();
        if (icon.indexOf("head") >= 0 || icon.indexOf("audio") >= 0)
            return "headphones";
        if (icon.indexOf("keyboard") >= 0)
            return "keyboard";
        if (icon.indexOf("mouse") >= 0)
            return "mouse";
        if (icon.indexOf("phone") >= 0)
            return "smartphone";
        return "bluetooth";
    }

    function bluetoothState(device) {
        if (device.connected)
            return qsTr("已连接");
        return qsTr("已配对");
    }

    function bluetoothAction(device) {
        if (device.connected)
            BluetoothService.disconnectDevice(device);
        else
            BluetoothService.connectDevice(device);
    }

    function bluetoothActionText(device) {
        if (device.connected)
            return qsTr("断开");
        return qsTr("连接");
    }

    Component.onCompleted: {
        if (WallpaperService.wallpapers.length === 0 && !WallpaperService.scanning)
            WallpaperService.scan();
    }

    StyledFlickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + Appearance.spacing.large * 2

        Column {
            id: pageColumn

            x: Appearance.spacing.large
            y: Appearance.spacing.large
            width: parent.width - Appearance.spacing.large * 2
            spacing: Appearance.spacing.large

            AccountProfileHeader {
                width: parent.width
                wallpaperPath: WallpaperService.currentWallpaper
                colorWallpaper: WallpaperService.isColorSource(wallpaperPath)
                avatarUrl: AvatarService.avatarUrl
                fallbackAvatarUrl: Paths.fileUrl(Paths.defaultAvatar)
                accountIdentity: SystemIdentityService.accountIdentity
                distroId: SystemIdentityService.distroId
                distroName: SystemIdentityService.distroName
                uptimeText: SystemIdentityService.uptimeText
                totalPackageCount: PackageService.totalPackages
                pendingUpdateCount: PackageService.pendingUpdates
                onAvatarActivated: avatarPicker.openAt(avatarPicker.picturesDir)
            }

            Item {
                id: cardLayout

                width: parent.width
                height: root.wideLayout
                    ? Math.max(bluetoothCard.y + bluetoothCard.height,
                               personalizationCard.y + personalizationCard.height)
                    : personalizationCard.y + personalizationCard.height

                MaterialCard {
                    id: languageCard

                    width: root.columnWidth
                    title: qsTr("语言")
                    iconName: "translate"
                    containerColor:
                        Appearance.m3colors.m3surfaceContainerHigh

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.medium

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("显示语言")
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodyMedium.pixelSize
                            font.weight: Font.Medium
                        }

                        SearchSelectMenuField {
                            Layout.preferredWidth: 190
                            options: I18nService.supportedLanguages
                            value: UiPreferences.language
                            placeholder: qsTr("选择语言")
                            textRole: "label"
                            valueRole: "code"
                            closeOnAccept: true
                            onAccepted: value => UiPreferences.setLanguage(value)
                        }
                    }
                }

                MaterialCard {
                    id: bluetoothCard

                    x: 0
                    y: languageCard.y + languageCard.height + root.cardGap
                    width: root.columnWidth
                    title: qsTr("蓝牙设备")
                    iconName: BluetoothService.enabled ? "bluetooth" : "bluetooth_disabled"
                    containerColor:
                        Appearance.m3colors.m3surfaceContainerHigh

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: BluetoothService.enabled ? qsTr("蓝牙") : qsTr("开启蓝牙以连接设备")
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodyMedium.pixelSize
                        }

                        StyledSwitch {
                            checked: BluetoothService.enabled
                            enabled: BluetoothService.available && !BluetoothService.busy
                            Accessible.name: qsTr("蓝牙开关")
                            onToggled: BluetoothService.setBluetoothEnabled(checked)
                        }
                    }

                    Flickable {
                        id: pairedDeviceList

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(
                            pairedDeviceColumn.implicitHeight,
                            56 * 3 + Appearance.spacing.small * 2)
                        Layout.maximumHeight: 56 * 3
                            + Appearance.spacing.small * 2
                        contentWidth: width
                        contentHeight: pairedDeviceColumn.implicitHeight
                        clip: true
                        interactive: contentHeight > height

                        Column {
                            id: pairedDeviceColumn

                            width: pairedDeviceList.width
                            spacing: Appearance.spacing.small

                            Repeater {
                                model: root.pairedBluetoothDevices

                                delegate: Rectangle {
                                    id: deviceRow

                                    required property var modelData

                                    width: pairedDeviceColumn.width
                                    height: 56
                                    radius: Appearance.rounding.normal
                                    color: Appearance.colors.colSurfaceContainer

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Appearance.spacing.medium
                                        anchors.rightMargin: Appearance.spacing.small
                                        spacing: Appearance.spacing.small

                                        MaterialSymbol {
                                            text: root.bluetoothIcon(deviceRow.modelData)
                                            iconSize: 22
                                            color: Appearance.colors.colPrimary
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            Text {
                                                Layout.fillWidth: true
                                                text: deviceRow.modelData.name
                                                    || qsTr("未命名设备")
                                                color: Appearance.colors.colOnSurface
                                                font.family: Fonts.ui
                                                font.pixelSize: Typography.bodyMedium.pixelSize
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.bluetoothState(
                                                    deviceRow.modelData)
                                                color: Appearance.colors.colOnSurfaceVariant
                                                font.family: Fonts.ui
                                                font.pixelSize: Typography.bodySmall.pixelSize
                                            }
                                        }

                                        ActionButton {
                                            text: root.bluetoothActionText(
                                                deviceRow.modelData)
                                            enabled: BluetoothService.enabled
                                                && !BluetoothService.busy
                                            onClicked: root.bluetoothAction(
                                                deviceRow.modelData)
                                        }

                                        Item {
                                            Layout.preferredWidth:
                                                Metrics.controlHeightM
                                            Layout.preferredHeight:
                                                Metrics.controlHeightM

                                            IconButton {
                                                id: moreButton

                                                anchors.fill: parent
                                                enabled: !BluetoothService.busy
                                                iconName: "more_horiz"
                                                iconSize: 22
                                                iconColor:
                                                    Appearance.colors.colOnSurfaceVariant
                                                accessibleName:
                                                    qsTr("%1 的更多选项").arg(
                                                        deviceRow.modelData.name
                                                            || qsTr("未命名设备"))
                                                onClicked: forgetMenu.open()
                                            }

                                            Menu {
                                                id: forgetMenu

                                                y: moreButton.height

                                                MenuItem {
                                                    text: qsTr("遗忘设备")
                                                    onTriggered:
                                                        BluetoothService.forgetDevice(
                                                            deviceRow.modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: BluetoothService.enabled
                            && root.pairedBluetoothDevices.length === 0
                        text: qsTr("暂无已配对设备")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: Typography.bodyMedium.pixelSize
                        horizontalAlignment: Text.AlignHCenter
                    }

                    SettingsActionRow {
                        Layout.fillWidth: true
                        text: qsTr("更多蓝牙设置")
                        trailingIconName: "chevron_right"
                        onClicked: console.warn("[Account] detailed Bluetooth settings are unavailable")
                    }
                }

                MaterialCard {
                    id: cloudCard

                    x: root.wideLayout ? root.columnWidth + root.cardGap : 0
                    y: root.wideLayout ? 0 : bluetoothCard.y + bluetoothCard.height + root.cardGap
                    width: root.columnWidth
                    title: qsTr("云存储")
                    iconName: "cloud"
                    containerColor:
                        Appearance.m3colors.m3surfaceContainerHigh

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        CloudProviderIcon {
                            remoteName: RcloneService.selectedRemote
                                ? RcloneService.selectedRemote.name : ""
                            remoteType: RcloneService.selectedRemote
                                ? RcloneService.selectedRemote.type : ""
                            iconSize: 34
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.providerName(RcloneService.selectedRemote)
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodyLarge.pixelSize
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        IconButton {
                            controlSize: Metrics.controlHeightL
                            iconName: "refresh"
                            iconSize: 22
                            iconColor: Appearance.colors.colOnSurfaceVariant
                            accessibleName: qsTr("刷新云存储信息")
                            enabled: RcloneService.selectedRemote !== null
                                && RcloneService.quotaState !== "loading"
                            onClicked: RcloneService.refreshCard()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.xSmall

                        Text {
                            Layout.fillWidth: true
                            text: RcloneService.quotaAvailable
                                ? qsTr("容量：已使用 %1，共 %2（%3%）")
                                    .arg(root.formatBytes(RcloneService.usedBytes))
                                    .arg(root.formatBytes(RcloneService.totalBytes))
                                    .arg(Math.round(RcloneService.usageRatio * 100))
                                : RcloneService.quotaState === "loading"
                                  ? qsTr("正在读取容量…")
                                  : RcloneService.quotaMessage
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodyMedium.pixelSize
                            elide: Text.ElideRight
                        }

                        ThinReadOnlySlider {
                            Layout.fillWidth: true
                            value: RcloneService.usageRatio
                            Accessible.name: qsTr("云存储已使用容量")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: RcloneService.backupState !== "idle"
                        spacing: Appearance.spacing.xSmall

                        Text {
                            Layout.fillWidth: true
                            text: RcloneService.backupMessage
                            color: RcloneService.backupState === "error"
                                ? Appearance.colors.colError
                                : Appearance.colors.colOnSurfaceVariant
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodySmall.pixelSize
                            wrapMode: Text.Wrap
                        }

                        ProgressBar {
                            Layout.fillWidth: true
                            visible: RcloneService.backupState === "running"
                            from: 0
                            to: 1
                            value: Math.max(0, RcloneService.backupProgress)
                            indeterminate: RcloneService.backupProgress < 0
                            Material.accent: Appearance.colors.colPrimary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        SettingsActionRow {
                            Layout.fillWidth: true
                            text: qsTr("电脑备份")
                            iconName: "backup"
                            enabled: RcloneService.selectedRemote !== null
                                && !RcloneService.isReadOnly(RcloneService.selectedRemote)
                                && RcloneService.backupState !== "running"
                            onClicked: backupPicker.openAt(backupPicker.homeDir)
                        }

                        SettingsActionRow {
                            Layout.fillWidth: true
                            text: qsTr("管理云存储")
                            iconName: "settings"
                            trailingIconName: "chevron_right"
                            onClicked: console.warn("[Account] cloud storage management is unavailable")
                        }
                    }
                }

                MaterialCard {
                    id: personalizationCard

                    x: cloudCard.x
                    y: cloudCard.y + cloudCard.height + root.cardGap
                    width: root.columnWidth
                    title: qsTr("个性化")
                    iconName: "palette"
                    containerColor:
                        Appearance.m3colors.m3surfaceContainerHigh

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.leftMargin: Appearance.spacing.medium
                        Layout.rightMargin: Appearance.spacing.medium
                        columns: 3
                        columnSpacing: Appearance.spacing.small
                        rowSpacing: Appearance.spacing.small

                        Repeater {
                            model: root.wallpaperChoices

                            delegate: RippleButton {
                                id: wallpaperChoice

                                required property string modelData

                                Layout.preferredWidth: root.wallpaperPreviewWidth
                                Layout.preferredHeight: root.wallpaperPreviewHeight
                                padding: 0
                                buttonRadius: Appearance.rounding.small
                                containerColor: Appearance.colors.colSurfaceContainer
                                hoverStateLayerOpacity: 0
                                pressedStateLayerOpacity:
                                    Appearance.interaction.pressedStateLayerOpacity
                                rippleColor: Appearance.colors.colOnSurface
                                Accessible.name: qsTr("使用壁纸 %1").arg(
                                    WallpaperService.basename(modelData))
                                onClicked: WallpaperService.setWallpaper(modelData)

                                backgroundContent: Rectangle {
                                    anchors.fill: parent
                                    radius: Appearance.rounding.small
                                    color: WallpaperService.isColorSource(wallpaperChoice.modelData)
                                        ? wallpaperChoice.modelData
                                        : Appearance.colors.colSurfaceContainer

                                    Image {
                                        id: wallpaperImage

                                        anchors.fill: parent
                                        source: WallpaperService.isColorSource(wallpaperChoice.modelData)
                                            ? "" : Paths.fileUrl(wallpaperChoice.modelData)
                                        sourceSize: Qt.size(
                                            Math.max(1, Math.ceil(
                                                width * Screen.devicePixelRatio * 2)),
                                            Math.max(1, Math.ceil(
                                                height * Screen.devicePixelRatio * 2)))
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: false
                                        mipmap: false
                                        visible: source !== ""
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: wallpaperMask
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1
                                        }
                                    }

                                    Rectangle {
                                        id: wallpaperMask

                                        anchors.fill: parent
                                        radius: Appearance.rounding.small
                                        color: Appearance.m3colors.m3scrim
                                        visible: false
                                        layer.enabled: true
                                    }

                                }

                                contentItem: Item {}
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: root.wallpaperPreviewWidth
                            Layout.preferredHeight: root.wallpaperPreviewHeight
                            visible: root.wallpaperChoices.length === 0
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colSurfaceContainer

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: WallpaperService.scanning ? "progress_activity" : "wallpaper"
                                iconSize: 28
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.medium

                        MaterialSymbol {
                            text: "palette"
                            iconSize: 22
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("色彩模式")
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodyMedium.pixelSize
                            font.weight: Font.Medium
                        }

                        SearchSelectMenuField {
                            Layout.preferredWidth: 142
                            options: [
                                ({ "label": qsTr("浅色"), "value": "light" }),
                                ({ "label": qsTr("深色"), "value": "dark" })
                            ]
                            value: PersonalizationConfig.themeMode
                            placeholder: qsTr("选择色彩模式")
                            closeOnAccept: true
                            onAccepted: value => ThemeService.setThemeMode(value)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        SettingsActionRow {
                            Layout.fillWidth: true
                            text: qsTr("壁纸")
                            iconName: "wallpaper"
                            trailingIconName: "chevron_right"
                            onClicked: root.navigateRequested("wallpaper")
                        }

                        SettingsActionRow {
                            Layout.fillWidth: true
                            text: qsTr("主题")
                            iconName: "palette"
                            trailingIconName: "chevron_right"
                            onClicked: root.navigateRequested("theme")
                        }
                    }
                }
            }
        }
    }

    FilePickerWindow {
        id: avatarPicker

        parentModal: root.parentModal
        requiresParentWindow: true
        dialogTitle: qsTr("选择头像")
        onAccepted: (path, isDirectory) => {
            if (!isDirectory)
                AvatarService.setAvatar(path);
        }
    }

    FilePickerWindow {
        id: backupPicker

        parentModal: root.parentModal
        requiresParentWindow: true
        selectionMode: FilePickerWindow.FilesAndFolders
        dialogTitle: qsTr("选择要备份的文件或文件夹")
        description: qsTr("备份到所选云存储的 Clavis Backups 文件夹")
        startPath: homeDir
        nameFilters: []
        windowIconName: "cloud_upload"
        emptyStateText: qsTr("当前文件夹为空")
        selectionPrompt: qsTr("选择文件或文件夹")
        acceptLabel: qsTr("开始备份")
        formatSummary: qsTr("支持文件与文件夹")
        onAccepted: (path, isDirectory) => RcloneService.backup(path, isDirectory)
    }
}
