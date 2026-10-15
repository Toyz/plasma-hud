import QtQuick

// Stand-in for KWin's window switcher model in offscreen renders.
ListModel {
    function activate(i) {}
    function rowCount() { return count; }
    ListElement { caption: "konsole: ~/projects/plasma-hud"; icon: "utilities-terminal"; minimized: false; desktopName: "Θ Whispering Iron Shrine"; windowId: "a" }
    ListElement { caption: "Downloads — Dolphin"; icon: "system-file-manager"; minimized: false; desktopName: "Θ Whispering Iron Shrine"; windowId: "b" }
    ListElement { caption: "Jodiac Candy - YouTube - Microsoft Edge"; icon: "microsoft-edge"; minimized: false; desktopName: "Δ Endless Iron Observatory"; windowId: "c" }
    ListElement { caption: "#questions | Discord"; icon: "discord"; minimized: true; desktopName: "Δ Endless Iron Observatory"; windowId: "d" }
    ListElement { caption: "Quick Settings — System Settings"; icon: "preferences-system"; minimized: false; desktopName: "Θ Whispering Iron Shrine"; windowId: "e" }
    ListElement { caption: "shell.rs - wally - Visual Studio Code"; icon: "com.visualstudio.code"; minimized: false; desktopName: "Δ Endless Iron Observatory"; windowId: "f" }
}
