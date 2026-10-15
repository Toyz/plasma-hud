#!/bin/sh
# Render the Helba World SDDM theme with a mock greeter:
#   ./sddm.sh [1|0 = primary|side screen] [0|1 = dark|light] [out.png]
cd "$(dirname "$0")"
primary=${1:-1}; light=${2:-0}; out=${3:-$PWD/sddm-$primary-$light.png}
tmp=$(mktemp -d)
cp ../packages/sddm/helba-world/Main.qml "$tmp/"
img=$(ls /home/helba/Pictures/wally/*.png 2>/dev/null | head -1)
[ -n "$img" ] && cp "$img" "$tmp/background.jpg"
cat > "$tmp/run.qml" <<QML
import QtQuick
import QtQuick.Window
Window {
    id: w
    width: 1600; height: 900; visible: true
    // What sddm-greeter provides as context properties.
    property bool primaryScreen: $( [ "$primary" = 1 ] && echo true || echo false )
    property QtObject config: QtObject { property string background: "background.jpg"; property string light: "$light" }
    property QtObject keyboard: QtObject { property bool capsLock: false }
    property QtObject sddm: QtObject {
        property string hostName: "seshat"
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        signal loginFailed()
        signal loginSucceeded()
        function login(u, p, s) { loginFailed(); }
        function suspend() {}
        function reboot() {}
        function powerOff() {}
    }
    property ListModel userModel: ListModel {
        property int lastIndex: 0
        property string lastUser: "helba"
        ListElement { name: "helba"; realName: "helba"; icon: "" }
        ListElement { name: "guest"; realName: "Guest"; icon: "" }
    }
    property ListModel sessionModel: ListModel {
        property int lastIndex: 0
        ListElement { name: "Plasma (Wayland)" }
        ListElement { name: "Plasma (X11)" }
    }
    Loader { anchors.fill: parent; source: "Main.qml" }
    Timer { interval: 1500; running: true; onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("$out"); Qt.quit(); }) }
}
QML
QT_FORCE_STDERR_LOGGING=1 timeout 30 qml6 "$tmp/run.qml" 2>&1 | grep -v -e "different thread"
rm -rf "$tmp"
