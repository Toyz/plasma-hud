import QtQuick
import QtQuick.Window
import org.kde.plasma.private.kicker as Kicker
import "file:///home/helba/projects/plasma-hud/packages/org.helba.plasmahud/contents/ui"

Window {
    id: w
    width: 600
    height: 760
    visible: true
    color: "#111318"

    Hud {
        id: ctx
        open: true
        cfg: ({ colorMode: __MODE__, palette: 1, serifFont: "Noto Serif", monoFont: "Hack", labelFont: "Fira Sans Condensed", mode: 3,
                badgeCpu: true, badgeGpu: true, badgeMem: true, badgeTemp: false, badgeNet: false, badgeUptime: false,
                sampleMs: 1000, glow: 0.7, scanlines: true, glitch: false, checkUpdates: false,
                favoritesMigrated: true, gpuDevice: "gpu0", terminalCommand: "konsole", probeCommand: "" })
    }
    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        flat: true; sorted: true; showSeparators: false
        showAllApps: true; showAllAppsCategorized: false; showTopLevelItems: false
        showRecentApps: false; showRecentDocs: false; showPowerSession: false
        Component.onCompleted: { favoritesModel.initForClient("org.kde.plasma.kickoff.favorites.instance-48"); refresh(); }
    }
    Kicker.RunnerModel { id: runnerModel; favoritesModel: rootModel.favoritesModel; mergeResults: true }

    LauncherPanel {
        id: panel
        x: 20; y: 20
        hud: ctx
        rootModel: rootModel
        runnerModel: runnerModel
        favorites: rootModel.favoritesModel
        Component.onCompleted: { focusSearch(); tab = __CAT__; }
    }
    Timer { interval: 900; running: "__QUERY__" !== ""; onTriggered: panel.setQuery("__QUERY__") }
    Timer {
        interval: 4000; running: true
        onTriggered: {
            console.warn("rows", rootModel.count, "first", rootModel.data(rootModel.index(0, 0), Qt.DisplayRole),
                         "favs", rootModel.favoritesModel.count, "runner", runnerModel.count);
            w.contentItem.grabToImage(r => { r.saveToFile("__OUT__"); Qt.quit(); });
        }
    }
}
