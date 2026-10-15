import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "file:///home/helba/projects/plasma-hud/packages/org.helba.plasmahud/contents/ui"

// Islands preview over the real wallpaper: [left] [tasks, centered] [fake tray + right].
Window {
    id: w
    width: 2560
    height: 120
    visible: true
    color: "black"

    Image {
        anchors.fill: parent
        source: "__IMG__"
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignBottom
    }

    Hud {
        id: ctx
        open: false
        cfg: ({ colorMode: __MODE__, serifFont: "Noto Serif", palette: __PAL__, monoFont: "Hack", labelFont: "Fira Sans Condensed", mode: 2,
                badgeCpu: true, badgeGpu: true, badgeMem: true, badgeTemp: true, badgeNet: false, badgeUptime: false,
                sampleMs: 1000, glow: 0.7, scanlines: true, glitch: false, checkUpdates: false, showActiveTitle: true,
                groupTasks: true, currentScreenOnly: false, currentDesktopOnly: false, launchers: [],
                gpuDevice: "gpu0", terminalCommand: "konsole", probeCommand: "" })
    }

    ListModel {
        id: demoWins
        Component.onCompleted: {
            const W = (x, y, w, h, d, a, m) => append({ Geometry: Qt.rect(x, y, w, h), VirtualDesktops: String(d),
                IsActive: !!a, IsMinimized: !!m, IsLauncher: false, IsStartup: false, IsOnAllVirtualDesktops: false, StackingOrder: a ? 9 : 1 });
            W(0, 0, 2560, 1406, 0);            // left: maximized editor
            W(2600, 120, 1500, 1000, 0, true);  // middle: active terminal
            W(3900, 300, 1100, 900, 0);         // middle: file manager
            W(5120, 0, 2560, 1406, 0);          // right: maximized browser
            W(2800, 200, 1800, 1100, 1);        // desktop 2: game
            W(5400, 400, 900, 700, 1, false, true);
        }
    }
    ListModel {
        id: demo
        ListElement { display: "kitty — ~/projects/plasma-hud"; AppName: "Konsole"; decoration: "utilities-terminal"; IsActive: true; IsMinimized: false; IsLauncher: false; IsStartup: false; IsDemandingAttention: false; IsGroupParent: false; ChildCount: 0 }
        ListElement { display: "Visual Studio Code"; AppName: "Code"; decoration: "visual-studio-code"; IsActive: false; IsMinimized: false; IsLauncher: false; IsStartup: false; IsDemandingAttention: false; IsGroupParent: true; ChildCount: 3 }
        ListElement { display: "Discord"; AppName: "Discord"; decoration: "discord"; IsActive: false; IsMinimized: false; IsLauncher: false; IsStartup: false; IsDemandingAttention: true; IsGroupParent: false; ChildCount: 0 }
        ListElement { display: "Dolphin"; AppName: "Dolphin"; decoration: "system-file-manager"; IsActive: false; IsMinimized: true; IsLauncher: false; IsStartup: false; IsDemandingAttention: false; IsGroupParent: false; ChildCount: 0 }
        ListElement { display: "Edge"; AppName: "Microsoft Edge"; decoration: "microsoft-edge"; IsActive: false; IsMinimized: false; IsLauncher: false; IsStartup: false; IsDemandingAttention: false; IsGroupParent: false; ChildCount: 0 }
        ListElement { display: "System Settings"; AppName: "System Settings"; decoration: "systemsettings"; IsActive: false; IsMinimized: false; IsLauncher: true; IsStartup: false; IsDemandingAttention: false; IsGroupParent: false; ChildCount: 0 }
    }

    // A 34px panel at the bottom, 2px theme margins: applets get 30px.
    RowLayout {
        x: 8
        width: w.width - 16
        y: w.height - 34 + 2
        height: 30
        spacing: 6

        Bar { hud: ctx; modeOverride: 3; demoDesktops: ({ count: 2, current: 0, windows: demoWins }); demoTasks: demo; Layout.fillHeight: true }
        Bar { hud: ctx; modeOverride: 2; demoTasks: demo; Layout.fillHeight: true }
        // Stand-in for the stock tray + the right island wrapping it.
        Island {
            hud: ctx
            Layout.preferredHeight: 28
            Layout.preferredWidth: implicitWidth
            Row {
                spacing: 8
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                Repeater {
                    model: ["audio-volume-high", "network-wireless", "bluetooth", "notifications", "discord"]
                    Kirigami.Icon { required property string modelData; source: modelData; width: 18; height: 18 }
                }
            }
            Rectangle { width: 1; height: 17; rotation: 18; color: ctx.alpha(ctx.accent, 0.35); anchors.verticalCenter: parent ? parent.verticalCenter : undefined }
            Clock { hud: ctx; size: 26 }
            Rectangle { width: 1; height: 17; rotation: 18; color: ctx.alpha(ctx.accent, 0.35); anchors.verticalCenter: parent ? parent.verticalCenter : undefined }
            Pulse { hud: ctx; size: 26 }
        }
    }

    Timer {
        interval: 9000; running: true
        onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("__OUT__"); Qt.quit(); })
    }
}
