#!/usr/bin/env python3
"""Generate the .hack (The World) Plasma desktop theme SVGs for packages/helba-hud.

    python3 dev/theme_gen.py packages/helba-hud

Every frame piece is a <g id=...> whose first child is a transparent rect giving the
exact piece bounds (KSvg measures elements by their bounding box). Corners are drawn
once in top-left orientation and mirrored.

Colors are not baked in: each palette color is written as a KDE ColorScheme class, so
Plasma repaints the frames from the active color scheme (Helba World dark or light, or
whatever scheme is chosen). The values below are only the stylesheet defaults.
"""
import os
import re
import sys

GOLD = "#b8935a"
CYAN = "#8fe3ff"
GLASS = "#0b1226"
GLASS_TOP = "#141c3e"
FIELD = "#070c1c"

OUT = sys.argv[1]

# palette color -> KDE color scheme role (Helba World: DecorationFocus is the gold trim,
# DecorationHover the data cyan, then window / button / view backgrounds).
ROLES = {
    GOLD: "ButtonFocus",
    CYAN: "ButtonHover",
    GLASS: "Background",
    GLASS_TOP: "ButtonBackground",
    FIELD: "ViewBackground",
}
STYLE = ('<style type="text/css" id="current-color-scheme">'
         + "".join(f".ColorScheme-{role}{{color:{color};}}" for color, role in ROLES.items())
         + "</style>")
PAINT = re.compile(r'(fill|stroke)="(#[0-9a-fA-F]{6})"')


def recolor(svg):
    """fill="#b8935a" -> class="ColorScheme-ButtonFocus" style="fill:currentColor"."""
    def element(m):
        tag = m.group(0)
        hits = [(a, c) for a, c in PAINT.findall(tag) if c.lower() in ROLES]
        if not hits:
            return tag
        assert len(hits) == 1, f"two scheme colors on one element: {tag}"
        attr, color = hits[0]
        return tag.replace(f'{attr}="{color}"', f'class="ColorScheme-{ROLES[color.lower()]}" style="{attr}:currentColor"')
    return re.sub(r"<(path|rect|polygon)\b[^>]*>", element, svg)


class Svg:
    def __init__(self):
        self.parts = []
        self.y = 0  # next free row

    def add(self, s):
        self.parts.append(s)

    def row(self, h):
        y = self.y
        self.y += h + 6
        return y

    def write(self, rel):
        path = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        w = 400
        with open(path, "w") as f:
            f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{self.y + 4}">\n')
            f.write(f"<defs>{STYLE}</defs>\n")
            f.write(recolor("\n".join(self.parts)))
            f.write("\n</svg>\n")


def bounds(x, y, w, h):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>'


def g(id_, inner):
    return f'<g id="{id_}">{inner}</g>'


def rect(id_, x, y, w, h):
    return f'<rect id="{id_}" x="{x}" y="{y}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>'


# --------------------------------------------------------------- frame pieces

PIECES = ["topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright"]


def frame(svg, prefix, c, e, style, x0=0, center=None):
    """Emit the nine pieces of a frame with corner size c and edge/center size e."""
    y0 = svg.row(2 * c + (center or e))
    ce = center or e
    cols = [(0, c), (c, e), (c + e, c)]
    rows = [(0, c), (c, ce), (c + ce, c)]
    for i, name in enumerate(PIECES):
        cx, cw = cols[i % 3]
        ry, rh = rows[i // 3]
        x, y = x0 + cx, y0 + ry
        id_ = f"{prefix}-{name}" if prefix else name
        svg.add(g(id_, bounds(x, y, cw, rh) + style(name, x, y, cw, rh, c)))


def corner_path(cmds, x, y, c, fx, fy):
    """Map canonical top-left corner commands (local coords) to a flipped corner at (x, y)."""
    out = []
    sweep_flip = fx != fy
    for cmd in cmds:
        op = cmd[0]
        if op in "ML":
            px, py = cmd[1], cmd[2]
            px = c - px if fx else px
            py = c - py if fy else py
            out.append(f"{op}{x + px:.2f},{y + py:.2f}")
        elif op == "A":
            r, px, py, sweep = cmd[1], cmd[2], cmd[3], cmd[4]
            px = c - px if fx else px
            py = c - py if fy else py
            sw = (1 - sweep) if sweep_flip else sweep
            out.append(f"A{r:.2f},{r:.2f} 0 0 {sw} {x + px:.2f},{y + py:.2f}")
        elif op == "Z":
            out.append("Z")
    return " ".join(out)


def flips(name):
    return ("right" in name, "bottom" in name)


def bordered(fill, fill_op, border=None, border_op=1.0, bw=1.0, r=4, echo_op=0.0, stud=False):
    """Rounded glass frame: fill, outer rule, optional inner echo line and corner studs."""

    def style(name, x, y, w, h, c):
        out = []
        h2 = bw / 2
        if name in ("topleft", "topright", "bottomleft", "bottomright"):
            fx, fy = flips(name)
            fillp = corner_path([("M", r, 0), ("L", c, 0), ("L", c, c), ("L", 0, c), ("L", 0, r), ("A", r, r, 0, 1), ("Z",)], x, y, c, fx, fy)
            out.append(f'<path d="{fillp}" fill="{fill}" fill-opacity="{fill_op}"/>')
            if border:
                bp = corner_path([("M", h2, c), ("L", h2, r), ("A", r - h2, r, h2, 1), ("L", c, h2)], x, y, c, fx, fy)
                out.append(f'<path d="{bp}" fill="none" stroke="{border}" stroke-opacity="{border_op}" stroke-width="{bw}"/>')
            if echo_op:
                d = 3.5
                ep = corner_path([("M", d, c), ("L", d, d), ("L", c, d)], x, y, c, fx, fy)
                out.append(f'<path d="{ep}" fill="none" stroke="{border}" stroke-opacity="{echo_op}" stroke-width="1"/>')
            if stud:
                s = 3.0
                cx0, cy0 = 4.5, 4.5
                pts = [(cx0, cy0 - s), (cx0 + s, cy0), (cx0, cy0 + s), (cx0 - s, cy0)]
                mapped = []
                for px, py in pts:
                    px = c - px if fx else px
                    py = c - py if fy else py
                    mapped.append(f"{x + px:.2f},{y + py:.2f}")
                out.append(f'<polygon points="{" ".join(mapped)}" fill="{GOLD}"/>')
        else:
            out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" fill-opacity="{fill_op}"/>')
            if border and name != "center":
                if name == "top":
                    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{bw}" fill="{border}" fill-opacity="{border_op}"/>')
                    if echo_op:
                        out.append(f'<rect x="{x}" y="{y + 3}" width="{w}" height="1" fill="{border}" fill-opacity="{echo_op}"/>')
                if name == "bottom":
                    out.append(f'<rect x="{x}" y="{y + h - bw}" width="{w}" height="{bw}" fill="{border}" fill-opacity="{border_op}"/>')
                    if echo_op:
                        out.append(f'<rect x="{x}" y="{y + h - 4}" width="{w}" height="1" fill="{border}" fill-opacity="{echo_op}"/>')
                if name == "left":
                    out.append(f'<rect x="{x}" y="{y}" width="{bw}" height="{h}" fill="{border}" fill-opacity="{border_op}"/>')
                    if echo_op:
                        out.append(f'<rect x="{x + 3}" y="{y}" width="1" height="{h}" fill="{border}" fill-opacity="{echo_op}"/>')
                if name == "right":
                    out.append(f'<rect x="{x + w - bw}" y="{y}" width="{bw}" height="{h}" fill="{border}" fill-opacity="{border_op}"/>')
                    if echo_op:
                        out.append(f'<rect x="{x + w - 4}" y="{y}" width="1" height="{h}" fill="{border}" fill-opacity="{echo_op}"/>')
        return "".join(out)

    return style


def empty(name, x, y, w, h, c):
    return ""


def outline(color, op=1.0, bw=1.0, r=4):
    return bordered("#000", 0, border=color, border_op=op, bw=bw, r=r)


def margins(svg, prefix, size):
    y = svg.row(size)
    x = 0
    for side in ["top", "bottom", "left", "right"]:
        id_ = f"{prefix}-hint-{side}-margin" if prefix else f"hint-{side}-margin"
        svg.add(rect(id_, x, y, size, size))
        x += size + 4


def diamond(id_, x, y, size, fill=None, stroke=None, inner=None, sw=1.5):
    c = size / 2
    pts = f"{x + c},{y + 1} {x + size - 1},{y + c} {x + c},{y + size - 1} {x + 1},{y + c}"
    s = bounds(x, y, size, size)
    s += f'<polygon points="{pts}" fill="{fill or "none"}"' + (f' stroke="{stroke}" stroke-width="{sw}"' if stroke else "") + "/>"
    if inner:
        q = size * 0.22
        ipts = f"{x + c},{y + c - q} {x + c + q},{y + c} {x + c},{y + c + q} {x + c - q},{y + c}"
        s += f'<polygon points="{ipts}" fill="{inner}"/>'
    return g(id_, s)


# --------------------------------------------------------------- dialogs/background

def dialog(rel, c, margin):
    svg = Svg()
    frame(svg, "", c, 8, bordered(GLASS, 0.97, border=GOLD, border_op=0.8, r=6, echo_op=0.22, stud=True))
    frame(svg, "mask", c, 8, bordered("#000", 1.0, r=6))
    margins(svg, "", margin)
    svg.write(rel)


dialog("dialogs/background.svg", 12, 10)
dialog("widgets/tooltip.svg", 10, 8)

# --------------------------------------------------------------- popup headings

svg = Svg()


def heading(line_side):
    def style(name, x, y, w, h, c):
        if line_side == "bottom" and name in ("bottomleft", "bottom", "bottomright"):
            op = 0.5 if name == "bottom" else 0.25
            return f'<rect x="{x}" y="{y + h - 1}" width="{w}" height="1" fill="{GOLD}" fill-opacity="{op}"/>'
        if line_side == "top" and name in ("topleft", "top", "topright"):
            op = 0.5 if name == "top" else 0.25
            return f'<rect x="{x}" y="{y}" width="{w}" height="1" fill="{GOLD}" fill-opacity="{op}"/>'
        return ""
    return style


frame(svg, "header", 6, 6, heading("bottom"))
frame(svg, "footer", 6, 6, heading("top"))
margins(svg, "", 6)
y = svg.row(4)
svg.add(rect("hint-stretch-borders", 0, y, 4, 4))
svg.write("widgets/plasmoidheading.svg")

# --------------------------------------------------------------- list items


def wash(op, brackets):
    def style(name, x, y, w, h, c):
        out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{CYAN}" fill-opacity="{op}"/>']
        if brackets:
            t = 1.5
            if name in ("topleft", "left", "bottomleft"):
                out.append(f'<rect x="{x}" y="{y}" width="{t}" height="{h}" fill="{GOLD}"/>')
            if name in ("topright", "right", "bottomright"):
                out.append(f'<rect x="{x + w - t}" y="{y}" width="{t}" height="{h}" fill="{GOLD}"/>')
            if name in ("topleft", "topright"):
                out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{t}" fill="{GOLD}"/>')
            if name in ("bottomleft", "bottomright"):
                out.append(f'<rect x="{x}" y="{y + h - t}" width="{w}" height="{t}" fill="{GOLD}"/>')
        return "".join(out)
    return style


for rel in ["widgets/viewitem.svg", "widgets/listitem.svg"]:
    svg = Svg()
    frame(svg, "normal", 6, 6, empty)
    frame(svg, "hover", 6, 6, wash(0.10, False))
    frame(svg, "selected", 6, 6, wash(0.16, True))
    frame(svg, "selected+hover", 6, 6, wash(0.24, True))
    frame(svg, "pressed", 6, 6, wash(0.24, True))
    frame(svg, "section", 6, 6, heading("bottom"))
    for p in ["normal", "pressed", "section"]:
        margins(svg, p, 4)
    svg.write(rel)

# --------------------------------------------------------------- slider

svg = Svg()
frame(svg, "groove", 2, 2, bordered(GOLD, 0.25, r=2))
frame(svg, "groove-highlight", 2, 2, bordered(CYAN, 0.9, r=2))
y = svg.row(20)
svg.add(diamond("horizontal-slider-handle", 0, y, 20, fill=GOLD, inner=GLASS))
svg.add(diamond("horizontal-slider-hover", 24, y, 20, stroke=CYAN))
svg.add(diamond("horizontal-slider-focus", 48, y, 20, stroke=CYAN, sw=2))
svg.add(g("horizontal-slider-shadow", bounds(72, y, 20, 20)))
svg.add(diamond("vertical-slider-handle", 96, y, 20, fill=GOLD, inner=GLASS))
svg.add(diamond("vertical-slider-hover", 120, y, 20, stroke=CYAN))
svg.add(diamond("vertical-slider-focus", 144, y, 20, stroke=CYAN, sw=2))
svg.add(g("vertical-slider-shadow", bounds(168, y, 20, 20)))
svg.add(rect("hint-handle-size", 192, y, 20, 20))
svg.write("widgets/slider.svg")

# --------------------------------------------------------------- switch

svg = Svg()
y = svg.row(14)


def track(prefix, fill, fill_op, border, x0):
    # left cap, stretchable center, right cap; 14px tall.
    h, cap = 14, 7
    left = (f'<path d="M{x0 + cap},{y} A{cap},{cap} 0 0 0 {x0 + cap},{y + h} Z" fill="{fill}" fill-opacity="{fill_op}"/>'
            f'<path d="M{x0 + cap},{y + 0.5} A{cap - 0.5},{cap - 0.5} 0 0 0 {x0 + cap},{y + h - 0.5}" fill="none" stroke="{border}" stroke-width="1"/>')
    svg.add(g(f"{prefix}-left", bounds(x0, y, cap, h) + left))
    cx = x0 + cap
    center = (f'<rect x="{cx}" y="{y}" width="8" height="{h}" fill="{fill}" fill-opacity="{fill_op}"/>'
              f'<rect x="{cx}" y="{y}" width="8" height="1" fill="{border}"/><rect x="{cx}" y="{y + h - 1}" width="8" height="1" fill="{border}"/>')
    svg.add(g(f"{prefix}-center", bounds(cx, y, 8, h) + center))
    rx = cx + 8
    right = (f'<path d="M{rx},{y} A{cap},{cap} 0 0 1 {rx},{y + h} Z" fill="{fill}" fill-opacity="{fill_op}"/>'
             f'<path d="M{rx},{y + 0.5} A{cap - 0.5},{cap - 0.5} 0 0 1 {rx},{y + h - 0.5}" fill="none" stroke="{border}" stroke-width="1"/>')
    svg.add(g(f"{prefix}-right", bounds(rx, y, cap, h) + right))


track("inactive", FIELD, 0.95, GOLD + '" stroke-opacity="0.45', 0)
track("active", CYAN, 0.5, CYAN, 40)
y2 = svg.row(18)
svg.add(diamond("handle", 0, y2, 18, fill=GOLD, inner=GLASS))
svg.add(diamond("handle-hover", 22, y2, 18, stroke=CYAN))
svg.add(diamond("handle-focus", 44, y2, 18, stroke=CYAN, sw=2))
svg.add(diamond("handle-pressed", 66, y2, 18, fill=CYAN, inner=GLASS))
svg.add(g("handle-shadow", bounds(88, y2, 18, 18)))
y3 = svg.row(14)
svg.add(rect("hint-bar-size", 0, y3, 36, 14))
svg.add(rect("hint-stretch-borders", 40, y3, 4, 4))
svg.write("widgets/switch.svg")

# --------------------------------------------------------------- buttons

svg = Svg()
frame(svg, "normal", 5, 6, bordered(GLASS_TOP, 0.95, border=GOLD, border_op=0.45, r=3))
frame(svg, "mask-normal", 5, 6, bordered("#000", 1.0, r=3))
frame(svg, "hover", 5, 6, outline(CYAN, 0.9, r=3))
frame(svg, "focus", 5, 6, outline(GOLD, 1.0, bw=1.5, r=3))
frame(svg, "pressed", 5, 6, bordered(CYAN, 0.2, border=CYAN, border_op=0.9, r=3))
frame(svg, "toolbutton-hover", 5, 6, bordered(CYAN, 0.08, border=CYAN, border_op=0.6, r=3))
frame(svg, "toolbutton-focus", 5, 6, outline(GOLD, 0.9, r=3))
frame(svg, "toolbutton-pressed", 5, 6, bordered(CYAN, 0.2, border=CYAN, border_op=0.9, r=3))
for p in ["normal", "hover", "focus", "pressed", "toolbutton-hover", "toolbutton-focus", "toolbutton-pressed"]:
    margins(svg, p, 6)
svg.write("widgets/button.svg")

# --------------------------------------------------------------- text fields

svg = Svg()
frame(svg, "base", 5, 6, bordered(FIELD, 0.95, border=GOLD, border_op=0.35, r=3))
frame(svg, "hover", 5, 6, outline(CYAN, 0.6, r=3))
frame(svg, "focus", 5, 6, outline(GOLD, 1.0, bw=1.5, r=3))
frame(svg, "focusframe", 5, 6, outline(GOLD, 1.0, bw=1.5, r=3))
for p in ["base", "hover", "focus", "focusframe"]:
    margins(svg, p, 6)
y = svg.row(4)
svg.add(rect("hint-focus-over-base", 0, y, 4, 4))
svg.write("widgets/lineedit.svg")

# --------------------------------------------------------------- scrollbar

svg = Svg()
frame(svg, "slider", 3, 2, bordered(GOLD, 0.5, r=3))
frame(svg, "mouseover-slider", 3, 2, bordered(CYAN, 0.85, r=3))
frame(svg, "background-vertical", 3, 2, empty)
frame(svg, "background-horizontal", 3, 2, empty)
y = svg.row(8)
svg.add(rect("hint-scrollbar-size", 0, y, 8, 8))
svg.write("widgets/scrollbar.svg")

print("theme svgs written to", OUT)
