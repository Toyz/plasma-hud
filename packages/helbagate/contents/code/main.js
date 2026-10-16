// Helba Gate: windows gate in and out like The World. KWin only takes third-party
// animation effects as scripts, so this file is just wiring; the look is the two
// shaders in ../shaders (gate_in: assemble from data cells, gate_out: drain away).
"use strict";

const traits = Effect.MapTexture | Effect.Modulate;
const gateIn = effect.addFragmentShader(traits, "gate_in.frag");
const gateOut = effect.addFragmentShader(traits, "gate_out.frag");

// Fixed lengths: a gate should read as a gate even when the global animation speed is
// turned up for everything else.
const openMs = 900;
const closeMs = 800;
const minimizeMs = 480;
const restoreMs = 520;

const QUICK = ["spectacle", "krunner", "polkit-kde-authentication-agent", "xwaylandvideobridge",
    "ksmserver-logout-greeter", "kscreenlocker", "org.kde.kdeconnect"];

// Real application windows only: no panels, popups, menus, tooltips or the desktop.
function gated(w) {
    if (effects.hasActiveFullScreenEffect) return false;
    // Layer-shell overlays (the gate warp, the Chaos Gate and its veils) report as normal,
    // managed windows when their scope is a custom one, so go by owner: nothing that
    // plasmashell draws gets gated. Gating them flashed the drain grid across screens
    // and made the Chaos Gate assemble one screen at a time.
    if (!w.managed) return false;
    if (String(w.windowClass).indexOf("plasmashell") >= 0) return false;
    // Fullscreen windows (Spectacle's capture overlay, games, video) and quick-use
    // utilities should appear at once, not after a gate.
    if (w.fullScreen) return false;
    const cls = String(w.windowClass).toLowerCase();
    for (const quick of QUICK) {
        if (cls.indexOf(quick) >= 0) return false;
    }
    if (w.popupWindow || w.outline || w.lockScreen || w.inputMethod) return false;
    if (w.desktopWindow || w.dock || w.splash || w.toolbar || w.notification || w.onScreenDisplay) return false;
    return w.normalWindow || w.dialog;
}

function stop(w) {
    if (w.gateAnimation) {
        cancel(w.gateAnimation);
        delete w.gateAnimation;
    }
}

function gateInto(w, ms, from) {
    stop(w);
    w.gateAnimation = animate({
        window: w,
        duration: ms,
        curve: QEasingCurve.OutCubic,
        fragmentShader: gateIn,
        animations: [
            { type: Effect.ShaderUniform, uniform: "progress", from: 0, to: 1 },
            { type: Effect.Scale, from: from }
        ]
    });
}

function gateOutOf(w, ms, to, offset) {
    stop(w);
    const animations = [
        { type: Effect.ShaderUniform, uniform: "progress", from: 0, to: 1 },
        { type: Effect.Scale, to: to }
    ];
    if (offset) animations.push({ type: Effect.Translation, to: offset });
    w.gateAnimation = animate({
        window: w,
        duration: ms,
        // Moves from the first frame; an ease-in sat still for half the time and then
        // vanished at once, which read as no animation at all.
        curve: QEasingCurve.InOutSine,
        fragmentShader: gateOut,
        animations: animations
    });
}

// Minimize drains toward the window's task tile when the strip has published it.
function toTile(w) {
    const icon = w.iconGeometry;
    if (!icon || icon.width <= 0) return null;
    const g = w.geometry;
    return {
        value1: (icon.x + icon.width / 2) - (g.x + g.width / 2),
        value2: (icon.y + icon.height / 2) - (g.y + g.height / 2)
    };
}

function watch(w) {
    w.minimizedChanged.connect(() => {
        if (!gated(w)) return;
        if (w.minimized) gateOutOf(w, minimizeMs, { value1: 0.55, value2: 0.55 }, toTile(w));
        else gateInto(w, restoreMs, { value1: 0.94, value2: 0.94 });
    });
}

effects.windowAdded.connect(w => {
    watch(w);
    if (!gated(w) || !w.visible) return;
    if (!effect.grab(w, Effect.WindowAddedGrabRole)) return;
    gateInto(w, openMs, { value1: 0.96, value2: 0.96 });
});

effects.windowClosed.connect(w => {
    if (!gated(w)) return;
    if (!effect.grab(w, Effect.WindowClosedGrabRole)) return;
    gateOutOf(w, closeMs, { value1: 0.97, value2: 0.97 }, null);
});

// Another effect took the window over: let it.
effects.windowDataChanged.connect((w, role) => {
    if (role === Effect.WindowAddedGrabRole || role === Effect.WindowClosedGrabRole) {
        if (w.gateAnimation && effect.isGrabbed(w, role)) stop(w);
    }
});

effects.stackingOrder.forEach(watch);
