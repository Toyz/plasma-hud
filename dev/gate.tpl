import QtQuick
import QtQuick.Window
import "file:///home/helba/projects/plasma-hud/packages/org.helba.plasmahud/contents/ui"
import "file:///home/helba/projects/plasma-hud/packages/org.helba.chaosgate/contents/ui"

Window {
    id: w
    width: 1600
    height: 900
    visible: true
    color: "black"
    Image { anchors.fill: parent; source: "file:///home/helba/Pictures/wally/wallhaven-3ldl5v.png"; fillMode: Image.PreserveAspectCrop }
    Hud { id: ctx; cfg: ({ colorMode: __MODE__, palette: 1, serifFont: "Noto Serif", labelFont: "Fira Sans Condensed", monoFont: "Hack" }) }
    AreaNames { id: names }
    GatePanel {
        id: gp
        anchors.fill: parent
        hud: ctx
        areas: [
            { index: 0, id: "a", name: names.name(0, "c391b56d"), glyph: "Δ", current: true, windows: 5 },
            { index: 1, id: "b", name: names.name(1, "0521f73e"), glyph: "Θ", current: false, windows: 2 }
        ]
        windows: [
            { row: 0, title: "plasma-hud — Visual Studio Code", app: "Code", icon: "visual-studio-code", area: "Δ" },
            { row: 1, title: "System Settings", app: "System Settings", icon: "systemsettings", area: "Δ" },
            { row: 2, title: "Borderlands 4", app: "Steam", icon: "steam", area: "Θ" }
        ]
        commands: [
            { key: "launcher", glyph: "∞", name: "Root Town", hint: "the app launcher", words: "apps" },
            { key: "app:x|systemsettings", glyph: "Ψ", name: "System Settings", hint: "brings it forward if already open", words: "settings preferences" },
            { key: "reboot", glyph: "Β", name: "Reboot", hint: "restart the machine", words: "restart", danger: true }
        ]
        Component.onCompleted: { reset(); }
    }
    Timer { interval: 600; running: "__Q__" !== ""; onTriggered: gp.setQuery("__Q__") }
    Timer { interval: 2200; running: true; onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("__OUT__"); Qt.quit(); }) }
}
