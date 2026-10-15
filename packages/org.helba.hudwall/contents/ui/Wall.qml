import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

// The wallpaper body. Kept free of WallpaperItem so dev/ can render it standalone.
Item {
    id: root

    required property var cfg
    // Image-reactive effects first (they transform the picture by its own pixels),
    // then the procedural overlay effects. Index == config value.
    readonly property var effects: ["drift", "drain", "depth", "ink", "sort", "growth", "bloom", "edges", "hue", "halftone",
                                    "plasma", "gyroid", "synthgrid", "datamosh", "hexlens", "rd_show"]
    readonly property int effect: cfg.Effect
    readonly property bool effectOn: effect >= 0 && effect < effects.length
    readonly property bool usesRd: effect === 5 || effect === 15
    readonly property real intensity: cfg.Intensity
    readonly property url shader: Qt.resolvedUrl("../shaders/" + effects[effectOn ? effect : 0] + ".frag.qsb")

    // ----------------------------------------------------------- palette

    readonly property var fixed: [
        ["#00f0ff", "#ff2a6d"], ["#ff3df2", "#29f0ff"], ["#b6ff00", "#ff2bd6"], ["#ffb000", "#ff4f1f"],
        ["#8fd8ff", "#c58bff"], ["#ff3b4a", "#ffd23f"], ["#39ff88", "#f5e663"]
    ]
    function neon(c, shift) {
        const h = ((c.hslHue < 0 ? 0.55 : c.hslHue) + shift) % 1;
        return Qt.hsla(h, Math.max(0.8, c.hslSaturation), Math.min(0.64, Math.max(0.52, c.hslLightness)), 1);
    }
    Kirigami.ImageColors {
        id: imageColors
        source: img.status === Image.Ready ? img.source : ""
    }
    readonly property bool fromImage: cfg.Palette === 1 && imageColors.palette.length > 0
    readonly property color seedColor: fromImage ? imageColors.highlight : Kirigami.Theme.highlightColor
    readonly property color accent: cfg.Palette >= 2 ? fixed[cfg.Palette - 2][0] : neon(seedColor, 0)
    readonly property color accent2: cfg.Palette >= 2 ? fixed[cfg.Palette - 2][1]
        : fromImage && imageColors.palette.length > 1 ? neon(imageColors.palette[1].color, 0.08)
        : neon(seedColor, 0.5)

    // ---------------------------------------------------------- geometry

    readonly property rect spanRect: {
        const ss = Qt.application.screens;
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (let i = 0; i < ss.length; i++) {
            x0 = Math.min(x0, ss[i].virtualX); y0 = Math.min(y0, ss[i].virtualY);
            x1 = Math.max(x1, ss[i].virtualX + ss[i].width); y1 = Math.max(y1, ss[i].virtualY + ss[i].height);
        }
        return ss.length ? Qt.rect(x0, y0, x1 - x0, y1 - y0) : Qt.rect(0, 0, width, height);
    }
    readonly property vector4d span: cfg.Span
        ? Qt.vector4d(Screen.virtualX - spanRect.x, Screen.virtualY - spanRect.y, spanRect.width, spanRect.height)
        : Qt.vector4d(0, 0, width, height)
    readonly property real seed: {
        if (cfg.Seed >= 0) return cfg.Seed;
        // Spanning screens share one seed so the pattern runs on across the seams.
        if (cfg.Span) return 0.4217;
        let h = 7;
        const n = Screen.name || "screen";
        for (let i = 0; i < n.length; i++) h = (h * 31 + n.charCodeAt(i)) % 100003;
        return h / 100003;
    }

    // -------------------------------------------------------------- time

    property real time: 0
    readonly property bool paused: (cfg.PauseWhenCovered && covered) || !root.visible
    Timer {
        id: clock
        interval: Math.round(1000 / Math.max(5, Math.min(240, cfg.Fps)))
        repeat: true
        running: root.effectOn && !root.paused
        // Wall-clock time, not accumulated frames: every screen reads the same moment, so
        // spanning effects stay aligned even after one screen pauses under a window.
        onTriggered: {
            root.time = (Date.now() / 1000 % 21600) * cfg.Speed;
            rd.tick();
        }
    }

    // Stop rendering while the wallpaper is hidden: a maximized or fullscreen window, or
    // windows that together cover nearly all of this screen.
    property bool covered: false
    // Attached Screen only means this wallpaper's screen on an Item (in a Timer it is the primary).
    readonly property rect screenRect: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: windows
        groupMode: TaskManager.TasksModel.GroupDisabled
        screenGeometry: root.screenRect
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity
        filterByScreen: true
        filterByVirtualDesktop: true
        filterByActivity: true
        filterNotMinimized: true
        filterHidden: true
    }
    Instantiator {
        id: windowWatch
        model: cfg.PauseWhenCovered ? windows : null
        delegate: QtObject {
            required property var model
            readonly property bool big: !!(model.IsMaximized || model.IsFullScreen)
            readonly property rect g: model.Geometry || Qt.rect(0, 0, 0, 0)
            onBigChanged: coverCheck.restart()
            onGChanged: coverCheck.restart()
        }
        onObjectAdded: coverCheck.restart()
        onObjectRemoved: coverCheck.restart()
    }
    Timer {
        id: coverCheck
        interval: 150
        onTriggered: {
            const rects = [];
            for (let i = 0; i < windowWatch.count; i++) {
                const o = windowWatch.objectAt(i);
                if (!o) continue;
                if (o.big) { root.covered = true; return; }
                if (o.g.width > 0) rects.push(o.g);
            }
            // Sample a 24x14 grid of this screen; covered when 90% of it is under windows.
            const sx = root.screenRect.x, sy = root.screenRect.y, sw = root.screenRect.width, sh = root.screenRect.height;
            let under = 0;
            for (let gy = 0; gy < 14; gy++)
                for (let gx = 0; gx < 24; gx++) {
                    const px = sx + (gx + 0.5) * sw / 24, py = sy + (gy + 0.5) * sh / 14;
                    for (const r of rects)
                        if (px >= r.x && px < r.x + r.width && py >= r.y && py < r.y + r.height) { under++; break; }
                }
            root.covered = under >= 0.9 * 24 * 14;
        }
    }

    // ------------------------------------------------------------- image

    Rectangle {
        anchors.fill: parent
        color: "#05070c"
    }
    Image {
        id: img
        anchors.fill: parent
        source: cfg.Image || ""
        fillMode: cfg.FillMode
        asynchronous: true
        cache: false
        smooth: true
        sourceSize: Qt.size(Math.round(root.width * Screen.devicePixelRatio), Math.round(root.height * Screen.devicePixelRatio))
    }
    ShaderEffectSource {
        id: imgTex
        sourceItem: img
        hideSource: root.effectOn
        live: true
        mipmap: true
        smooth: true
        visible: false
    }

    // ----------------------------------------------------- reaction-diffusion

    // Gray-Scott at a third of screen resolution, three steps per frame through a
    // ping-pong chain, fed back into itself via a recursive ShaderEffectSource.
    Item {
        id: rd
        readonly property bool on: root.usesRd
        readonly property size sim: Qt.size(Math.max(64, Math.round(root.width / 3)), Math.max(64, Math.round(root.height / 3)))
        property real init: 1
        property real dropOn: 0
        property point drop: Qt.point(0.5, 0.5)
        property int frames: 0
        width: sim.width
        height: sim.height
        visible: on
        enabled: false

        function tick() {
            if (!on) return;
            frames++;
            init = frames < 3 ? 1 : 0;
            dropOn = 0;
            if (frames % Math.max(8, Math.round(cfg.Fps * 1.2)) === 0) {
                drop = Qt.point(Math.random(), Math.random());
                dropOn = 1;
            }
        }
        onOnChanged: frames = 0
        Connections {
            target: root
            function onEffectChanged() { rd.frames = 0; }
        }
        Connections {
            target: img
            function onStatusChanged() { if (img.status === Image.Ready) rd.frames = 0; }
        }

        component Step: ShaderEffect {
            property var prev
            property real time: root.time
            property real seed: root.seed
            property real init: rd.init
            property real dropOn: rd.dropOn
            property point texel: Qt.point(1 / rd.sim.width, 1 / rd.sim.height)
            property point drop: rd.drop
            property real useImage: root.effect === 5 && img.status === Image.Ready ? 1 : 0
            property var src: imgTex
            width: rd.sim.width
            height: rd.sim.height
            vertexShader: Qt.resolvedUrl("../shaders/rd_step.vert.qsb")
            fragmentShader: Qt.resolvedUrl("../shaders/rd_step.frag.qsb")
        }
        component Buffer: ShaderEffectSource {
            textureSize: rd.sim
            format: ShaderEffectSource.RGBA16F
            smooth: false
            hideSource: true
            live: rd.on
            wrapMode: ShaderEffectSource.Repeat
        }

        Buffer { id: fieldBuf; sourceItem: s3; recursive: true }
        Step { id: s1; prev: fieldBuf }
        Buffer { id: b1; sourceItem: s1 }
        Step { id: s2; prev: b1 }
        Buffer { id: b2; sourceItem: s2 }
        Step { id: s3; prev: b2 }
    }

    // ------------------------------------------------------------- effect

    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: root.effectOn
        vertexShader: Qt.resolvedUrl("../shaders/fx.vert.qsb")
        fragmentShader: root.shader

        property var src: imgTex
        property var field: rd.on ? fieldBuf : imgTex
        property real time: root.time
        property real intensity: root.intensity
        property real hasImage: img.status === Image.Ready ? 1 : 0
        property real seed: root.seed
        property point resolution: Qt.point(root.width, root.height)
        property vector4d span: root.span
        property color accent: root.accent
        property color accent2: root.accent2
        property real chroma: root.cfg.ColorDrift === undefined ? 0.35 : root.cfg.ColorDrift

        onStatusChanged: if (status === ShaderEffect.Error) console.warn("hudwall:", root.effects[root.effect], log)

        Behavior on accent { ColorAnimation { duration: 1200 } }
        Behavior on accent2 { ColorAnimation { duration: 1200 } }
    }
}
