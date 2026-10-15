import QtQuick
import QtQuick.Window
import "file:///home/helba/projects/plasma-hud/packages/org.helba.plasmahud/contents/ui"

// The seven HUD Tile cards at their default desktop sizes, over a wallpaper.
// sed __MODE__ / __IMG__ / __OUT__ (see tiles.sh).
Window {
    id: w
    width: 1380
    height: 920
    visible: true
    color: "#0b0d14"

    Image { anchors.fill: parent; source: "__IMG__"; fillMode: Image.PreserveAspectCrop; opacity: 0.8 }

    Hud {
        id: hud
        open: true
        cfg: ({ colorMode: __MODE__, palette: 1, serifFont: "Noto Serif", monoFont: "Hack", labelFont: "Fira Sans Condensed",
                sampleMs: 500, glow: 0.7, checkUpdates: false, gpuDevice: "gpu0", terminalCommand: "konsole", probeCommand: "" })
    }

    GaugesCard { hud: hud; x: 20; y: 20; width: 628; height: 260 }
    CoresCard { hud: hud; x: 20; y: 290; width: 548; height: 70 }
    LoadCard { hud: hud; x: 680; y: 20; width: 388; height: 200 }
    NetCard { hud: hud; x: 680; y: 240; width: 388; height: 138 }
    ProcsCard { hud: hud; x: 20; y: 370; width: 448; height: 238 }
    SystemCard { hud: hud; x: 500; y: 370; width: 328; height: 218 }
    DeckCard { hud: hud; x: 20; y: 640; width: 648; height: 44 }

    Timer {
        interval: 6000; running: true
        onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("__OUT__"); Qt.quit(); })
    }
}
