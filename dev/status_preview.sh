#!/bin/sh
# Render HelbaWorld tray icons at 22 px and 44 px on dark and light: ./status_preview.sh [out.png]
cd "$(dirname "$0")"
out=${1:-$PWD/status-preview.png}
tmp=$(mktemp -d)
mkdir -p "$tmp/dark" "$tmp/light"
cp ../packages/icons/HelbaWorld/scalable/status/*.svg "$tmp/dark/"
cp ../packages/icons/HelbaWorld/scalable/status/*.svg "$tmp/light/"
# What Plasma's recoloring does under Helba World Light.
sed -i 's/#eaf0fb/#1a2033/; s/#8fe3ff/#14708a/; s/#f5c85a/#a07308/; s/#ff6074/#c81e45/' "$tmp"/light/*.svg
cat > "$tmp/run.qml" <<QML
import QtQuick
import QtQuick.Window
Window {
    id: w
    width: 1100; height: 330; visible: true
    readonly property var names: ["network-wireless-signal-none", "network-wireless-signal-weak", "network-wireless-signal-ok",
        "network-wireless-signal-excellent", "network-wireless-secure-signal-good", "network-wireless-80-limited",
        "network-wireless-acquiring", "network-wireless-disconnected", "network-wired-activated", "network-wired-disconnected",
        "network-vpn", "audio-volume-high", "audio-volume-medium", "audio-volume-low", "audio-volume-muted",
        "microphone-sensitivity-medium", "microphone-sensitivity-muted", "battery-100", "battery-060", "battery-020",
        "battery-010", "battery-040-charging", "battery-full-charged", "battery-missing", "bluetooth-active",
        "bluetooth-paired", "bluetooth-disabled", "airplane-mode"]
    Column {
        Repeater {
            model: [["dark", "#0b1126"], ["light", "#f3eee1"]]
            Rectangle {
                required property var modelData
                width: w.width; height: w.height / 2
                color: modelData[1]
                Flow {
                    anchors.fill: parent; anchors.margins: 12; spacing: 12
                    Repeater {
                        model: w.names
                        Row {
                            required property string modelData
                            spacing: 4
                            Image { anchors.bottom: parent.bottom; width: 22; height: 22; sourceSize: Qt.size(22, 22); source: "$tmp/" + parent.parent.parent.modelData[0] + "/" + modelData + ".svg" }
                            Image { width: 44; height: 44; sourceSize: Qt.size(44, 44); source: "$tmp/" + parent.parent.parent.modelData[0] + "/" + modelData + ".svg" }
                        }
                    }
                }
            }
        }
    }
    Timer { interval: 1000; running: true; onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("$out"); Qt.quit(); }) }
}
QML
QT_FORCE_STDERR_LOGGING=1 timeout 20 qml6 "$tmp/run.qml" 2>&1 | grep -iE "error|cannot" | head -5
rm -rf "$tmp"
