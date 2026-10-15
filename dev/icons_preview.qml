import QtQuick
import QtQuick.Window

// HelbaWorld icons at 16 / 32 / 64 / 128 px on dark and light: qml6 dev/icons_preview.qml
Window {
    id: w
    width: 1180
    height: 760
    visible: true
    readonly property string dir: Qt.resolvedUrl("../packages/icons/HelbaWorld/")
    readonly property var names: ["folder", "folder-open", "folder-documents", "folder-download", "folder-pictures",
        "folder-music", "folder-videos", "user-home", "user-desktop", "folder-templates", "folder-publicshare",
        "folder-remote", "folder-code", "folder-projects", "folder-games", "folder-root", "user-trash", "user-trash-full", "start-here"]
    Column {
        Repeater {
            model: [["#0b1126", "#eaf0fb"], ["#f3eee1", "#1a2033"]]
            Rectangle {
                required property var modelData
                width: w.width
                height: w.height / 2
                color: modelData[0]
                Flow {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10
                    Repeater {
                        model: w.names
                        Column {
                            required property string modelData
                            spacing: 2
                            width: 112
                            Row {
                                spacing: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                Image {
                                    anchors.bottom: parent.bottom
                                    width: 16; height: 16
                                    source: w.dir + (modelData.startsWith("folder") || modelData.startsWith("user-home") || modelData.startsWith("user-desktop")
                                        ? "16x16/places/" : "scalable/places/") + modelData + ".svg"
                                    sourceSize: Qt.size(16, 16)
                                }
                                Image { anchors.bottom: parent.bottom; width: 32; height: 32; source: w.dir + "scalable/places/" + modelData + ".svg"; sourceSize: Qt.size(32, 32) }
                                Image { width: 56; height: 56; source: w.dir + "scalable/places/" + modelData + ".svg"; sourceSize: Qt.size(56, 56) }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData
                                color: "#8d98b6"
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
    }
    Timer { interval: 1200; running: true; onTriggered: w.contentItem.grabToImage(r => { r.saveToFile(Qt.resolvedUrl("icons-preview.png").toString().replace("file://", "")); Qt.quit(); }) }
}
