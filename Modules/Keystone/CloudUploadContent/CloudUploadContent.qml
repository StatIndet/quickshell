import "../../../Common/functions/SystemFormat.js" as Format
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool dragActive: false
    property bool showQueue: CloudUploadService.uploadJobs.length > 0
    property int previousJobCount: CloudUploadService.uploadJobs.length
    readonly property bool hasJobs: CloudUploadService.uploadJobs.length > 0
    readonly property bool hasCompletedJobs: CloudUploadService.uploadJobs.some((job) => {
        return job.state === "success";
    })

    function stateIcon(state) {
        switch (state) {
        case "success":
            return "cloud_done";
        case "error":
            return "error";
        case "cancelled":
            return "cancel";
        case "uploading":
            return "cloud_upload";
        case "preparing":
            return "hourglass_top";
        default:
            return "schedule";
        }
    }

    function stateText(job) {
        switch (job.state) {
        case "success":
            return qsTr("上传完成");
        case "error":
            return qsTr("上传失败");
        case "cancelled":
            return qsTr("已取消");
        case "uploading":
            return qsTr("正在上传");
        case "preparing":
            return qsTr("正在准备");
        default:
            return qsTr("等待上传");
        }
    }

    function progressDetail(job) {
        const parts = [];
        if (job.totalBytes > 0)
            parts.push(qsTr("%1 / %2").arg(Format.bytes(job.bytes)).arg(Format.bytes(job.totalBytes)));
        else if (job.bytes > 0)
            parts.push(Format.bytes(job.bytes));
        if (job.speed > 0)
            parts.push(Format.bytesPerSecond(job.speed));

        if (job.eta >= 0 && job.state === "uploading")
            parts.push(qsTr("剩余 %1").arg(Format.duration(job.eta)));

        return parts.join(" · ");
    }

    Connections {
        function onUploadJobsChanged() {
            const count = CloudUploadService.uploadJobs.length;
            if (count > root.previousJobCount)
                root.showQueue = true;

            root.previousJobCount = count;
        }

        target: CloudUploadService
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.showQueue && root.hasJobs ? queueComponent : CloudUploadService.hasWritableRemote ? landingComponent : noRemoteComponent
    }

    Component {
        id: landingComponent

        Item {
            Rectangle {
                id: dropSurface

                anchors.fill: parent
                anchors.margins: Metrics.spacingL
                radius: Appearance.rounding.extraLarge
                color: root.dragActive ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh

                Canvas {
                    id: dashedOutline

                    property color lineColor: root.dragActive ? Appearance.colors.colPrimary : Appearance.colors.colOutline

                    function roundedPath(context, x, y, width, height, radius) {
                        context.beginPath();
                        context.moveTo(x + radius, y);
                        context.lineTo(x + width - radius, y);
                        context.quadraticCurveTo(x + width, y, x + width, y + radius);
                        context.lineTo(x + width, y + height - radius);
                        context.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
                        context.lineTo(x + radius, y + height);
                        context.quadraticCurveTo(x, y + height, x, y + height - radius);
                        context.lineTo(x, y + radius);
                        context.quadraticCurveTo(x, y, x + radius, y);
                        context.closePath();
                    }

                    anchors.fill: parent
                    anchors.margins: Metrics.spacingS
                    onLineColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const context = getContext("2d");
                        context.reset();
                        context.lineWidth = 2;
                        context.strokeStyle = lineColor;
                        if (context.setLineDash)
                            context.setLineDash([10, 8]);

                        roundedPath(context, 1, 1, width - 2, height - 2, Math.max(0, Appearance.rounding.extraLarge - Metrics.spacingS));
                        context.stroke();
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Metrics.spacingXL * 2, 620)
                    spacing: Metrics.spacingM

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.dragActive ? "move_to_inbox" : "cloud_upload"
                        iconSize: 72
                        fill: root.dragActive ? 1 : 0
                        color: root.dragActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary
                        scale: root.dragActive ? 1.12 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveDefaultSpatial.duration
                                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                            }

                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.dragActive ? qsTr("释放以上传") : qsTr("将文件或文件夹拖到这里")
                        color: root.dragActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                        font.family: Typography.headlineMedium.family
                        font.pixelSize: Typography.headlineMedium.pixelSize
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("文件夹会保持原有目录结构，上传到默认云存储的 Clavis Uploads")
                        color: root.dragActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.bodyLarge.family
                        font.pixelSize: Typography.bodyLarge.pixelSize
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: CloudUploadService.lastMessage.length > 0
                        text: CloudUploadService.lastMessage
                        color: CloudUploadService.lastMessageTone === "error" ? Appearance.colors.colError : Appearance.colors.colPrimary
                        font.family: Typography.labelLarge.family
                        font.pixelSize: Typography.labelLarge.pixelSize
                        horizontalAlignment: Text.AlignHCenter
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }

                }

            }

        }

    }

    Component {
        id: noRemoteComponent

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - Metrics.spacingXL * 2, 560)
            spacing: Metrics.spacingM

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "cloud_off"
                iconSize: 64
                color: Appearance.colors.colOnSurfaceVariant
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("没有可用的默认云存储")
                color: Appearance.colors.colOnSurface
                font.family: Typography.headlineSmall.family
                font.pixelSize: Typography.headlineSmall.pixelSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("请先在设置中心选择一个可写入的默认云存储")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.bodyLarge.family
                font.pixelSize: Typography.bodyLarge.pixelSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            ActionButton {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("打开云存储设置")
                iconName: "settings"
                filled: true
                onClicked: ControlCenterService.open("advanced")
            }

        }

    }

    Component {
        id: queueComponent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spacingL
            spacing: Metrics.spacingM

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS

                Text {
                    Layout.fillWidth: true
                    text: qsTr("上传队列")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.headlineSmall.family
                    font.pixelSize: Typography.headlineSmall.pixelSize
                    font.weight: Font.DemiBold
                }

                ActionButton {
                    text: qsTr("清除已完成")
                    iconName: "done_all"
                    enabled: root.hasCompletedJobs
                    onClicked: CloudUploadService.clearCompletedUploads()
                }

                ActionButton {
                    text: qsTr("返回上传")
                    iconName: "add"
                    filled: true
                    onClicked: root.showQueue = false
                }

            }

            ListView {
                id: uploadList

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Metrics.spacingS
                clip: true
                model: CloudUploadService.uploadJobs

                delegate: Rectangle {
                    id: jobRow

                    required property var modelData

                    width: uploadList.width
                    height: Math.max(92, jobContent.implicitHeight + Metrics.spacingM * 2)
                    radius: Appearance.rounding.large
                    color: modelData.state === "error" ? Appearance.colors.colErrorContainer : Appearance.colors.colSurfaceContainerHigh

                    RowLayout {
                        id: jobContent

                        anchors.fill: parent
                        anchors.margins: Metrics.spacingM
                        spacing: Metrics.spacingM

                        MaterialLoadingIndicator {
                            id: jobSpinner

                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            visible: jobRow.modelData.state === "preparing" || (jobRow.modelData.state === "uploading" && jobRow.modelData.progress < 0)
                            running: visible
                            contained: false
                            indicatorColor: Appearance.colors.colPrimary
                            accessibleName: root.stateText(jobRow.modelData)
                        }

                        MaterialSymbol {
                            visible: !jobSpinner.visible
                            text: root.stateIcon(jobRow.modelData.state)
                            iconSize: Metrics.iconL
                            fill: jobRow.modelData.state === "success" ? 1 : 0
                            color: jobRow.modelData.state === "error" ? Appearance.colors.colOnErrorContainer : jobRow.modelData.state === "success" ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Metrics.spacingXS

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Metrics.spacingS

                                Text {
                                    Layout.fillWidth: true
                                    text: jobRow.modelData.displayName
                                    color: jobRow.modelData.state === "error" ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSurface
                                    font.family: Typography.titleMedium.family
                                    font.pixelSize: Typography.titleMedium.pixelSize
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    text: root.stateText(jobRow.modelData)
                                    color: jobRow.modelData.state === "error" ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSurfaceVariant
                                    font.family: Typography.labelLarge.family
                                    font.pixelSize: Typography.labelLarge.pixelSize
                                }

                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                visible: jobRow.modelData.state === "uploading" && jobRow.modelData.progress >= 0
                                radius: height / 2
                                color: Appearance.colors.colSecondaryContainer

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, jobRow.modelData.progress))
                                    height: parent.height
                                    radius: parent.radius
                                    color: Appearance.colors.colPrimary

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Appearance.animation.expressiveEffects.duration
                                            easing.type: Appearance.animation.expressiveEffects.type
                                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                                        }

                                    }

                                }

                            }

                            Text {
                                Layout.fillWidth: true
                                text: jobRow.modelData.state === "error" ? jobRow.modelData.errorMessage : root.progressDetail(jobRow.modelData)
                                visible: text.length > 0
                                color: jobRow.modelData.state === "error" ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSurfaceVariant
                                font.family: Typography.bodySmall.family
                                font.pixelSize: Typography.bodySmall.pixelSize
                                elide: Text.ElideRight
                            }

                        }

                        ActionButton {
                            visible: jobRow.modelData.state === "error"
                            text: qsTr("重试")
                            iconName: "refresh"
                            onClicked: CloudUploadService.retryUpload(jobRow.modelData.id)
                        }

                        IconButton {
                            visible: ["queued", "preparing", "uploading"].indexOf(jobRow.modelData.state) >= 0
                            iconName: "close"
                            accessibleName: qsTr("取消上传")
                            onClicked: CloudUploadService.cancelUpload(jobRow.modelData.id)
                        }

                    }

                }

            }

        }

    }

}
