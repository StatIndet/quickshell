import "../../../Common/functions/SystemFormat.js" as Format
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Modules.Sidebars.Left.notifications as NotificationComponents
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool dragActive: false
    property bool showQueue: false
    property bool clearingCompletedJobs: false
    readonly property bool hasJobs: CloudUploadService.uploadJobCount > 0
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
        if (CloudUploadService.uploadsPaused && ["queued", "preparing", "uploading"].indexOf(job.state) >= 0)
            return qsTr("已暂停");

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

    function finishDrop(addedCount) {
        if (addedCount > 0)
            showQueue = true;

    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.showQueue && root.hasJobs ? queueComponent : CloudUploadService.hasWritableRemote ? landingComponent : noRemoteComponent
    }

    UploadDropSurface {
        anchors.fill: parent
        anchors.margins: Metrics.spacingL
        z: 10
        dropPrompt: true
        opacity: root.dragActive ? 1 : 0
        visible: root.dragActive || opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }

        }

    }

    Component {
        id: landingComponent

        Item {
            UploadDropSurface {
                anchors.fill: parent
                anchors.margins: Metrics.spacingL
                dropPrompt: false
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
            id: queueLayout

            function clearCompletedWithAnimation() {
                if (!root.hasCompletedJobs || root.clearingCompletedJobs)
                    return ;

                root.clearingCompletedJobs = true;
                for (let index = 0; index < CloudUploadService.uploadJobCount; ++index) {
                    const item = uploadList.itemAtIndex(index);
                    if (item && item.completed)
                        item.dismissWithAnimation(index % 2 === 0 ? 1 : -1, false);

                }
                clearCompletedTimer.restart();
            }

            anchors.fill: parent
            anchors.margins: Metrics.spacingL
            spacing: Metrics.spacingM

            Timer {
                id: clearCompletedTimer

                interval: Appearance.animation.expressiveDefaultSpatial.duration
                repeat: false
                onTriggered: {
                    CloudUploadService.clearCompletedUploads();
                    root.clearingCompletedJobs = false;
                }
            }

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
                    text: CloudUploadService.uploadsPaused ? qsTr("全部继续") : qsTr("全部暂停")
                    iconName: CloudUploadService.uploadsPaused ? "play_arrow" : "pause"
                    enabled: CloudUploadService.hasPendingUploads || CloudUploadService.uploadsPaused
                    onClicked: CloudUploadService.toggleUploadsPaused()
                }

                ActionButton {
                    text: qsTr("清除已完成")
                    iconName: "done_all"
                    enabled: root.hasCompletedJobs && !root.clearingCompletedJobs
                    onClicked: queueLayout.clearCompletedWithAnimation()
                }

                ActionButton {
                    text: qsTr("返回上传")
                    iconName: "add"
                    filled: true
                    enabled: !root.clearingCompletedJobs
                    onClicked: root.showQueue = false
                }

            }

            ListView {
                id: uploadList

                property int dragIndex: -1
                property real dragDistance: 0

                function resetDrag() {
                    dragIndex = -1;
                    dragDistance = 0;
                }

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Metrics.spacingS
                clip: true
                model: CloudUploadService.uploadJobCount

                delegate: Item {
                    id: jobRow

                    required property int index
                    readonly property var job: CloudUploadService.uploadJobs[index] || ({
                    })
                    readonly property bool completed: job.state === "success"
                    readonly property real dragConfirmThreshold: Math.max(128, Math.min(220, width * 0.22))
                    readonly property int dragIndexDiff: Math.abs(uploadList.dragIndex - index)
                    readonly property real xOffset: dragIndexDiff === 0 ? uploadList.dragDistance : Math.abs(uploadList.dragDistance) > dragConfirmThreshold ? 0 : dragIndexDiff === 1 ? uploadList.dragDistance * 0.3 : dragIndexDiff === 2 ? uploadList.dragDistance * 0.1 : 0

                    function dismissWithAnimation(direction, removeAfterAnimation = true) {
                        if (!completed)
                            return ;

                        const currentX = jobSurface.x;
                        uploadList.resetDrag();
                        dragManager.resetDrag();
                        jobSurface.x = currentX;
                        dismissAnimation.direction = direction < 0 ? -1 : 1;
                        dismissAnimation.removeAfterAnimation = removeAfterAnimation;
                        dismissAnimation.jobId = Number(job.id);
                        dismissAnimation.restart();
                    }

                    width: uploadList.width
                    height: Math.max(92, jobContent.implicitHeight + Metrics.spacingM * 2)

                    SequentialAnimation {
                        id: dismissAnimation

                        property int direction: 1
                        property bool removeAfterAnimation: true
                        property int jobId: -1

                        onFinished: {
                            if (removeAfterAnimation)
                                CloudUploadService.removeCompletedUpload(jobId);

                        }

                        NumberAnimation {
                            target: jobSurface
                            property: "x"
                            to: dismissAnimation.direction * (jobRow.width + Metrics.spacingL)
                            duration: Appearance.animation.expressiveDefaultSpatial.duration
                            easing.type: Appearance.animation.expressiveDefaultSpatial.type
                            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                        }

                    }

                    NotificationComponents.DragManager {
                        id: dragManager

                        anchors.fill: parent
                        interactive: !root.clearingCompletedJobs
                        automaticallyReset: false
                        onDraggingChanged: {
                            if (dragging)
                                uploadList.dragIndex = jobRow.index;

                        }
                        onDragDiffXChanged: uploadList.dragDistance = dragDiffX
                        onDragReleased: (diffX) => {
                            if (jobRow.completed && Math.abs(diffX) > jobRow.dragConfirmThreshold) {
                                jobRow.dismissWithAnimation(diffX);
                            } else {
                                dragManager.resetDrag();
                                uploadList.resetDrag();
                            }
                        }
                    }

                    Rectangle {
                        id: jobSurface

                        x: jobRow.xOffset
                        width: parent.width
                        height: parent.height
                        radius: Appearance.rounding.large
                        color: jobRow.job.state === "error" ? Appearance.colors.colErrorContainer : Appearance.colors.colSurfaceContainerHigh

                        RowLayout {
                            id: jobContent

                            anchors.fill: parent
                            anchors.margins: Metrics.spacingM
                            spacing: Metrics.spacingM

                            MaterialLoadingIndicator {
                                id: jobSpinner

                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                visible: !CloudUploadService.uploadsPaused && (jobRow.job.state === "preparing" || (jobRow.job.state === "uploading" && jobRow.job.progress < 0))
                                running: visible
                                contained: false
                                indicatorColor: Appearance.colors.colPrimary
                                accessibleName: root.stateText(jobRow.job)
                            }

                            MaterialSymbol {
                                visible: !jobSpinner.visible
                                text: CloudUploadService.uploadsPaused && ["queued", "preparing", "uploading"].indexOf(jobRow.job.state) >= 0 ? "pause" : root.stateIcon(jobRow.job.state)
                                iconSize: Metrics.iconL
                                fill: jobRow.job.state === "success" ? 1 : 0
                                color: jobRow.job.state === "error" ? Appearance.colors.colOnErrorContainer : jobRow.job.state === "success" ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Metrics.spacingXS

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Metrics.spacingS

                                    Text {
                                        Layout.fillWidth: true
                                        text: jobRow.job.displayName
                                        color: jobRow.job.state === "error" ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSurface
                                        font.family: Typography.titleMedium.family
                                        font.pixelSize: Typography.titleMedium.pixelSize
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        text: root.stateText(jobRow.job)
                                        color: jobRow.job.state === "error" ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSurfaceVariant
                                        font.family: Typography.labelLarge.family
                                        font.pixelSize: Typography.labelLarge.pixelSize
                                    }

                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 6
                                    visible: jobRow.job.state === "uploading" && jobRow.job.progress >= 0
                                    radius: height / 2
                                    color: Appearance.colors.colSecondaryContainer

                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, jobRow.job.progress))
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
                                    text: jobRow.job.state === "error" ? jobRow.job.errorMessage : root.progressDetail(jobRow.job)
                                    visible: text.length > 0
                                    color: jobRow.job.state === "error" ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSurfaceVariant
                                    font.family: Typography.bodySmall.family
                                    font.pixelSize: Typography.bodySmall.pixelSize
                                    elide: Text.ElideRight
                                }

                            }

                            ActionButton {
                                visible: jobRow.job.state === "error"
                                text: qsTr("重试")
                                iconName: "refresh"
                                onClicked: CloudUploadService.retryUpload(jobRow.job.id)
                            }

                            IconButton {
                                visible: ["queued", "preparing", "uploading"].indexOf(jobRow.job.state) >= 0
                                iconName: "close"
                                accessibleName: qsTr("取消上传")
                                onClicked: CloudUploadService.cancelUpload(jobRow.job.id)
                            }

                        }

                        Behavior on x {
                            enabled: !dragManager.dragging && !dismissAnimation.running

                            NumberAnimation {
                                duration: Appearance.animation.expressiveDefaultSpatial.duration
                                easing.type: Appearance.animation.expressiveFastSpatial.type
                                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                            }

                        }

                    }

                }

            }

        }

    }

    component UploadDropSurface: Rectangle {
        id: dropSurface

        required property bool dropPrompt

        radius: Appearance.rounding.extraLarge
        color: dropPrompt ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh

        Canvas {
            id: dashedOutline

            property color lineColor: dropSurface.dropPrompt ? Appearance.colors.colPrimary : Appearance.colors.colOutline

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
                text: dropSurface.dropPrompt ? "move_to_inbox" : "cloud_upload"
                iconSize: 72
                fill: dropSurface.dropPrompt ? 1 : 0
                color: dropSurface.dropPrompt ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary
                scale: dropSurface.dropPrompt ? 1.12 : 1
            }

            Text {
                Layout.fillWidth: true
                text: dropSurface.dropPrompt ? qsTr("释放以上传") : qsTr("将文件或文件夹拖到这里")
                color: dropSurface.dropPrompt ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                font.family: Typography.headlineMedium.family
                font.pixelSize: Typography.headlineMedium.pixelSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            ActionButton {
                Layout.alignment: Qt.AlignHCenter
                visible: !dropSurface.dropPrompt && root.hasJobs
                text: qsTr("已加入 %1 个上传任务").arg(CloudUploadService.uploadJobCount)
                iconName: "format_list_bulleted"
                onClicked: root.showQueue = true
            }

            Text {
                Layout.fillWidth: true
                visible: !dropSurface.dropPrompt && CloudUploadService.lastMessage.length > 0
                text: CloudUploadService.lastMessage
                color: CloudUploadService.lastMessageTone === "error" ? Appearance.colors.colError : Appearance.colors.colPrimary
                font.family: Typography.labelLarge.family
                font.pixelSize: Typography.labelLarge.pixelSize
                horizontalAlignment: Text.AlignHCenter
            }

        }

    }

}
