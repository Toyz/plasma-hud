import QtQuick
import QtQuick.Window
import "file:///home/helba/projects/plasma-hud/packages/org.helba.plasmahud/contents/ui"
Window {
    id: w
    width: 1600; height: 900; visible: true; color: "black"
    Image { anchors.fill: parent; source: "file:///home/helba/Pictures/wally/wallhaven-3ldl5v.png"; fillMode: Image.PreserveAspectCrop }
    Hud { id: ctx; cfg: ({ colorMode: __MODE__, palette: 1, serifFont: "Noto Serif", labelFont: "Fira Sans Condensed", monoFont: "Hack" }) }
    WarpScene { id: sc; anchors.fill: parent; hud: ctx; glyph: "Θ"; title: "Whispering Iron Shrine" }
    SequentialAnimation {
        running: true
        NumberAnimation { target: sc; property: "t"; from: 0; to: 1; duration: 1400; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 250 }
        NumberAnimation { target: sc; property: "t"; from: 1; to: 2; duration: 1900; easing.type: Easing.Linear }
    }
    Timer { interval: __MS__; running: true; onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("__OUT__"); Qt.quit(); }) }
}
