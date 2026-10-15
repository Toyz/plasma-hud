#!/bin/sh
# Render a window switcher offscreen: ./switcher.sh helba-roster [0|1|2 = system|light|dark] [out.png]
cd "$(dirname "$0")"
pkg=${1:-helba-roster}; mode=${2:-2}; out=${3:-$PWD/switch-$pkg-$mode.png}
python3 switcher_mock.py ../packages/$pkg/contents/ui/main.qml .switcher.qml "$mode"
cat > .switcher-run.qml <<QML
import QtQuick
import QtQuick.Window
Window {
    id: w
    width: 1600; height: 900; visible: true
    Image { anchors.fill: parent; source: "file:///home/helba/Pictures/wally/wallhaven-w5dod6.png"; fillMode: Image.PreserveAspectCrop }
    Loader { anchors.fill: parent; source: "file://$PWD/.switcher.qml" }
    Timer { interval: 1500; running: true; onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("$out"); Qt.quit(); }) }
}
QML
QT_FORCE_STDERR_LOGGING=1 timeout 30 qml6 ./.switcher-run.qml 2>&1 | grep -v -e QProcess -e "different thread"
rm -f .switcher.qml .switcher-run.qml
