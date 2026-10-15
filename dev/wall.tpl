import QtQuick
import QtQuick.Window
import "file:///home/helba/projects/plasma-hud/packages/org.helba.hudwall/contents/ui"

Window {
    id: w
    width: 1280
    height: 720
    visible: true
    Wall {
        anchors.fill: parent
        cfg: ({ Image: "__IMG__", FillMode: 2, Effect: __FX__, Intensity: 0.7, ColorDrift: 0.35, Speed: 1.0, Palette: 1,
                Fps: 60, PauseWhenCovered: false, Span: false, Seed: 0.37, PublishAccent: false })
    }
    Timer {
        interval: __MS__; running: true
        onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("__OUT__"); Qt.quit(); })
    }
}
