#!/bin/sh
# Render the Helba World lock screen with a mock greeter: ./lock.sh [0|1 = idle|plate] [0|1|2 = system|light|dark] [out.png]
cd "$(dirname "$0")"
state=${1:-1}; mode=${2:-2}; out=${3:-$PWD/lock-$state-$mode.png}
src=../packages/lockshell/contents/lockscreen
tmp=$(mktemp -d)
cp "$src"/*.qml "$src"/qmldir "$tmp"/
case $mode in
    1) sed -i 's/readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5/readonly property bool light: true/' "$tmp/LockScreen.qml" ;;
    2) sed -i 's/readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5/readonly property bool light: false/' "$tmp/LockScreen.qml" ;;
esac
cat > "$tmp/run.qml" <<QML
import QtQuick
import QtQuick.Window
Window {
    id: w
    width: 1600; height: 900; visible: true
    // What kscreenlocker_greet provides as context properties.
    property string kscreenlocker_userName: "helba"
    property string kscreenlocker_userImage: ""
    property QtObject authenticator: QtObject {
        property string prompt: ""
        property string infoMessage: ""
        property string errorMessage: ""
        property bool hadPrompt: true
        signal failed(int kind)
        signal succeeded()
        signal promptForSecretChanged()
        function startAuthenticating() {}
        function respond(p) {}
    }
    Image { anchors.fill: parent; source: "file:///home/helba/Pictures/wally/wallhaven-w5dod6.png"; fillMode: Image.PreserveAspectCrop }
    Loader { id: lock; anchors.fill: parent; source: "LockScreen.qml" }
    Timer { interval: 300; running: true; onTriggered: if ($state) { lock.item.active = true; lock.item.notification = "Caps would show here"; } }
    Timer { interval: 1600; running: true; onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("$out"); Qt.quit(); }) }
}
QML
QT_FORCE_STDERR_LOGGING=1 timeout 30 qml6 "$tmp/run.qml" 2>&1 | grep -v -e "different thread"
rm -rf "$tmp"
