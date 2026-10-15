#!/usr/bin/env python3
"""Generate the .hack (The World) window decorations: Aurorae themes helba-world (dark)
and helba-world-light, into packages/aurorae/.

    python3 dev/aurorae_gen.py packages/aurorae

Aurorae draws the frame from a FrameSvg with the decoration-* pieces (plus -inactive,
-maximized and -maximized-inactive variants) and each button from its own SVG with
active / inactive / hover / pressed / deactivated centers. Piece sizes must match the
rc layout exactly: the outer padding is the shadow, then the border.

Title text colors live in the rc and cannot follow the color scheme, hence one theme
per scheme; the Chaos Gate widget switches between them with the KDE color scheme.
"""
import os
import sys

OUT = sys.argv[1]

PAD = 14          # shadow
BORDER = 4        # side / bottom frame
TITLE_EDGE_TOP = 5
TITLE_H = 22
TITLE_EDGE_BOTTOM = 5
TOP = TITLE_EDGE_TOP + TITLE_H + TITLE_EDGE_BOTTOM   # title band height
MAX_EDGE = 3
MAX_TOP = MAX_EDGE + TITLE_H + MAX_EDGE
BTN = 22
STRETCH = 8       # width / height of the stretchable middle pieces

THEMES = {
    "helba-world": dict(
        name="Helba World",
        glass_top="#141c3e", glass_bottom="#0b1226", glass_op=0.98,
        gold="#b8935a", cyan="#8fe3ff", crit="#ff3864", ink="#1a1408",
        shadow="#000000", shadow_op=0.5,
        text="234,240,251", text_inactive="141,152,182",
        inactive_glass_top="#0e1530", inactive_glass_bottom="#080d1e",
    ),
    "helba-world-light": dict(
        name="Helba World Light",
        glass_top="#fbf8f0", glass_bottom="#efe9da", glass_op=0.99,
        gold="#8a6418", cyan="#14708a", crit="#c81e45", ink="#fbf6e8",
        shadow="#2a2410", shadow_op=0.28,
        text="26,32,51", text_inactive="90,99,128",
        inactive_glass_top="#f3eee1", inactive_glass_bottom="#ebe4d2",
    ),
}


def rect(x, y, w, h, fill, op=1.0, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" fill-opacity="{op}"{extra}/>'


def bounds(x, y, w, h):
    return rect(x, y, w, h, "#000", 0)


def g(id_, inner):
    return f'<g id="{id_}">{inner}</g>'


class Doc:
    def __init__(self):
        self.defs, self.parts, self.y = [], [], 0
        self.n = 0

    def grad(self, kind, stops, **attrs):
        self.n += 1
        gid = f"g{self.n}"
        a = " ".join(f'{k}="{v}"' for k, v in attrs.items())
        s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
        self.defs.append(f'<{kind} id="{gid}" {a}>{s}</{kind}>')
        return f"url(#{gid})"

    def row(self, h):
        y = self.y
        self.y += h + 8
        return y

    def write(self, path, width=200):
        with open(path, "w") as f:
            f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{self.y + 4}">\n')
            f.write("<defs>" + "".join(self.defs) + "</defs>\n")
            f.write("\n".join(self.parts) + "\n</svg>\n")


# --------------------------------------------------------------------- frame

def shadow_linear(d, x, y, w, h, direction, t):
    """A shadow strip fading away from the frame. direction: the way it fades."""
    vec = {"up": ("0", "1", "0", "0"), "down": ("0", "0", "0", "1"),
           "left": ("1", "0", "0", "0"), "right": ("0", "0", "1", "0")}[direction]
    fill = d.grad("linearGradient", [(0, t["shadow"], t["shadow_op"]), (1, t["shadow"], 0)],
                  x1=vec[0], y1=vec[1], x2=vec[2], y2=vec[3])
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}"/>'


def shadow_corner(d, cx, cy, x, y, t):
    fill = d.grad("radialGradient", [(0, t["shadow"], t["shadow_op"]), (1, t["shadow"], 0)],
                  cx=cx, cy=cy, r=PAD, gradientUnits="userSpaceOnUse")
    return f'<rect x="{x}" y="{y}" width="{PAD}" height="{PAD}" fill="{fill}"/>'


def stud(cx, cy, s, fill, hollow=False):
    pts = f"{cx},{cy - s} {cx + s},{cy} {cx},{cy + s} {cx - s},{cy}"
    if hollow:
        return f'<polygon points="{pts}" fill="none" stroke="{fill}" stroke-width="1"/>'
    return f'<polygon points="{pts}" fill="{fill}"/>'


def frame(d, prefix, t, active):
    """Nine pieces of a normal (non-maximized) frame, shadow included."""
    W = PAD + BORDER          # left / right / bottom piece thickness
    H = PAD + TOP             # top piece height
    gold_op = 0.85 if active else 0.35
    seam_op = 0.6 if active else 0.25
    gt, gb = (t["glass_top"], t["glass_bottom"]) if active else (t["inactive_glass_top"], t["inactive_glass_bottom"])
    title = d.grad("linearGradient", [(0, gt, t["glass_op"]), (1, gb, t["glass_op"])], x1="0", y1="0", x2="0", y2="1")
    glass = gb
    y0 = d.row(H + STRETCH + W)
    cols = [(0, W), (W, STRETCH), (W + STRETCH, W)]
    rows = [(0, H), (H, STRETCH), (H + STRETCH, W)]
    gold = t["gold"]
    for name, (ci, ri) in {
        "topleft": (0, 0), "top": (1, 0), "topright": (2, 0),
        "left": (0, 1), "center": (1, 1), "right": (2, 1),
        "bottomleft": (0, 2), "bottom": (1, 2), "bottomright": (2, 2),
    }.items():
        x, w = cols[ci]
        yy, h = rows[ri]
        y = y0 + yy
        out = [bounds(x, y, w, h)]
        if name == "center":
            out.append(rect(x, y, w, h, glass, t["glass_op"]))
        if name == "top":
            out.append(shadow_linear(d, x, y, w, PAD, "up", t))
            out.append(f'<rect x="{x}" y="{y + PAD}" width="{w}" height="{TOP}" fill="{title}"/>')
            out.append(rect(x, y + PAD, w, 1, gold, gold_op))
            out.append(rect(x, y + PAD + 3, w, 1, gold, gold_op * 0.25))
            out.append(rect(x, y + H - 1, w, 1, gold, seam_op))
        if name == "bottom":
            out.append(rect(x, y, w, BORDER, glass, t["glass_op"]))
            out.append(rect(x, y + BORDER - 1, w, 1, gold, gold_op * 0.7))
            out.append(shadow_linear(d, x, y + BORDER, w, PAD, "down", t))
        if name in ("left", "right"):
            left = name == "left"
            fx = x + PAD if left else x
            out.append(rect(fx, y, BORDER, h, glass, t["glass_op"]))
            out.append(rect(fx if left else fx + BORDER - 1, y, 1, h, gold, gold_op * 0.7))
            out.append(shadow_linear(d, x if left else x + BORDER, y, PAD, h, "left" if left else "right", t))
        if name in ("topleft", "topright"):
            left = name == "topleft"
            fx = x + PAD if left else x            # frame column inside the piece
            sx = x if left else x + BORDER         # shadow column
            out.append(shadow_corner(d, x + PAD if left else x + BORDER, y + PAD, sx, y, t))
            out.append(shadow_linear(d, sx, y + PAD, PAD, TOP, "left" if left else "right", t))
            out.append(shadow_linear(d, fx, y, BORDER, PAD, "up", t))
            out.append(f'<rect x="{fx}" y="{y + PAD}" width="{BORDER}" height="{TOP}" fill="{title}"/>')
            out.append(rect(fx, y + PAD, BORDER, 1, gold, gold_op))
            out.append(rect(fx if left else fx + BORDER - 1, y + PAD, 1, TOP, gold, gold_op))
            out.append(rect(fx, y + H - 1, BORDER, 1, gold, seam_op))
            cx = fx if left else fx + BORDER
            out.append(stud(cx, y + PAD, 3.5, gold, hollow=not active))
        if name in ("bottomleft", "bottomright"):
            left = name == "bottomleft"
            fx = x + PAD if left else x
            sx = x if left else x + BORDER
            out.append(rect(fx, y, BORDER, BORDER, glass, t["glass_op"]))
            out.append(rect(fx, y + BORDER - 1, BORDER, 1, gold, gold_op * 0.7))
            out.append(rect(fx if left else fx + BORDER - 1, y, 1, BORDER, gold, gold_op * 0.7))
            out.append(shadow_linear(d, sx, y, PAD, BORDER, "left" if left else "right", t))
            out.append(shadow_linear(d, fx, y + BORDER, BORDER, PAD, "down", t))
            out.append(shadow_corner(d, x + PAD if left else x + BORDER, y + BORDER, sx, y + BORDER, t))
            cx = fx if left else fx + BORDER
            out.append(stud(cx, y + BORDER, 2.5, gold, hollow=not active))
        d.parts.append(g(f"{prefix}-{name}", "".join(out)))


def maximized(d, prefix, t, active):
    """Maximized windows: just the title band, no borders or shadow (center only)."""
    gt, gb = (t["glass_top"], t["glass_bottom"]) if active else (t["inactive_glass_top"], t["inactive_glass_bottom"])
    title = d.grad("linearGradient", [(0, gt, t["glass_op"]), (1, gb, t["glass_op"])], x1="0", y1="0", x2="0", y2="1")
    y = d.row(MAX_TOP)
    out = [bounds(0, y, 40, MAX_TOP), f'<rect x="0" y="{y}" width="40" height="{MAX_TOP}" fill="{title}"/>',
           rect(0, y + MAX_TOP - 1, 40, 1, t["gold"], 0.6 if active else 0.25)]
    d.parts.append(g(f"{prefix}-center", "".join(out)))


def decoration(t, path):
    d = Doc()
    frame(d, "decoration", t, True)
    frame(d, "decoration-inactive", t, False)
    maximized(d, "decoration-maximized", t, True)
    maximized(d, "decoration-maximized-inactive", t, False)
    d.write(path)


# --------------------------------------------------------------------- buttons

def glyph(kind, c, s, color, sw=1.4):
    """The mark inside a button diamond, centered at c with half-size s."""
    x, y = c
    line = lambda x1, y1, x2, y2: f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}" stroke-linecap="round"/>'
    if kind == "close":
        return line(x - s, y - s, x + s, y + s) + line(x - s, y + s, x + s, y - s)
    if kind == "minimize":
        return line(x - s, y + s * 0.6, x + s, y + s * 0.6)
    if kind == "maximize":
        return f'<rect x="{x - s}" y="{y - s}" width="{2 * s}" height="{2 * s}" fill="none" stroke="{color}" stroke-width="{sw}"/>'
    if kind == "restore":
        o = s * 0.45
        return (f'<rect x="{x - s}" y="{y - s + o}" width="{2 * s - o}" height="{2 * s - o}" fill="none" stroke="{color}" stroke-width="{sw}"/>'
                f'<polyline points="{x - s + o},{y - s + o} {x - s + o},{y - s} {x + s},{y - s} {x + s},{y + s - o} {x + s - o},{y + s - o}" fill="none" stroke="{color}" stroke-width="{sw}"/>')
    if kind == "alldesktops":
        return f'<circle cx="{x}" cy="{y}" r="{s * 0.55}" fill="{color}"/>'
    if kind == "keepabove":
        return f'<polyline points="{x - s},{y + s * 0.4} {x},{y - s * 0.5} {x + s},{y + s * 0.4}" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round"/>'
    if kind == "keepbelow":
        return f'<polyline points="{x - s},{y - s * 0.4} {x},{y + s * 0.5} {x + s},{y - s * 0.4}" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round"/>'
    if kind == "shade":
        return line(x - s, y - s * 0.6, x + s, y - s * 0.6) + line(x - s * 0.6, y, x + s * 0.6, y)
    if kind == "help":
        return f'<text x="{x}" y="{y + s * 0.85}" text-anchor="middle" font-family="Noto Serif" font-size="{s * 2.6}" fill="{color}">?</text>'
    raise ValueError(kind)


def button(kind, t, path):
    d = Doc()
    c = BTN / 2
    gold, cyan = t["gold"], t["cyan"]
    hot = t["crit"] if kind == "close" else cyan
    # state -> (diamond fill, fill opacity, stroke, stroke opacity, glyph color)
    states = {
        "active": ("none", 0, gold, 0.9, gold),
        "hover": (hot, 0.22, hot, 1.0, hot),
        "pressed": (hot, 0.45, hot, 1.0, t["ink"]),
        "deactivated": ("none", 0, gold, 0.25, gold),
        "inactive": ("none", 0, gold, 0.35, gold),
        "hover-inactive": (hot, 0.15, hot, 0.8, hot),
        "pressed-inactive": (hot, 0.35, hot, 0.9, t["ink"]),
        "deactivated-inactive": ("none", 0, gold, 0.15, gold),
    }
    for state, (fill, fop, stroke, sop, gcol) in states.items():
        y = d.row(BTN)
        r = BTN / 2 - 2
        pts = f"{c},{y + c - r} {c + r},{y + c} {c},{y + c + r} {c - r},{y + c}"
        dim = 0.45 if state.startswith("deactivated") else (0.6 if state == "inactive" else 1.0)
        inner = (bounds(0, y, BTN, BTN)
                 + f'<polygon points="{pts}" fill="{fill if fill != "none" else "#000"}" fill-opacity="{fop}" '
                   f'stroke="{stroke}" stroke-opacity="{sop}" stroke-width="1.2"/>'
                 + f'<g opacity="{dim}">{glyph(kind, (c, y + c), 3.6, gcol)}</g>')
        d.parts.append(g(f"{state}-center", inner))
    d.write(path, width=BTN + 4)


# --------------------------------------------------------------------- package

def rc(t):
    return f"""[General]
ActiveTextColor={t["text"]}
InactiveTextColor={t["text_inactive"]}
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=120
UseTextShadow=false
Shadow=false

[Layout]
PaddingTop={PAD}
PaddingBottom={PAD}
PaddingLeft={PAD}
PaddingRight={PAD}
BorderLeft={BORDER}
BorderRight={BORDER}
BorderBottom={BORDER}
TitleEdgeTop={TITLE_EDGE_TOP}
TitleEdgeBottom={TITLE_EDGE_BOTTOM}
TitleEdgeLeft=10
TitleEdgeRight=10
TitleEdgeTopMaximized={MAX_EDGE}
TitleEdgeBottomMaximized={MAX_EDGE}
TitleEdgeLeftMaximized=8
TitleEdgeRightMaximized=8
TitleBorderLeft=10
TitleBorderRight=10
TitleHeight={TITLE_H}
ButtonWidth={BTN}
ButtonHeight={BTN}
ButtonSpacing=6
ButtonMarginTop=0
ButtonMarginTopMaximized=0
ExplicitButtonSpacer=10
"""


def metadata(theme, t):
    return f"""[Desktop Entry]
Name={t["name"]}
Comment=.hack (The World) window frame: glass title band, gold trim, diamond buttons
X-KDE-PluginInfo-Author=helba
X-KDE-PluginInfo-Email=ai@helba.ai
X-KDE-PluginInfo-Name={theme}
X-KDE-PluginInfo-Version=1.0.0
X-KDE-PluginInfo-License=MIT
X-KDE-PluginInfo-EnabledByDefault=true
"""


for theme, t in THEMES.items():
    root = os.path.join(OUT, theme)
    os.makedirs(root, exist_ok=True)
    decoration(t, os.path.join(root, "decoration.svg"))
    for kind in ["close", "minimize", "maximize", "restore", "alldesktops", "keepabove", "keepbelow", "shade", "help"]:
        button(kind, t, os.path.join(root, f"{kind}.svg"))
    with open(os.path.join(root, f"{theme}rc"), "w") as f:
        f.write(rc(t))
    with open(os.path.join(root, "metadata.desktop"), "w") as f:
        f.write(metadata(theme, t))
print("aurorae themes written to", OUT)
