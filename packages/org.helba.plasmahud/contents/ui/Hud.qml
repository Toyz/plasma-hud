import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.taskmanager as TaskManager

// Shared HUD context: live sensors, palette, history, hudprobe bridge and formatting helpers.
// Every visual component receives this object as `hud`.
Item {
    id: hud

    required property var cfg
    property bool open: false

    visible: false

    // ----------------------------------------------------------- palette

    // SYSTEM follows the Plasma accent (and so accent-from-wallpaper when enabled),
    // pushed to neon saturation, with a split-complement as the second accent.
    readonly property color sysAccent: neon(Kirigami.Theme.highlightColor, 0)
    readonly property color sysAccent2: neon(Kirigami.Theme.highlightColor, 0.5)
    function neon(c, shift) {
        const h = ((c.hslHue < 0 ? 0.55 : c.hslHue) + shift) % 1;
        return Qt.hsla(h, Math.max(0.85, c.hslSaturation), Math.min(0.66, Math.max(0.55, c.hslLightness)), 1);
    }

    readonly property var palettes: [
        { name: "SYSTEM",     accent: sysAccent, accent2: sysAccent2 },
        { name: "THE WORLD",  accent: gold, accent2: cyan },
        { name: "NEON GRID",  accent: "#00f0ff", accent2: "#ff2a6d" },
        { name: "SYNTHWAVE",  accent: "#ff3df2", accent2: "#29f0ff" },
        { name: "ACID",       accent: "#b6ff00", accent2: "#ff2bd6" },
        { name: "AMBER CRT",  accent: "#ffb000", accent2: "#ff4f1f" },
        { name: "ICEBREAKER", accent: "#8fd8ff", accent2: "#c58bff" },
        { name: "BLOODLINE",  accent: "#ff3b4a", accent2: "#ffd23f" },
        { name: "TOXIC",      accent: "#39ff88", accent2: "#f5e663" }
    ]
    readonly property var pal: palettes[Math.max(0, Math.min(palettes.length - 1, cfg.palette || 0))]
    readonly property string paletteName: pal.name
    readonly property color accent: pal.accent
    readonly property color accent2: pal.accent2
    readonly property color warn: light ? "#a07a06" : "#f5e663"
    readonly property color crit: light ? "#c81e45" : "#ff3864"
    readonly property color panel: world || light ? glassBottom : Qt.rgba(0.020, 0.028, 0.048, 0.94)
    readonly property bool world: pal.name === "THE WORLD"
    readonly property color text: world || light ? ink : Qt.tint("#e8f2ff", alpha(accent, 0.12))
    readonly property color dim: world ? inkDim : alpha(text, 0.45)
    readonly property string monoFont: cfg.monoFont || "monospace"
    readonly property string labelFont: cfg.labelFont || "sans-serif"
    readonly property string serifFont: cfg.serifFont || "Noto Serif"

    // Light or dark. System (colorMode 0) follows the KDE color scheme as it changes:
    // a light window background means the light set.
    readonly property int colorMode: cfg.colorMode || 0
    readonly property bool light: colorMode === 1
        || (colorMode === 0 && Kirigami.Theme.backgroundColor.hslLightness > 0.5)

    // .hack ("The World") tokens. Dark: gold trim, data-cyan selection, midnight glass.
    // Light: bronze trim, deep teal data, parchment glass, navy ink.
    readonly property color gold: light ? "#8a6418" : "#b8935a"
    readonly property color cyan: light ? "#14708a" : "#8fe3ff"
    // Nearly opaque: without blur behind it, translucency only shows window clutter.
    readonly property color glassTop: light ? Qt.rgba(0.985, 0.970, 0.925, 0.97) : Qt.rgba(0.09, 0.12, 0.26, 0.97)
    readonly property color glassBottom: light ? Qt.rgba(0.945, 0.925, 0.870, 0.98) : Qt.rgba(0.02, 0.035, 0.09, 0.98)
    readonly property color ink: light ? "#1a2033" : "#eaf0fb"
    readonly property color inkDim: light ? "#5a6380" : "#8d98b6"
    // Text drawn on a solid gold fill.
    readonly property color onGold: light ? "#fbf6e8" : "#1a1408"
    readonly property real glow: Math.max(0, Math.min(1, cfg.glow === undefined ? 0.7 : cfg.glow))

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function css(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
            + Math.round(c.b * 255) + "," + a + ")";
    }
    function level(v) { return v >= 85 ? crit : v >= 65 ? warn : accent; }
    function tempLevel(t) { return t >= 85 ? crit : t >= 72 ? warn : accent; }

    // ----------------------------------------------------------- sensors

    readonly property int sampleRate: Math.max(250, cfg.sampleMs || 1000)
    readonly property string gpuBase: "gpu/" + (cfg.gpuDevice || "gpu0") + "/"

    component S: Sensors.Sensor { updateRateLimit: hud.sampleRate }

    S { id: sCpu; sensorId: "cpu/all/usage" }
    S { id: sCpuTemp; sensorId: "cpu/all/averageTemperature" }
    S { id: sCpuFreq; sensorId: "cpu/all/averageFrequency" }
    S { id: sThreads; sensorId: "cpu/all/coreCount"; updateRateLimit: 60000 }
    S { id: sMem; sensorId: "memory/physical/usedPercent" }
    S { id: sMemUsed; sensorId: "memory/physical/used" }
    S { id: sMemTotal; sensorId: "memory/physical/total"; updateRateLimit: 60000 }
    S { id: sSwap; sensorId: "memory/swap/usedPercent" }
    S { id: sGpu; sensorId: hud.gpuBase + "usage" }
    S { id: sGpuTemp; sensorId: hud.gpuBase + "temperature" }
    S { id: sGpuPower; sensorId: hud.gpuBase + "power" }
    S { id: sGpuFreq; sensorId: hud.gpuBase + "coreFrequency" }
    S { id: sVramUsed; sensorId: hud.gpuBase + "usedVram" }
    S { id: sVramTotal; sensorId: hud.gpuBase + "totalVram"; updateRateLimit: 60000 }
    S { id: sGpuName; sensorId: hud.gpuBase + "name"; updateRateLimit: 60000 }
    S { id: sNetDown; sensorId: "network/all/download" }
    S { id: sNetUp; sensorId: "network/all/upload" }
    S { id: sDisk; sensorId: "disk/all/usedPercent"; updateRateLimit: 10000 }
    S { id: sUptime; sensorId: "os/system/uptime" }
    S { id: sHost; sensorId: "os/system/hostname"; updateRateLimit: 60000 }
    S { id: sOs; sensorId: "os/system/prettyName"; updateRateLimit: 60000 }
    S { id: sKernel; sensorId: "os/kernel/prettyName"; updateRateLimit: 60000 }
    S { id: sPlasma; sensorId: "os/plasma/plasmaVersion"; updateRateLimit: 60000 }
    S { id: sQt; sensorId: "os/plasma/qtVersion"; updateRateLimit: 60000 }

    readonly property real cpu: sCpu.value || 0
    readonly property real cpuTemp: sCpuTemp.value || 0
    readonly property real cpuFreq: sCpuFreq.value || 0
    readonly property int threads: sThreads.value || 0
    readonly property real mem: sMem.value || 0
    readonly property real memUsed: sMemUsed.value || 0
    readonly property real memTotal: sMemTotal.value || 0
    readonly property real swap: sSwap.value || 0
    readonly property real gpu: sGpu.value || 0
    readonly property real gpuTemp: sGpuTemp.value || 0
    readonly property real gpuPower: sGpuPower.value || 0
    readonly property real gpuFreq: sGpuFreq.value || 0
    readonly property real vramUsed: sVramUsed.value || 0
    readonly property real vramTotal: sVramTotal.value || 0
    readonly property real vram: vramTotal > 0 ? vramUsed / vramTotal * 100 : 0
    readonly property string gpuName: sGpuName.value || ""
    readonly property string gpuShortName: {
        const m = gpuName.match(/\[(.*)\]/);
        return (m ? m[1] : gpuName).replace(/^(NVIDIA\s+|AMD\s+)?(GeForce\s+|Radeon\s+)?/i, "").toUpperCase();
    }
    readonly property real netDown: sNetDown.value || 0
    readonly property real netUp: sNetUp.value || 0
    readonly property real disk: sDisk.value || 0
    readonly property real uptime: sUptime.value || 0
    readonly property string hostname: sHost.value || ""
    readonly property string osName: sOs.value || ""
    readonly property string kernel: sKernel.value || ""
    property date now: new Date()

    // ----------------------------------------------------------- history

    readonly property int histLen: 90
    property var cpuHist: []
    property var gpuHist: []
    property var memHist: []
    property var vramHist: []
    property var netDownHist: []
    property var netUpHist: []
    readonly property real cpuPeak: peak(cpuHist)
    readonly property real gpuPeak: peak(gpuHist)
    readonly property real memPeak: peak(memHist)
    readonly property real vramPeak: peak(vramHist)

    Timer {
        interval: hud.sampleRate
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            hud.cpuHist = hud.push(hud.cpuHist, hud.cpu);
            hud.gpuHist = hud.push(hud.gpuHist, hud.gpu);
            hud.memHist = hud.push(hud.memHist, hud.mem);
            hud.vramHist = hud.push(hud.vramHist, hud.vram);
            hud.netDownHist = hud.push(hud.netDownHist, hud.netDown);
            hud.netUpHist = hud.push(hud.netUpHist, hud.netUp);
        }
    }

    Timer {
        interval: 1000
        running: hud.open
        repeat: true
        triggeredOnStart: true
        onTriggered: hud.now = new Date()
    }

    // ---------------------------------------------------------- hudprobe

    property var probe: ({})
    property bool probeOk: true
    property var updates: ({ updates: -2, list: [] })
    readonly property var procs: probe.top || []
    KCoreAddons.KUser { id: kuser }
    readonly property string user: kuser.loginName || probe.user || ""
    readonly property string fullName: kuser.fullName || user
    readonly property url avatar: kuser.faceIconUrl
    readonly property string iface: probe.iface || ""
    readonly property string probeCmd: cfg.probeCommand
        ? cfg.probeCommand
        : shq(decodeURIComponent(Qt.resolvedUrl("../bin/hudprobe").toString().replace(/^file:\/\//, "")))
    readonly property string updatesCmd: probeCmd + " updates"

    function run(cmd) { exec.run(cmd); }

    // Gate warp across every screen; fn runs under the white-out (see WarpOverlay).
    Loader {
        id: warpLoader
        // Inside WarpOverlay a bare "hud" is its own (empty) property, so hand it over from here.
        readonly property QtObject ctx: hud
        active: false
        sourceComponent: WarpOverlay { hud: warpLoader.ctx }
    }
    function arrive(glyph, title) {
        warpLoader.active = true;
        if (warpLoader.item) warpLoader.item.arrive(glyph, title);
    }
    // Run a command and hand its trimmed stdout to fn.
    property var waiting: ({})
    function ask(cmd, fn) {
        waiting[cmd] = fn;
        exec.run(cmd);
    }
    function warp(glyph, title, fn) {
        warpLoader.active = true;
        if (warpLoader.item) warpLoader.item.play(glyph, title, fn);
        else if (fn) fn();
    }
    // "Δ Hidden Forbidden Holy Ground" -> ["Δ", "Hidden Forbidden Holy Ground"]
    // Areas (virtual desktops). A new one is named "Desktop N"; the Chaos Gate renames
    // it with keywords. Removing one moves its windows to a neighbour (KWin does that).
    // A new area is warped to as soon as it exists and has its keywords.
    function addArea(count) {
        newAreaAt = count;
        newAreaTimeout.restart();
        run("busctl --user call org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager "
            + "createDesktop us " + count + " " + shq("Desktop " + (count + 1)));
    }
    property int newAreaAt: -1
    TaskManager.VirtualDesktopInfo { id: areaInfo }
    Connections {
        target: areaInfo
        enabled: hud.newAreaAt >= 0
        function onDesktopIdsChanged() { hud.enterNewArea(false); }
        function onDesktopNamesChanged() { hud.enterNewArea(false); }
    }
    // The Chaos Gate renames "Desktop N" a moment after it appears; don't wait forever.
    Timer {
        id: newAreaTimeout
        interval: 1500
        onTriggered: hud.enterNewArea(true)
    }
    function enterNewArea(force) {
        const i = newAreaAt;
        if (i < 0 || i >= areaInfo.desktopIds.length) {
            if (force) newAreaAt = -1;
            return;
        }
        const name = String(areaInfo.desktopNames[i] || "");
        if (!force && /^Desktop \d+$/.test(name)) return;
        newAreaAt = -1;
        newAreaTimeout.stop();
        switchDesktop(areaInfo.desktopIds[i], name);
    }
    function removeArea(id) {
        run("busctl --user call org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager "
            + "removeDesktop s " + shq(id));
    }
    function splitArea(name) {
        const n = String(name || "");
        return /^\S\s/.test(n) && !/^[A-Za-z0-9]/.test(n) ? [n.charAt(0), n.slice(2)] : ["", n];
    }
    function switchDesktop(id, name) {
        const parts = splitArea(name);
        warp(parts[0], parts[1], () => run("busctl --user set-property org.kde.KWin /VirtualDesktopManager "
            + "org.kde.KWin.VirtualDesktopManager current s " + id));
    }
    function launch(cmd) { exec.run("setsid -f sh -c " + shq(cmd) + " >/dev/null 2>&1"); }
    function sample() { exec.run(probeCmd); }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []

        function run(cmd) {
            if (connectedSources.indexOf(cmd) < 0) connectSource(cmd);
        }

        onNewData: (source, data) => {
            disconnectSource(source);
            const out = (data["stdout"] || "").trim();
            const waiter = hud.waiting[source];
            if (waiter) {
                delete hud.waiting[source];
                waiter(out);
                return;
            }
            if (source === hud.probeCmd) {
                try {
                    hud.probe = JSON.parse(out);
                    hud.probeOk = true;
                } catch (e) {
                    hud.probeOk = false;
                }
            } else if (source === hud.updatesCmd) {
                try { hud.updates = JSON.parse(out); } catch (e) { hud.updates = { updates: -1, list: [] }; }
            }
        }
    }

    // Preferred path: the socket-activated daemon pushes a snapshot every 2s while
    // we are connected, and only while the HUD is open.
    Loader {
        id: link
        source: "ProbeLink.qml"
        onLoaded: item.active = Qt.binding(() => hud.open)
    }
    readonly property bool socketLinked: link.status === Loader.Ready
    readonly property bool socketLive: socketLinked && link.item.connected
    Connections {
        target: hud.socketLinked ? link.item : null
        function onJsonChanged() {
            try {
                const d = JSON.parse(link.item.json);
                hud.probe = d;
                hud.probeOk = true;
                if (d.updates) hud.updates = d.updates;
            } catch (e) {
                hud.probeOk = false;
            }
        }
    }

    // Fallback path: spawn the one-shot probe if the socket is not up shortly after opening.
    Timer {
        interval: 2000
        running: hud.open && !hud.socketLive
        repeat: true
        onTriggered: hud.sample()
    }
    Timer {
        interval: 45 * 1000
        running: !!hud.cfg.checkUpdates && !hud.socketLinked
        repeat: true
        onTriggered: {
            interval = 30 * 60 * 1000;
            exec.run(hud.updatesCmd);
        }
    }

    // ------------------------------------------------------ derived text

    readonly property var sysRows: {
        const l = probe.load || [];
        const u = updates.updates;
        return [
            ["LOAD", l.length ? l.map(x => x.toFixed(2)).join("  ") : "--", false],
            ["TASKS", (probe.procs || "--") + " / " + (probe.threads || "--") + "T", false],
            ["NODE", probe.ip || "--", false],
            ["DISK", Math.round(disk) + "% USED", disk >= 85],
            ["PKGS", probe.pkgs ? probe.pkgs + " INSTALLED" : "--", false],
            ["SYNC", ago(probe.lastUpgrade), false],
            ["UPDATE", u === -2 ? (cfg.checkUpdates ? "SCANNING" : "OFF")
                : u < 0 ? "ERR" : u === 0 ? "CURRENT" : u + " PENDING", u > 0],
        ];
    }
    readonly property string tickerText: {
        const parts = [
            "NODE " + (hostname || "--").toUpperCase(),
            probe.ip || "0.0.0.0",
            (probe.cpuModel || "CPU").replace(/\s+\d+-Core Processor/i, "").toUpperCase(),
            gpuShortName || "GPU",
            kernel.toUpperCase(),
            "PLASMA " + (sPlasma.value || "?"),
            "QT " + (sQt.value || "?"),
            "LINK " + (iface || "--").toUpperCase(),
        ];
        return "   ·   " + parts.join("   ·   ") + "   ·   ";
    }

    // -------------------------------------------------------- formatting

    function pad2(v) { const n = Math.round(v); return n < 10 ? "0" + n : "" + n; }
    function pad3(v) { const n = Math.min(100, Math.round(v)); return n < 10 ? "0" + n : "" + n; }
    function bytes(b) {
        const u = ["B", "K", "M", "G", "T"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)) + u[i];
    }
    function rate(b) { return bytes(b) + "/S"; }
    function rateShort(b) { return bytes(b); }
    function uptimeShort(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? d + "D" + pad2(h) + "H" : pad2(h) + ":" + pad2(m);
    }
    function uptimeLong(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d + "D " + pad2(h) + ":" + pad2(m);
    }
    function ago(stamp) {
        if (!stamp) return "--";
        const t = new Date(stamp.replace(/([+-]\d\d)(\d\d)$/, "$1:$2"));
        if (isNaN(t.getTime())) return "--";
        const s = (now.getTime() - t.getTime()) / 1000;
        if (s < 3600) return Math.max(0, Math.floor(s / 60)) + "M AGO";
        if (s < 86400) return Math.floor(s / 3600) + "H AGO";
        return Math.floor(s / 86400) + "D " + Math.floor(s % 86400 / 3600) + "H AGO";
    }
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    function peak(a) { let m = 0; for (const v of a) m = Math.max(m, v); return m; }
    function push(a, v) {
        const n = a.length >= histLen ? a.slice(a.length - histLen + 1) : a.slice();
        n.push(v);
        return n;
    }
}
