import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.layershell as LayerShell
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus
import "../../../org.helba.plasmahud/contents/ui"

// Chaos Gate widget. Invisible in the panel; its global shortcut (Meta+Space, set by
// hudctl) opens the gate overlay. Separate from the HUD widget on purpose: the HUD
// widget answers the launcher key (Meta), this one only its own shortcut.
PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: ""
    toolTipSubText: ""
    fullRepresentation: Item {
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        Layout.maximumWidth: 0
        Layout.minimumHeight: 0
        Layout.preferredHeight: 0
        Layout.maximumHeight: 0
    }

    Hud {
        id: ctx
        cfg: Plasmoid.configuration
        open: false
    }
    AreaNames { id: names }
    WindowFinder { id: finder }

    TaskManager.VirtualDesktopInfo { id: vd }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        activity: activities.currentActivity
        filterByActivity: true
    }

    Connections {
        target: Plasmoid
        function onActivated() { root.toggle(); }
    }

    // ------------------------------------------------------------ areas

    function salts() {
        try { return JSON.parse(Plasmoid.configuration.nameSalts || "{}"); } catch (e) { return {}; }
    }
    function setName(id, name) {
        ctx.run("busctl --user call org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager "
            + "setDesktopName ss " + ctx.shq(id) + " " + ctx.shq(name));
    }
    // KWin's default "Desktop N" names become area keywords; names you set are kept.
    function ensureNames() {
        const s = salts();
        for (let i = 0; i < vd.desktopIds.length; i++) {
            const id = vd.desktopIds[i];
            if (names.isGeneric(vd.desktopNames[i])) setName(id, names.name(i, id, s[id] || 0));
        }
    }
    function reroll() {
        const i = Math.max(0, vd.desktopIds.indexOf(vd.currentDesktop));
        const id = vd.desktopIds[i];
        const s = salts();
        s[id] = (s[id] || 0) + 1;
        Plasmoid.configuration.nameSalts = JSON.stringify(s);
        setName(id, names.name(i, id, s[id]));
    }
    Connections {
        target: vd
        function onDesktopIdsChanged() {
            nameSoon.restart();
            root.refresh();
        }
        function onDesktopNamesChanged() { root.refresh(); }
    }
    function refresh() {
        const g = gate.item;
        if (!g || !g.visible) return;
        const data = collect();
        g.panel.areas = data.areas;
        g.panel.windows = data.windows;
    }
    Timer { id: nameSoon; interval: 400; onTriggered: root.ensureNames() }
    Component.onCompleted: {
        nameSoon.start();
        arriveOnLogin();
    }

    // ------------------------------------------------------------ window frames

    // The Helba World window frames come in dark and light (title colors cannot follow
    // the scheme inside one Aurorae theme): swap them as the scheme flips, but only while
    // one of them is the active decoration.
    function syncFrames() {
        const want = "__aurorae__svg__helba-world" + (ctx.light ? "-light" : "");
        ctx.run("t=$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme); "
            + "case \"$t\" in __aurorae__svg__helba-world*) [ \"$t\" = " + want + " ] || "
            + "{ kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme " + want
            + " && qdbus6 org.kde.KWin /KWin reconfigure; } ;; esac");
        // The Kvantum widget theme (menus, controls) follows the same way; apps pick it
        // up when they next start.
        // Alacritty imports ~/.config/alacritty/helba-world.toml (and live-reloads it): point
        // that link at the matching theme when it is ours.
        const alacritty = "${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/helba-world.toml";
        ctx.run("l=\"" + alacritty + "\"; t=$(readlink \"$l\"); case \"$t\" in */packages/alacritty/helba-world*.toml) "
            + "ln -sfn \"${t%/*}/helba-world" + (ctx.light ? "-light" : "") + ".toml\" \"$l\" ;; esac");
        const kv = ctx.light ? "HelbaWorldLight" : "HelbaWorld";
        ctx.run("f=${XDG_CONFIG_HOME:-$HOME/.config}/Kvantum/kvantum.kvconfig; "
            + "t=$(kreadconfig6 --file \"$f\" --group General --key theme); "
            + "case \"$t\" in HelbaWorld*) [ \"$t\" = " + kv + " ] || "
            + "kwriteconfig6 --file \"$f\" --group General --key theme " + kv + " ;; esac");
    }
    Connections {
        target: ctx
        function onLightChanged() { root.syncFrames(); }
    }
    Timer { running: true; interval: 3000; onTriggered: root.syncFrames() }

    // ------------------------------------------------------------ OSD

    // The .hack volume / brightness OSD (Plasma's own is kept invisible by Helba Gate).
    OsdOverlay { hud: ctx }

    // ------------------------------------------------------------ arrival

    // Gate in when you arrive: on unlock and once per login (a marker in the runtime dir,
    // so restarting plasmashell does not replay it). Shows the area you land in. Cover
    // first, decide second, so the desktop never flashes before the gate-in: the cover
    // goes up when the screen locks (under the lock screen) and as soon as this loads
    // (under the splash).
    function arriveHere() {
        const i = Math.max(0, vd.desktopIds.indexOf(vd.currentDesktop));
        const parts = ctx.splitArea(areaName(i));
        ctx.arrive(parts[0], parts[1]);
    }
    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: "org.freedesktop.ScreenSaver"
        path: "/ScreenSaver"
        iface: "org.freedesktop.ScreenSaver"
        function dbusActiveChanged(active) {
            if (active) ctx.holdArrival();
            else root.arriveHere();
        }
    }
    function arriveOnLogin() {
        ctx.holdArrival();
        ctx.ask("f=\"${XDG_RUNTIME_DIR:-/tmp}/plasma-hud-arrived\"; [ -e \"$f\" ] || { : > \"$f\"; echo first; }",
            out => { if (out === "first") root.arriveHere(); else ctx.releaseArrival(); });
    }

    function areaName(i) {
        const n = String(vd.desktopNames[i] || "");
        return names.isGeneric(n) || !n ? names.name(i, vd.desktopIds[i], salts()[vd.desktopIds[i]] || 0) : n;
    }

    // ------------------------------------------------------------ gate data

    function collect() {
        const R = TaskManager.AbstractTasksModel;
        const counts = new Array(vd.desktopIds.length).fill(0);
        const wins = [];
        for (let i = 0; i < tasks.count; i++) {
            const ix = tasks.makeModelIndex(i);
            if (tasks.data(ix, R.IsLauncher) || tasks.data(ix, R.IsStartup)) continue;
            const on = tasks.data(ix, R.VirtualDesktops) || [];
            const all = tasks.data(ix, R.IsOnAllVirtualDesktops);
            let area = "";
            for (let k = 0; k < vd.desktopIds.length; k++) {
                if (all || on.indexOf(vd.desktopIds[k]) >= 0) {
                    counts[k]++;
                    if (!area) area = areaName(k);
                }
            }
            wins.push({
                row: i,
                title: String(tasks.data(ix, Qt.DisplayRole) || ""),
                app: String(tasks.data(ix, R.AppName) || ""),
                icon: tasks.data(ix, Qt.DecorationRole),
                area: all ? "every area" : area
            });
        }
        const areas = [];
        for (let k = 0; k < vd.desktopIds.length; k++) {
            areas.push({
                index: k,
                id: vd.desktopIds[k],
                name: areaName(k),
                glyph: names.glyph(k),
                current: vd.desktopIds[k] === vd.currentDesktop,
                windows: counts[k]
            });
        }
        return { areas: areas, windows: wins };
    }

    readonly property var commands: [
        { key: "launcher", glyph: "∞", name: "Root Town", hint: "the app launcher", words: "apps launcher start menu programs" },
        { key: "overview", glyph: "Ω", name: "Overview", hint: "every window, every area", words: "expose windows grid all spread" },
        { key: "new-area", glyph: "+", name: "Open a new area", hint: "a new workspace with its own keywords", words: "new workspace desktop add create" },
        { key: "close-area", glyph: "−", name: "Close this area", hint: "its windows move to the next area", words: "remove delete close workspace desktop" },
        { key: "reroll", glyph: "↻", name: "Reroll this area's keywords", hint: "give the current workspace a new name", words: "rename name workspace keywords" },
        { key: "show-desktop", glyph: "◇", name: "Show the desktop", hint: "move every window aside", words: "desktop hide minimize peek" },
        { key: "app:org.kde.systemsettings|systemsettings", glyph: "Ψ", name: "System Settings", hint: "brings it forward if already open", words: "settings preferences config control" },
        { key: "app:org.kde.konsole|konsole", glyph: "Σ", name: "Terminal", hint: "brings it forward if already open", words: "konsole shell console term" },
        { key: "app:org.kde.dolphin|dolphin", glyph: "Φ", name: "Files", hint: "brings it forward if already open", words: "dolphin file manager folders" },
        { key: "app:org.kde.plasma-systemmonitor|plasma-systemmonitor", glyph: "Θ", name: "System Monitor", hint: "brings it forward if already open", words: "processes monitor task manager" },
        { key: "capture", glyph: "Λ", name: "Capture a region", hint: "screenshot", words: "screenshot screen capture snip" },
        { key: "lock", glyph: "Ξ", name: "Lock the screen", hint: "", words: "lock away" },
        { key: "sleep", glyph: "Π", name: "Sleep", hint: "suspend to memory", words: "suspend sleep", danger: true },
        { key: "logout", glyph: "Γ", name: "Log out", hint: "end this session", words: "logout log out exit leave", danger: true },
        { key: "reboot", glyph: "Β", name: "Reboot", hint: "restart the machine", words: "restart reboot", danger: true },
        { key: "halt", glyph: "Ζ", name: "Shut down", hint: "power off", words: "shutdown power off halt", danger: true }
    ]

    function runCommand(key, shift) {
        if (key.indexOf("app:") === 0) {
            const parts = key.slice(4).split("|");
            if (shift || !finder.raiseApp(parts[0])) ctx.launch(parts[1]);
            return;
        }
        switch (key) {
        case "launcher": ctx.run("qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.activateLauncherMenu"); break;
        case "overview": ctx.run("qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut Overview"); break;
        case "show-desktop": ctx.run("qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Show Desktop'"); break;
        case "new-area": ctx.addArea(vd.desktopIds.length); break;
        case "close-area":
            if (vd.desktopIds.length > 1) ctx.removeArea(vd.currentDesktop);
            break;
        case "reroll": reroll(); break;
        case "capture": ctx.launch("spectacle -r"); break;
        case "lock": ctx.run("loginctl lock-session"); break;
        case "sleep": ctx.run("systemctl suspend"); break;
        case "logout": ctx.run("qdbus6 org.kde.Shutdown /Shutdown logout"); break;
        case "reboot": ctx.run("qdbus6 org.kde.Shutdown /Shutdown logoutAndReboot"); break;
        case "halt": ctx.run("qdbus6 org.kde.Shutdown /Shutdown logoutAndShutdown"); break;
        }
    }

    // ------------------------------------------------------------ the gate

    Loader {
        id: gate
        active: false
        sourceComponent: Gate {
            hud: ctx
            Connections {
                target: panel
                function onWarpTo(index) {
                    if (vd.desktopIds[index] === vd.currentDesktop) return;
                    ctx.switchDesktop(vd.desktopIds[index], root.areaName(index));
                }
                // A window on another area warps there first; one here is just raised.
                function onFocusWindow(row) {
                    const ix = tasks.makeModelIndex(row);
                    const R = TaskManager.AbstractTasksModel;
                    const on = tasks.data(ix, R.VirtualDesktops) || [];
                    const here = tasks.data(ix, R.IsOnAllVirtualDesktops) || on.indexOf(vd.currentDesktop) >= 0;
                    if (here) {
                        tasks.requestActivate(ix);
                        return;
                    }
                    const k = Math.max(0, vd.desktopIds.indexOf(on[0]));
                    const parts = ctx.splitArea(root.areaName(k));
                    ctx.warp(parts[0], parts[1], () => tasks.requestActivate(ix));
                }
                function onCommand(key, shift) { root.runCommand(key, shift); }
                // The gate stays open; its area list refreshes once KWin has removed it.
                function onRemoveArea(index) {
                    if (vd.desktopIds.length <= 1) return;
                    ctx.removeArea(vd.desktopIds[index]);
                }
            }
        }
    }

    // While the gate is open every screen dims, one layer under the gate itself.
    Instantiator {
        model: Qt.application.screens
        delegate: Window {
            required property var modelData
            // Qt picks a new window's screen from its position: start it on its own screen.
            screen: modelData
            x: modelData.virtualX
            y: modelData.virtualY
            width: modelData.width
            height: modelData.height
            color: "transparent"
            flags: Qt.FramelessWindowHint
            visible: !!gate.item && gate.item.visible

            LayerShell.Window.scope: "org.helba.chaosgate.veil"
            LayerShell.Window.layer: LayerShell.Window.LayerTop
            LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
            LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
            LayerShell.Window.exclusionZone: -1
            LayerShell.Window.screenConfiguration: LayerShell.Window.ScreenFromQWindow

            Rectangle {
                anchors.fill: parent
                color: ctx.alpha(ctx.glassBottom, 0.8)
                opacity: parent.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: gate.item.close()
            }
        }
    }

    function toggle() {
        gate.active = true;
        const g = gate.item;
        if (!g) return;
        if (g.visible) {
            g.close();
            return;
        }
        const data = collect();
        g.panel.areas = data.areas;
        g.panel.windows = data.windows;
        g.panel.commands = commands;
        g.open();
    }
}
