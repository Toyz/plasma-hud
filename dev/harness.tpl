import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "file:///home/helba/projects/plasma-hud/packages/org.helba.plasmahud/contents/ui"

Window {
    id: w
    width: 960
    height: 1040
    visible: true
    color: "#14161d"

    Hud {
        id: hud
        open: true
        cfg: ({ colorMode: __MODE__, serifFont: "Noto Serif", palette: __PAL__, monoFont: "Hack", labelFont: "Fira Sans Condensed",
                badgeCpu: true, badgeGpu: true, badgeMem: true, badgeTemp: true, badgeNet: true, badgeUptime: true,
                sampleMs: 500, mode: 0, taskAlign: 0, showActiveTitle: true, groupTasks: true,
                currentDesktopOnly: false, currentScreenOnly: false, livePreviews: false, ghostPanel: false,
                launchers: ["applications:systemsettings.desktop", "preferred://filemanager", "applications:org.kde.konsole.desktop", "applications:firefox.desktop"], glow: 0.7, scanlines: true, glitch: false, checkUpdates: false,
                gpuDevice: "gpu0", terminalCommand: "konsole", probeCommand: "" })
    }
    Rectangle { width: w.width; height: 96; color: "#0b0d12" }
    RowLayout { x: 20; y: 4; height: 44; width: 800; Bar { hud: hud; Layout.fillHeight: true; Layout.fillWidth: true } }
    RowLayout { x: 20; y: 58; height: 30; Badge { hud: hud; Layout.fillHeight: true } }

    HudPanel { id: panel; x: 20; y: 110; hud: hud; Component.onCompleted: play() }

    Timer {
        interval: 7000; running: true
        onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("__OUT__"); Qt.quit(); })
    }
}
