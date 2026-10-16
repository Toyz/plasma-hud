#!/usr/bin/env python3
"""Generate the HelbaWorld-cursors theme (.hack, The World) into packages/cursors/.

    python3 dev/cursors_gen.py packages/cursors/HelbaWorld-cursors [--xcursor]

A normal cursor set in the Helba look: every shape keeps its standard silhouette and
hotspot, drawn in deep navy with a gold edge over a faint dark halo (readable on any
background), with a small cyan diamond where it fits; busy cursors turn a dashed gold
gate ring. Writes the scalable SVG theme Plasma uses on Wayland (cursors_scalable/,
committed) and, with --xcursor, Xcursor files for X11 / XWayland apps (cursors/, built
at install time with rsvg-convert; not committed). Alias names (CSS, X11 legacy and
hashed ids) mirror Breeze's so every request lands on a shape.
"""
import io
import json
import math
import os
import shutil
import struct
import subprocess
import sys

OUT = sys.argv[1]
XCURSOR = "--xcursor" in sys.argv

NAVY = "#0f1734"
GOLD = "#e2c27d"
CYAN = "#8fe3ff"
RED = "#ff6074"
SIZES = [24, 30, 36, 48, 64, 72, 96]
FRAMES = 12
FRAME_MS = 60


# ------------------------------------------------------------------ drawing helpers (24 px grid)

def shape(d, fill=NAVY, edge=GOLD, w=1.1):
    """A filled outline over a dark halo."""
    return (f'<path d="{d}" fill="none" stroke="#000" stroke-opacity="0.38" stroke-width="{w + 1.6}" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<path d="{d}" fill="{fill}" stroke="{edge}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"/>')


def line(d, color=GOLD, w=1.6):
    return (f'<path d="{d}" fill="none" stroke="#000" stroke-opacity="0.4" stroke-width="{w + 1.6}" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')


def dia(cx, cy, r, color=CYAN):
    return f'<path d="M{cx},{cy - r} L{cx + r},{cy} L{cx},{cy + r} L{cx - r},{cy} Z" fill="{color}"/>'


def rot(deg, inner, cx=12, cy=12):
    return f'<g transform="rotate({deg} {cx} {cy})">{inner}</g>'


ARROW = "M3,2 L3,19.2 L7.3,15.3 L10.3,21.7 L12.9,20.5 L10,14.3 L15.8,14.3 Z"


def arrow():
    return shape(ARROW) + dia(5.6, 12.4, 1.15)


def badge(inner, color=CYAN):
    """A diamond badge at the bottom right of the arrow."""
    return (f'<path d="M18,11.6 L23.2,16.8 L18,22 L12.8,16.8 Z" fill="#000" fill-opacity="0.38" transform="translate(0.4,0.4)"/>'
            f'<path d="M18,12 L22.8,16.8 L18,21.6 L13.2,16.8 Z" fill="{NAVY}" stroke="{color}" stroke-width="1"/>'
            f'<g transform="translate(18,16.8)">{inner}</g>')


def double_arrow(length=18, head=4.6, shaft=1.7):
    """Horizontal double-headed arrow centred on (12, 12)."""
    h = length / 2
    d = (f"M{12 - h},12 L{12 - h + head},{12 - head} L{12 - h + head},{12 - shaft} L{12 + h - head},{12 - shaft} "
         f"L{12 + h - head},{12 - head} L{12 + h},12 L{12 + h - head},{12 + head} L{12 + h - head},{12 + shaft} "
         f"L{12 - h + head},{12 + shaft} L{12 - h + head},{12 + head} Z")
    return shape(d)


def single_arrow(length=16, head=5.2, shaft=1.8):
    """Arrow pointing right, centred on (12, 12)."""
    h = length / 2
    d = (f"M{12 + h},12 L{12 + h - head},{12 - head} L{12 + h - head},{12 - shaft} L{12 - h},{12 - shaft} "
         f"L{12 - h},{12 + shaft} L{12 + h - head},{12 + shaft} L{12 + h - head},{12 + head} Z")
    return shape(d)


def ring(phase, cx=12, cy=12, r=7.6, w=2.2):
    """The dashed gate ring, turned by phase (0..1)."""
    circ = 2 * math.pi * r
    dash = circ / 8
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{NAVY}" fill-opacity="0.85" stroke="#000" stroke-opacity="0.4" stroke-width="{w + 1.6}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{GOLD}" stroke-opacity="0.35" stroke-width="{w}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{GOLD}" stroke-width="{w}" stroke-linecap="round" '
            f'stroke-dasharray="{dash * 0.6:.2f} {dash * 0.4:.2f}" stroke-dashoffset="{-phase * circ:.2f}" '
            f'transform="rotate({phase * 360:.1f} {cx} {cy})"/>'
            + dia(cx, cy, r * 0.42))


HAND_POINT = ("M8.7,3.4 A1.35,1.35 0 0 1 11.4,3.4 V9.7 L15.6,10.4 A1.7,1.7 0 0 1 17.1,12.1 V16.4 "
              "C17.1,19.3 15.3,21.3 12.4,21.3 H10.6 C8.6,21.3 7.4,20.3 6.4,18.7 L3.8,14.5 A1.35,1.35 0 0 1 5.9,12.9 L8.7,15.3 Z")
HAND_OPEN = ("M6.4,10.6 V5.6 A1.25,1.25 0 0 1 8.9,5.6 V9.8 V4.2 A1.25,1.25 0 0 1 11.4,4.2 V9.8 V4.8 A1.25,1.25 0 0 1 13.9,4.8 V10 "
             "V6.6 A1.25,1.25 0 0 1 16.4,6.6 V15.2 C16.4,18.8 14.4,20.8 11.6,20.8 H10.4 C8.4,20.8 7.2,19.8 6.2,18.2 "
             "L3.6,13.8 A1.3,1.3 0 0 1 5.6,12.3 L6.4,13.2 Z")
HAND_CLOSED = ("M6.6,10.4 A1.3,1.3 0 0 1 8.8,9.6 A1.3,1.3 0 0 1 11.2,8.9 A1.3,1.3 0 0 1 13.6,9.2 A1.3,1.3 0 0 1 16,10 "
               "A1.3,1.3 0 0 1 17,11.4 V15.6 C17,18.9 15,20.8 12.2,20.8 H10.6 C8.6,20.8 7.4,19.8 6.6,18.4 Z")


# ------------------------------------------------------------------ the shapes: name -> (svg body or [frames], hotspot)

def shapes():
    S = {}
    S["default"] = (arrow(), (3, 2))
    S["right_ptr"] = (f'<g transform="translate(24,0) scale(-1,1)">{arrow()}</g>', (21, 2))
    S["center_ptr"] = (rot(-30, arrow(), 3, 2), (3, 2))
    S["pointer"] = (shape(HAND_POINT) + line("M12.9,11.1 V13.6 M14.9,11.4 V13.8", GOLD, 0.8) + dia(10.1, 17, 1.1), (10, 2.4))
    S["openhand"] = (shape(HAND_OPEN) + dia(11.2, 15.4, 1.1), (11.5, 11))
    S["dnd-move"] = (shape(HAND_CLOSED) + dia(11.8, 15.2, 1.1), (11.5, 12))
    S["text"] = (line("M8.6,4 H15.4 M8.6,20 H15.4 M12,4 V20", GOLD, 1.5) + dia(12, 12, 1), (12, 12))
    S["vertical-text"] = (rot(90, S["text"][0]), (12, 12))
    S["crosshair"] = (line("M12,2.5 V9 M12,15 V21.5 M2.5,12 H9 M15,12 H21.5", GOLD, 1.4) + dia(12, 12, 1.6), (12, 12))
    S["cell"] = (shape("M9.6,3.4 H14.4 V9.6 H20.6 V14.4 H14.4 V20.6 H9.6 V14.4 H3.4 V9.6 H9.6 Z") + dia(12, 12, 1.2), (12, 12))
    S["help"] = (arrow() + badge(f'<text x="0" y="2.1" text-anchor="middle" font-family="Noto Serif, serif" font-size="6.2" fill="{CYAN}">?</text>'), (3, 2))
    S["context-menu"] = (arrow() + badge(line("M-2,-1.4 H2 M-2,0.2 H2 M-2,1.8 H2", CYAN, 0.7)), (3, 2))
    S["alias"] = (arrow() + badge(line("M-1.8,1.8 V0 Q-1.8,-1.6 0,-1.6 H1.6 M0.4,-2.8 L1.8,-1.6 L0.4,-0.4", CYAN, 0.75)), (3, 2))
    S["copy"] = (arrow() + badge(line("M0,-2 V2 M-2,0 H2", CYAN, 0.9)), (3, 2))
    S["dnd-no-drop"] = (arrow() + badge(f'<circle r="2" fill="none" stroke="{RED}" stroke-width="0.9"/>' + line("M-1.4,1.4 L1.4,-1.4", RED, 0.9), RED), (3, 2))
    S["no-drop"] = S["dnd-no-drop"]
    S["not-allowed"] = (f'<circle cx="12" cy="12" r="7.6" fill="{NAVY}" stroke="#000" stroke-opacity="0.4" stroke-width="4"/>'
                        f'<circle cx="12" cy="12" r="7.6" fill="{NAVY}" stroke="{RED}" stroke-width="2.2"/>'
                        + line("M6.8,17.2 L17.2,6.8", RED, 2.2), (12, 12))
    S["x-cursor"] = (line("M5,5 L19,19 M19,5 L5,19", GOLD, 2.2) + dia(12, 12, 1.6), (12, 12))
    S["pirate"] = S["x-cursor"]
    four = double_arrow(19) + rot(90, double_arrow(19)) + dia(12, 12, 1.8)
    S["fleur"] = (four, (12, 12))
    S["all-scroll"] = (four, (12, 12))
    S["size_hor"] = (double_arrow(), (12, 12))
    S["size_ver"] = (rot(90, double_arrow()), (12, 12))
    S["size_bdiag"] = (rot(-45, double_arrow(17)), (12, 12))
    S["size_fdiag"] = (rot(45, double_arrow(17)), (12, 12))
    S["col-resize"] = (double_arrow(20) + line("M12,4 V20", GOLD, 1.6), (12, 12))
    S["row-resize"] = (rot(90, double_arrow(20)) + line("M4,12 H20", GOLD, 1.6), (12, 12))
    bar = line("M20,4 V20", GOLD, 1.8)
    side = single_arrow(14) + bar
    S["right_side"] = (side, (20, 12))
    S["left_side"] = (rot(180, side), (4, 12))
    S["bottom_side"] = (rot(90, side), (12, 20))
    S["top_side"] = (rot(-90, side), (12, 4))
    corner = rot(45, single_arrow(14), 12, 12) + line("M19.5,10 V19.5 H10", GOLD, 1.8)
    S["bottom_right_corner"] = (corner, (19.5, 19.5))
    S["bottom_left_corner"] = (rot(90, corner), (4.5, 19.5))
    S["top_left_corner"] = (rot(180, corner), (4.5, 4.5))
    S["top_right_corner"] = (rot(-90, corner), (19.5, 4.5))
    S["right-arrow"] = (single_arrow(), (20, 12))
    S["left-arrow"] = (rot(180, single_arrow()), (4, 12))
    S["down-arrow"] = (rot(90, single_arrow()), (12, 20))
    S["up-arrow"] = (rot(-90, single_arrow()), (12, 4))
    pencil = (shape("M17.4,3.2 L20.8,6.6 L8.6,18.8 L3.4,20.6 L5.2,15.4 Z") + line("M15.2,5.4 L18.6,8.8", CYAN, 1.2)
              + line("M5.2,15.4 L8.6,18.8", GOLD, 0.9))
    S["pencil"] = (pencil, (3.4, 20.6))
    S["draft"] = S["pencil"]
    S["color-picker"] = (shape("M16.6,3.6 A2.4,2.4 0 0 1 20.4,7.4 L17.6,10.2 L18.6,11.2 L16.8,13 L11,7.2 L12.8,5.4 L13.8,6.4 Z")
                         + shape("M11.8,8 L16,12.2 L7.6,20.6 L4.4,20.6 L3.4,19.6 L3.4,16.4 Z", CYAN, GOLD, 1), (3.6, 20.4))
    glass = shape("M10,3.4 A6.6,6.6 0 1 1 10,16.6 A6.6,6.6 0 1 1 10,3.4 Z") + line("M14.8,14.8 L20.4,20.4", GOLD, 2.6)
    S["zoom-in"] = (glass + line("M10,7.2 V12.8 M7.2,10 H12.8", CYAN, 1.3), (10, 10))
    S["zoom-out"] = (glass + line("M7.2,10 H12.8", CYAN, 1.3), (10, 10))
    S["wayland-cursor"] = S["default"]
    # Busy: the gate ring turning, alone (wait) or beside the arrow (progress).
    S["wait"] = ([ring(i / FRAMES) for i in range(FRAMES)], (12, 12))
    S["progress"] = ([arrow() + ring(i / FRAMES, 17.4, 17.4, 4.4, 1.6) for i in range(FRAMES)], (3, 2))
    return S


ALIASES = {
    "00000000000000020006000e7e9ffc3f": "progress", "00008160000006810000408080010102": "size_ver",
    "03b6e0fcb3499374a867c041f52298f0": "not-allowed", "08e8e1c95fe2fc01f976f1e063a24ccd": "progress",
    "1081e37283d90000800003c07f3ef6bf": "copy", "3085a0e285430894940527032f8b26df": "alias",
    "3ecb610c1bf2410f44200f48c40d3599": "progress", "4498f0e0c1937ffe01fd06f973665830": "dnd-move",
    "5c6cd98b3f3ebcb1f9c7f1c204630408": "help", "6407b0e94181790501fd1e167b474872": "copy",
    "640fb0e74195791501fd1ed57b41487f": "alias", "9081237383d90e509aa00f00170e968f": "dnd-move",
    "9d800788f1b08800ae810202380a0822": "pointer", "a2a266d0498c3104214a47bd64ab0fc8": "alias",
    "b66166c04f8c3109214a4fbd64a50fc8": "copy", "d9ce0ab605698f320427677b458ad60b": "help",
    "e29285e634086352946a0e7090d73106": "pointer", "fcf21c00b30f7e3f83fe0dfd12e71cff": "dnd-move",
    "arrow": "default", "circle": "not-allowed", "closedhand": "dnd-move", "cross": "crosshair",
    "crossed_circle": "not-allowed", "dnd-copy": "copy", "dnd-none": "dnd-move", "e-resize": "size_hor",
    "ew-resize": "size_hor", "forbidden": "no-drop", "grab": "openhand", "grabbing": "dnd-move",
    "h_double_arrow": "size_hor", "half-busy": "progress", "hand1": "pointer", "hand2": "pointer", "ibeam": "text",
    "left_ptr": "default", "left_ptr_help": "help", "left_ptr_watch": "progress", "link": "alias", "move": "dnd-move",
    "n-resize": "size_ver", "ne-resize": "size_bdiag", "nesw-resize": "size_bdiag", "ns-resize": "size_ver",
    "nw-resize": "size_fdiag", "nwse-resize": "size_fdiag", "plus": "cell", "pointing_hand": "pointer",
    "question_arrow": "help", "s-resize": "size_ver", "sb_h_double_arrow": "size_hor", "sb_v_double_arrow": "size_ver",
    "se-resize": "size_fdiag", "size-bdiag": "size_bdiag", "size-fdiag": "size_fdiag", "size-hor": "size_hor",
    "size-ver": "size_ver", "size_all": "fleur", "split_h": "col-resize", "split_v": "row-resize",
    "sw-resize": "size_bdiag", "tcross": "crosshair", "top_left_arrow": "default", "v_double_arrow": "size_ver",
    "w-resize": "size_hor", "watch": "wait", "whats_this": "help", "xterm": "text",
    "col-resize": "col-resize", "row-resize": "row-resize", "ns_resize": "size_ver",
}


def svg_doc(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">{body}</svg>\n'


# ------------------------------------------------------------------ Xcursor

def png(svg_text, size):
    """Render an SVG to RGBA rows with rsvg-convert."""
    from PIL import Image
    r = subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size)], input=svg_text.encode(), capture_output=True, check=True)
    return Image.open(io.BytesIO(r.stdout)).convert("RGBA")


def xcursor(images):
    """images: list of (nominal size, width, height, xhot, yhot, delay, RGBA image)."""
    header = 16
    toc = 12 * len(images)
    chunks, pos, entries = [], header + toc, []
    for nominal, w, h, xh, yh, delay, img in images:
        raw = img.tobytes()
        px = bytearray()
        for i in range(0, len(raw), 4):
            r, g, b, a = raw[i], raw[i + 1], raw[i + 2], raw[i + 3]
            px += struct.pack("<I", (a << 24) | ((r * a // 255) << 16) | ((g * a // 255) << 8) | (b * a // 255))
        chunk = struct.pack("<9I", 36, 0xfffd0002, nominal, 1, w, h, xh, yh, delay) + bytes(px)
        entries.append(struct.pack("<3I", 0xfffd0002, nominal, pos))
        chunks.append(chunk)
        pos += len(chunk)
    return b"Xcur" + struct.pack("<3I", header, 0x10000, len(images)) + b"".join(entries) + b"".join(chunks)


# ------------------------------------------------------------------ write

def main():
    scalable = os.path.join(OUT, "cursors_scalable")
    xdir = os.path.join(OUT, "cursors")
    shutil.rmtree(scalable, ignore_errors=True)
    os.makedirs(scalable)
    if XCURSOR:
        shutil.rmtree(xdir, ignore_errors=True)
        os.makedirs(xdir)
    S = shapes()
    for name, (body, (hx, hy)) in S.items():
        frames = body if isinstance(body, list) else [body]
        d = os.path.join(scalable, name)
        os.makedirs(d)
        meta = []
        for i, f in enumerate(frames):
            fn = f"{name}.svg" if len(frames) == 1 else f"{name}-{i:02d}.svg"
            with open(os.path.join(d, fn), "w") as out:
                out.write(svg_doc(f))
            entry = {"filename": fn, "hotspot_x": hx, "hotspot_y": hy, "nominal_size": 24}
            if len(frames) > 1:
                entry["delay"] = FRAME_MS
            meta.append(entry)
        with open(os.path.join(d, "metadata.json"), "w") as out:
            json.dump(meta, out, indent=4)
        if XCURSOR:
            imgs = []
            for size in SIZES:
                for f in frames:
                    imgs.append((size, size, size, round(hx * size / 24), round(hy * size / 24),
                                 FRAME_MS if len(frames) > 1 else 0, png(svg_doc(f), size)))
            with open(os.path.join(xdir, name), "wb") as out:
                out.write(xcursor(imgs))
    for alias, target in ALIASES.items():
        if alias in S or target not in S:
            continue
        os.symlink(target, os.path.join(scalable, alias))
        if XCURSOR:
            os.symlink(target, os.path.join(xdir, alias))
    with open(os.path.join(OUT, "index.theme"), "w") as out:
        out.write("[Icon Theme]\nName=Helba World cursors\n"
                  "Comment=.hack (The World): a normal cursor set in navy and gold with cyan diamonds\n"
                  "Inherits=breeze_cursors\n")
    print(f"{len(S)} cursors, {sum(1 for a, t in ALIASES.items() if a not in S and t in S)} aliases"
          + (", Xcursor built" if XCURSOR else ""))


main()
