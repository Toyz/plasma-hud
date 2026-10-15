#!/usr/bin/env python3
"""Generate the Helba World Kvantum themes (dark and light) into packages/kvantum/.

    python3 dev/kvantum_gen.py packages/kvantum

Kvantum styles every Qt widget, so the flat KvFlat / KvFlatLight themes are the base:
their neutral grays are mapped onto the Helba glass (navy, or parchment for light) at
the same lightness and their Breeze blue onto the data cyan (teal for light). Menus,
menu items and tooltips get their own .hack pieces: glass, gold edge with an inner
echo, diamond studs at the corners, and the cyan wash with gold brackets for the
hovered item, like Root Town and the Chaos Gate.
"""
import colorsys
import os
import re
import sys

OUT = sys.argv[1]
SRC = "/usr/share/Kvantum"


def hx(c):
    c = c.lstrip("#")
    if len(c) == 3:
        c = "".join(ch * 2 for ch in c)
    return tuple(int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))


def tohex(r, g, b):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255))) for v in (r, g, b))


def hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h / 360, l, s)
    return tohex(r, g, b)


def recolor_dark(c):
    r, g, b = hx(c)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.15:
        if l <= 0.5:   # surfaces and borders -> navy glass
            return hsl(228, 0.5 if l < 0.3 else 0.3, l * 0.55 + 0.02)
        return hsl(220, 0.35, l)   # light glyphs -> ink
    if 180 <= h * 360 <= 235:   # Breeze blues -> data cyan
        return hsl(193, min(1, s), min(0.78, l + 0.12))
    return c


def recolor_light(c):
    r, g, b = hx(c)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.15:
        if l > 0.55:   # surfaces -> parchment
            return hsl(43, 0.45, min(0.97, l * 0.98))
        return hsl(225, 0.25, l * 0.9)   # text and borders -> navy ink
    if 180 <= h * 360 <= 235:   # blues -> deep teal
        return hsl(193, 0.75, l * 0.75)
    return c


HEX = re.compile(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")

THEMES = {
    "HelbaWorld": dict(
        base="KvFlat", recolor=recolor_dark,
        glass="#0b1226", glass_top="#141c3e", gold="#b8935a", cyan="#8fe3ff", ink="#eaf0fb",
        colors={
            "window.color": "#0b1126", "base.color": "#080d1e", "alt.base.color": "#0b1126",
            "button.color": "#141c3e", "light.color": "#1c2650", "mid.light.color": "#141c3e",
            "dark.color": "#04070f", "mid.color": "#0e1530", "highlight.color": "#8fe3ff",
            "inactive.highlight.color": "#5a9ab5", "text.color": "#eaf0fb", "window.text.color": "#eaf0fb",
            "button.text.color": "#eaf0fb", "disabled.text.color": "#5d6684", "tooltip.text.color": "#eaf0fb",
            "highlight.text.color": "#0a1022", "link.color": "#b8935a", "link.visited.color": "#c4aa6e",
        },
    ),
    "HelbaWorldLight": dict(
        base="KvFlatLight", recolor=recolor_light,
        glass="#f3eee1", glass_top="#fbf8f0", gold="#8a6418", cyan="#14708a", ink="#1a2033",
        colors={
            "window.color": "#f3eee1", "base.color": "#faf7ee", "alt.base.color": "#f3eee1",
            "button.color": "#ece5d4", "light.color": "#fbf8f0", "mid.light.color": "#ece5d4",
            "dark.color": "#b9ad90", "mid.color": "#d9d0b8", "highlight.color": "#14708a",
            "inactive.highlight.color": "#5f98a8", "text.color": "#1a2033", "window.text.color": "#1a2033",
            "button.text.color": "#1a2033", "disabled.text.color": "#9a9fae", "tooltip.text.color": "#1a2033",
            "highlight.text.color": "#faf7ee", "link.color": "#8a6418", "link.visited.color": "#6e5428",
        },
    ),
}

# ------------------------------------------------------------------ .hack pieces

F = 6        # menu / tooltip frame thickness
FI = 3       # menu item frame thickness
C = 12       # stretchable middle size


class Pieces:
    def __init__(self, y0):
        self.parts, self.y = [], y0

    def row(self, h):
        y = self.y
        self.y += h + 6
        return y

    def add(self, id_, x, y, w, h, inner):
        self.parts.append(f'<g id="{id_}"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>{inner}</g>')


def rect(x, y, w, h, fill, op=1.0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" fill-opacity="{op}"/>'


def nine(p, name, f, center, draw, zero=False):
    """Emit name-topleft .. name-bottomright plus the bare interior `name` (and, with
    zero, the -top0 style copies some Kvantum frames are also looked up by)."""
    y0 = p.row(2 * f + center)
    cols = [(0, f), (f, center), (f + center, f)]
    rows = [(0, f), (f, center), (f + center, f)]
    names = [["topleft", "top", "topright"], ["left", None, "right"], ["bottomleft", "bottom", "bottomright"]]
    for ri, (ry, rh) in enumerate(rows):
        for ci, (cx, cw) in enumerate(cols):
            part = names[ri][ci]
            id_ = name if part is None else f"{name}-{part}"
            p.add(id_, cx, y0 + ry, cw, rh, draw(part, cx, y0 + ry, cw, rh))
            if zero and part is not None:
                p.add(id_ + "0", cx, y0 + ry, cw, rh, draw(part, cx, y0 + ry, cw, rh))


def glass_frame(t, f, stud=True):
    gold, glass = t["gold"], t["glass"]

    def draw(part, x, y, w, h):
        out = [rect(x, y, w, h, glass, 0.98)]
        if part is None:
            return "".join(out)
        if "top" in part:
            out.append(rect(x, y, w, 1, gold, 0.85))
            if f > 3:
                out.append(rect(x, y + 3, w, 1, gold, 0.2))
        if "bottom" in part:
            out.append(rect(x, y + h - 1, w, 1, gold, 0.85))
            if f > 3:
                out.append(rect(x, y + h - 4, w, 1, gold, 0.2))
        if "left" in part:
            out.append(rect(x, y, 1, h, gold, 0.85))
            if f > 3:
                out.append(rect(x + 3, y, 1, h, gold, 0.2))
        if "right" in part:
            out.append(rect(x + w - 1, y, 1, h, gold, 0.85))
            if f > 3:
                out.append(rect(x + w - 4, y, 1, h, gold, 0.2))
        if stud and part in ("topleft", "topright", "bottomleft", "bottomright"):
            # Inside the piece: Kvantum scales pieces by their bounds, overhang skews them.
            s = 2.6
            cx = x + (s if "left" in part else w - s)
            cy = y + (s if "top" in part else h - s)
            out.append(f'<polygon points="{cx},{cy - s} {cx + s},{cy} {cx},{cy + s} {cx - s},{cy}" fill="{gold}"/>')
        return "".join(out)
    return draw


def item_frame(t, wash, brackets):
    gold, cyan = t["gold"], t["cyan"]

    def draw(part, x, y, w, h):
        out = [rect(x, y, w, h, cyan, wash)]
        if not brackets or part is None:
            return "".join(out)
        b = 1.5
        if "left" in part:
            out.append(rect(x, y, b, h, gold))
        if "right" in part:
            out.append(rect(x + w - b, y, b, h, gold))
        if part in ("topleft", "topright"):
            out.append(rect(x, y, w, b, gold))
        if part in ("bottomleft", "bottomright"):
            out.append(rect(x, y + h - b, w, b, gold))
        return "".join(out)
    return draw


def hack_pieces(t, y0):
    p = Pieces(y0)
    # Standard element names: translucent menus also look up <element>-shadow-* and its
    # hints by the frame element's name, so a renamed element lost its frame on Wayland.
    # Popups that are not the active window (tray menus, tooltips) are drawn from the
    # -inactive pieces; missing ones fall through to Kvantum's built-in default theme.
    for suffix in ("", "-inactive"):
        nine(p, "menu-normal" + suffix, F, C, glass_frame(t, F), zero=True)
        nine(p, "tooltip-normal" + suffix, F, C, glass_frame(t, F))
        nine(p, "menuitem-focused" + suffix, FI, C, item_frame(t, 0.16, True))
        nine(p, "menuitem-pressed" + suffix, FI, C, item_frame(t, 0.28, True))
        nine(p, "menuitem-toggled" + suffix, FI, C, item_frame(t, 0.22, True))
    return "\n".join(p.parts)


# ------------------------------------------------------------------ config

def section(cfg, name, body):
    """Replace [name] (up to the next section) with body, or append it."""
    pat = re.compile(r"^\[" + re.escape(name) + r"\]\n(?:(?!\[).*\n?)*", re.M)
    block = f"[{name}]\n{body.strip()}\n\n"
    return pat.sub(block, cfg, count=1) if pat.search(cfg) else cfg + "\n" + block


def set_key(cfg, sec, key, value):
    pat = re.compile(r"(^\[" + re.escape(sec) + r"\]\n(?:(?!\[).*\n)*?)" + re.escape(key) + r"=.*$", re.M)
    if pat.search(cfg):
        return pat.sub(lambda m: m.group(1) + f"{key}={value}", cfg, count=1)
    return re.sub(r"^\[" + re.escape(sec) + r"\]\n", lambda m: m.group(0) + f"{key}={value}\n", cfg, count=1, flags=re.M)


def build(name, t):
    base = t["base"]
    svg = open(f"{SRC}/{base}/{base}.svg").read()
    cfg = open(f"{SRC}/{base}/{base}.kvconfig").read()

    svg = HEX.sub(lambda m: t["recolor"](m.group(0)), svg)
    # Retire the template's own menu / item / tooltip art (its menu shadows stay).
    svg = re.sub(r'id="((?:menu-normal|menuitem-(?:focused|pressed|toggled)|tooltip-normal)[^"]*)"', r'id="old-\1"', svg)
    m = re.search(r'<svg[^>]*\bheight="([0-9.]+)', svg)
    y0 = float(m.group(1)) + 20 if m else 2000
    svg = svg.replace("</svg>", "<!-- helba .hack pieces -->\n" + hack_pieces(t, y0) + "\n</svg>")

    cfg = set_key(cfg, "%General", "author", "helba, after Tsu Jan's " + base)
    cfg = set_key(cfg, "%General", "comment", ".hack (The World): Helba World glass, gold and data cyan")
    cfg = set_key(cfg, "%General", "composite", "true")
    cfg = set_key(cfg, "%General", "translucent_windows", "false")
    # The template's menu-shadow art replaces the frame on the translucent (Wayland) path.
    cfg = set_key(cfg, "%General", "menu_shadow_depth", "0")
    cfg = set_key(cfg, "%General", "tooltip_shadow_depth", "0")
    colors = "\n".join(f"{k}={v}" for k, v in t["colors"].items())
    cfg = section(cfg, "GeneralColors", colors)
    cfg = section(cfg, "Menu", f"""
inherits=PanelButtonCommand
frame.top={F}
frame.bottom={F}
frame.left={F}
frame.right={F}
frame.element=menu
interior.element=menu
""")
    cfg = section(cfg, "MenuItem", f"""
inherits=PanelButtonCommand
frame=true
frame.element=menuitem
interior.element=menuitem
indicator.element=menuitem
text.normal.color={t["ink"]}
text.focus.color={t["ink"]}
text.press.color={t["ink"]}
text.toggle.color={t["ink"]}
text.margin.top=2
text.margin.bottom=2
text.margin.left=6
text.margin.right=6
frame.top={FI}
frame.bottom={FI}
frame.left={FI}
frame.right={FI}
""")
    cfg = section(cfg, "ToolTip", f"""
inherits=GenericFrame
frame.top={F}
frame.bottom={F}
frame.left={F}
frame.right={F}
interior=true
text.shadow=0
text.margin=2
interior.element=tooltip
frame.element=tooltip
""")

    root = os.path.join(OUT, name)
    os.makedirs(root, exist_ok=True)
    with open(os.path.join(root, name + ".svg"), "w") as f:
        f.write(svg)
    with open(os.path.join(root, name + ".kvconfig"), "w") as f:
        f.write(cfg)


for name, t in THEMES.items():
    build(name, t)
print("kvantum themes written to", OUT)
