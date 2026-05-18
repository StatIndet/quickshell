import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Widgets.common
import qs.Common
import qs.Widgets.audio
import qs.Services
import QtQuick.Controls

WidgetPanel {
    id: root
    title: "混音器"
    icon: "tune"
    closeAction: () => WidgetState.qsOpen = false
    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "audio"

    headerTools: Text {
        text: "\uf013"
        font.family: "Font Awesome 6 Free Solid"; font.pixelSize: 20
        color: Appearance.colors.colOnLayer1
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Volume.openMixer() }
    }

    property var defaultSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [ root.defaultSink ] }
    PwNodeLinkTracker { id: appTracker; node: root.defaultSink }
    
    function isHeadphone(node) {
        if (!node) return false;
        const icon = node.properties["device.icon-name"] || ""; 
        const desc = node.description || "";
        return icon.includes("headphone") || desc.toLowerCase().includes("headphone") || desc.toLowerCase().includes("耳机");
    }

    Rectangle {
        Layout.fillWidth: true
        height: 104 
        color: Appearance.colors.colLayer1; radius: Appearance.rounding.large

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text { 
                    text: isHeadphone(root.defaultSink) ? "\uf025" : "\uf028"
                    font.family: "Font Awesome 6 Free Solid"; font.pixelSize: 20; color: Appearance.colors.colPrimary 
                }
                Text { 
                    text: root.defaultSink ? (root.defaultSink.description || root.defaultSink.name) : "未找到设备"
                    font.bold: true; font.pixelSize: 15; color: Appearance.colors.colOnLayer2; elide: Text.ElideRight; Layout.fillWidth: true 
                }
                Text { 
                    text: root.defaultSink ? Math.round(root.defaultSink.audio.volume * 100) + "%" : "0%"
                    font.bold: true; font.pixelSize: 15; color: Appearance.colors.colPrimary 
                }
            }

            VolumeSlider { node: root.defaultSink; isHeadphone: root.isHeadphone(root.defaultSink) }
        }
    }

    Text { text: "应用程序"; font.pixelSize: 14; color: Appearance.colors.colOnLayer1; font.bold: true; Layout.topMargin: 12 }

    StyledListView {
        id: appList
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; spacing: 12;
        model: appTracker.linkGroups
        animateAppearance: false
        animateMovement: false
        interactive: false 

        delegate: Rectangle {
            required property PwLinkGroup modelData
            property var appNode: modelData.source

            width: ListView.view.width; height: 68
            radius: 12; color: "transparent"
            border.width: 1; border.color: "transparent" 
            PwObjectTracker { objects: [ appNode ] }

            RowLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 14

                Image {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    visible: source != ""
                    source: {
                        const iconProperty = (appNode.properties["application.icon-name"] || "").toLowerCase();
                        const binaryName = (appNode.properties["application.process.binary"] || "").toLowerCase();

                        const iconMap = {
                            "zen": "zen-browser",
                            "zen-bin": "zen-browser",
                            "zen-alpha": "zen-browser",
                            "splayer": "file:///usr/share/icons/hicolor/512x512/apps/SPlayer.png"
                        };

                        let finalIcon = iconMap[binaryName] || iconMap[iconProperty] || iconProperty || binaryName || "audio-card";
                        
                        if (finalIcon.startsWith("file://") || finalIcon.startsWith("/")) {
                            return finalIcon.startsWith("/") ? "file://" + finalIcon : finalIcon;
                        }
                        
                        return `image://icon/${finalIcon}`;
                    }
                    onStatusChanged: { if (status === Image.Error) source = "image://icon/audio-card"; }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: appNode.properties["application.name"] || appNode.name; font.bold: true; font.pixelSize: 14; color: Appearance.colors.colOnLayer2; elide: Text.ElideRight; Layout.fillWidth: true }
                    }

                    Item {
                        Layout.fillWidth: true; height: 16
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 6; radius: 3
                            color: Qt.rgba(Appearance.colors.colOnLayer2.r, Appearance.colors.colOnLayer2.g, Appearance.colors.colOnLayer2.b, 0.1)
                            Rectangle { height: parent.height; width: parent.width * appNode.audio.volume; radius: 3; color: Appearance.colors.colPrimary }
                        }

                        Rectangle {
                            width: 6; height: 16; radius: 3; color: Appearance.colors.colOnLayer2 
                            x: Math.max(0, Math.min(parent.width * appNode.audio.volume - width / 2, parent.width - width))
                            anchors.verticalCenter: parent.verticalCenter

                            Item {
                                width: 32; height: 32
                                anchors.bottom: parent.top; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter
                                visible: sliderMouseArea.containsMouse || sliderMouseArea.pressed
                                
                                Rectangle {
                                    anchors.fill: parent; radius: 16; color: Appearance.colors.colPrimary; rotation: 45 
                                    Rectangle { width: 16; height: 16; x: 16; y: 16; color: parent.color }
                                }
                                Text { anchors.centerIn: parent; text: Math.round(appNode.audio.volume * 100); color: Appearance.colors.colLayer1; font.pixelSize: 11; font.bold: true }
                            }
                        }

                        MouseArea {
                            id: sliderMouseArea; anchors.fill: parent;
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            
                            // 【代码精简】：这里不再需要 preventStealing: true 了，因为外层的列表已经彻底失去了抢夺焦点的能力！
                            
                            function updateVolume(mouse) { 
                                let v = mouse.x / width;
                                if (v < 0) v = 0; if (v > 1) v = 1;
                                appNode.audio.volume = v 
                            }
                            onPressed: (mouse) => updateVolume(mouse)
                            onPositionChanged: (mouse) => { if (pressed) updateVolume(mouse) }
                        }
                    }
                }
            }
        }
    }
}
