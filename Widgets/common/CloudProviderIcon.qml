import QtQuick
import qs.Common
import qs.Components

Item {
    id: root

    property string remoteName: ""
    property string remoteType: ""
    property real iconSize: 28
    property color symbolColor: Appearance.colors.colPrimary
    readonly property string normalizedType: remoteType.toLowerCase()
    readonly property string normalizedName: remoteName.toLowerCase()
    readonly property string logoPath: {
        if (normalizedType === "drive")
            return Paths.rcloneIconsDir + "/logos--google-drive.svg";

        if (normalizedType === "onedrive")
            return Paths.rcloneIconsDir + "/logos--microsoft-onedrive.svg";

        if (normalizedType === "s3")
            return normalizedName.indexOf("r2") >= 0 || normalizedName.indexOf("cloudflare") >= 0 ? Paths.rcloneIconsDir + "/logos--cloudflare-icon.svg" : Paths.rcloneIconsDir + "/logos--aws-s3.svg";

        const logos = {
            "azureblob": "logos--microsoft-azure.svg",
            "azurefiles": "logos--microsoft-azure.svg",
            "b2": "simple-icons--backblaze.svg",
            "box": "logos--box.svg",
            "cloudinary": "logos--cloudinary.svg",
            "dropbox": "logos--dropbox.svg",
            "filen": "simple-icons--filen.svg",
            "google cloud storage": "simple-icons--googlecloudstorage.svg",
            "google photos": "logos--google-photos.svg",
            "huaweidrive": "simple-icons--huawei.svg",
            "iclouddrive": "simple-icons--icloud.svg",
            "internetarchive": "simple-icons--internetarchive.svg",
            "jottacloud": "arcticons--jottacloud.svg",
            "koofr": "arcticons--koofr.svg",
            "mailru": "arcticons--mailru.svg",
            "mega": "simple-icons--mega.svg",
            "oracleobjectstorage": "logos--oracle.svg",
            "protondrive": "simple-icons--protondrive.svg",
            "pcloud": "arcticons--pcloud.svg",
            "putio": "thesvg-color--putio.svg",
            "seafile": "simple-icons--seafile.svg",
            "storj": "token-branded--storj.svg",
            "swift": "logos--swift.svg",
            "yandex": "simple-icons--yandexcloud.svg",
            "zoho": "logos--zoho.svg"
        };
        if (logos[normalizedType])
            return Paths.rcloneIconsDir + "/" + logos[normalizedType];

        return "";
    }
    readonly property string symbolName: {
        switch (normalizedType) {
        case "alias":
            return "shortcut";
        case "archive":
            return "archive";
        case "cache":
            return "cached";
        case "chunker":
            return "splitscreen";
        case "combine":
            return "merge";
        case "compress":
            return "folder_zip";
        case "crypt":
            return "encrypted";
        case "hdfs":
            return "dns";
        case "http":
            return "http";
        case "local":
            return "hard_drive";
        case "memory":
            return "memory";
        case "smb":
            return "lan";
        case "ftp":
        case "sftp":
            return "folder_shared";
        case "union":
            return "account_tree";
        case "webdav":
            return "cloud_sync";
        default:
            return "cloud";
        }
    }

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.logoPath !== "" ? Paths.fileUrl(root.logoPath) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: root.logoPath !== ""
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: root.logoPath === ""
        text: root.symbolName
        iconSize: root.iconSize
        fill: 1
        color: root.symbolColor
    }

}
