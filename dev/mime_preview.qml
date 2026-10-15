import QtQuick
import QtQuick.Window

// HelbaWorld file-type icons at 16 / 32 / 64 px: qml6 dev/mime_preview.qml
Window {
    id: w
    width: 1200
    height: 520
    visible: true
    color: "#0b1126"
    readonly property string dir: Qt.resolvedUrl("../packages/icons/HelbaWorld/")
    readonly property var names: ["text-x-python", "text-rust", "application-javascript", "text-x-csrc", "application-json",
        "text-x-generic", "text-markdown", "application-pdf", "application-epub+zip", "x-office-spreadsheet",
        "x-office-presentation", "image-png", "image-jpeg", "image-svg+xml", "audio-mpeg", "audio-flac", "video-mp4",
        "video-x-matroska", "application-zip", "application-x-compressed-tar", "application-x-7z-compressed",
        "application-x-deb", "application-x-cd-image", "application-x-executable", "font-x-generic", "text-html",
        "application-pgp-keys", "application-vnd.nintendo.snes.rom", "application-x-blender", "application-octet-stream",
        "inode-directory", "unknown"]
    Flow {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        Repeater {
            model: w.names
            Column {
                required property string modelData
                width: 136
                spacing: 2
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    Image { anchors.bottom: parent.bottom; width: 16; height: 16; sourceSize: Qt.size(16, 16); source: w.dir + "16x16/mimetypes/" + modelData + ".svg" }
                    Image { anchors.bottom: parent.bottom; width: 32; height: 32; sourceSize: Qt.size(32, 32); source: w.dir + "scalable/mimetypes/" + modelData + ".svg" }
                    Image { width: 64; height: 64; sourceSize: Qt.size(64, 64); source: w.dir + "scalable/mimetypes/" + modelData + ".svg" }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData; color: "#8d98b6"; font.pixelSize: 8; width: 136; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }
    Timer { interval: 2500; running: true; onTriggered: w.contentItem.grabToImage(r => { console.warn("saved", r.saveToFile("/home/helba/projects/plasma-hud/dev/mime-preview.png")); Qt.quit(); }) }
}
