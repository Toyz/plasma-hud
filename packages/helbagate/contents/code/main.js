// Helba Gate: windows gate in and out like The World. KWin only takes third-party
// animation effects as scripts, so this file is just wiring; the look is the two
// shaders in ../shaders (gate_in: assemble from data cells on restore, gate_out: drain
// away on close and minimize). New windows fade in without a shader (see fadeInto).
"use strict";

const traits = Effect.MapTexture | Effect.Modulate;
const gateIn = effect.addFragmentShader(traits, "gate_in.frag");
const gateOut = effect.addFragmentShader(traits, "gate_out.frag");

// Fixed lengths: a gate should read as a gate even when the global animation speed is
// turned up for everything else.
const fadeMs = 380;
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

// Opening is a plain fade and rise, no shader. The gate shader draws from an offscreen
// copy, and on KWin 6.8 a copy made from a new window's first frame keeps that frame's
// scale (the window showed zoomed in until the gate ended); holding the window back
// instead stalled the app (KWin sends no frame callbacks to a window it does not draw).
// Close, minimize and restore act on settled windows and keep the gate.
function fadeInto(w) {
    stop(w);
    w.gateAnimation = animate({
        window: w,
        duration: fadeMs,
        curve: QEasingCurve.OutCubic,
        animations: [
            { type: Effect.Opacity, from: 0, to: 1 },
            { type: Effect.Scale, from: { value1: 0.95, value2: 0.95 }, to: { value1: 1.0, value2: 1.0 } },
            { type: Effect.Brightness, from: 1.35, to: 1.0 }
        ]
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
    fadeInto(w);
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
