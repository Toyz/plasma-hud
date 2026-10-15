#!/bin/sh
# Render the Helba World splash at a stage: ./splash.sh [stage 0-5] [0|1 = dark|light] [out.png]
cd "$(dirname "$0")"
stage=${1:-3}; light=${2:-0}; out=${3:-$PWD/splash-$stage-$light.png}
tmp=$(mktemp -d)
cp ../packages/lookandfeel/contents/splash/Splash.qml "$tmp/"
[ "$light" = 1 ] && sed -i 's/readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5/readonly property bool light: true/' "$tmp/Splash.qml"
[ "$light" = 0 ] && sed -i 's/readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5/readonly property bool light: false/' "$tmp/Splash.qml"
cat > "$tmp/run.qml" <<QML
import QtQuick
import QtQuick.Window
Window {
    id: w
    width: 1600; height: 900; visible: true
    Loader { id: s; anchors.fill: parent; source: "Splash.qml"; onLoaded: item.stage = $stage }
    Timer { interval: 2600; running: true; onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("$out"); Qt.quit(); }) }
}
QML
QT_FORCE_STDERR_LOGGING=1 timeout 20 qml6 "$tmp/run.qml" 2>&1 | grep -iE "error|TypeError|Cannot" | head -5
rm -rf "$tmp"
