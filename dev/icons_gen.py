#!/usr/bin/env python3
"""Generate the HelbaWorld icon theme (.hack, The World) into packages/icons/HelbaWorld.

    python3 dev/icons_gen.py packages/icons/HelbaWorld

A curated set over the user's icon theme (it inherits Papirus-Dark, breeze-dark and
hicolor, so anything not drawn here falls through): folders and places as midnight
glass folders with a bronze rim, diamond studs and a cyan-edged diamond emblem saying
what is inside; the trash; and start-here as Root Town's Twilight Bracelet. A
scalable design for 22 px and up, and a simplified 16 px one for sidebars.
"""
import os
import sys

OUT = sys.argv[1]

GOLD = "#b8935a"
GOLD_LIGHT = "#e2c27d"
CYAN = "#8fe3ff"
NAVY_TOP = "#1f2a58"
NAVY = "#0f1734"
NAVY_DEEP = "#0a1022"
INK = "#eaf0fb"


def svg(size, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
            f"<defs>{defs}</defs>{body}</svg>\n")


def diamond(cx, cy, r, fill="none", stroke=None, sw=1.0, op=1.0):
    pts = f"{cx},{cy - r} {cx + r},{cy} {cx},{cy + r} {cx - r},{cy}"
    st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="miter"' if stroke else ""
    return f'<polygon points="{pts}" fill="{fill}" fill-opacity="{op}"{st}/>'


# ------------------------------------------------------------------ emblem glyphs
# Drawn in a 16x16 box centred on (0, 0), stroked in gold; scaled into the emblem.

def g_lines():        # documents
    return '<path d="M-4.5,-4 H4.5 M-4.5,-1.3 H4.5 M-4.5,1.4 H4.5 M-4.5,4.1 H1.5"/>'


def g_down():         # downloads
    return '<path d="M0,-5.5 V3.2 M-3.8,-0.4 L0,3.4 L3.8,-0.4 M-4.8,5.4 H4.8"/>'


def g_picture():      # pictures
    return ('<path d="M-5,4.5 L-1.5,-0.5 L1.2,2.6 L2.8,0.8 L5,4.5 Z" fill="currentColor" stroke="none"/>'
            '<circle cx="2.6" cy="-3.2" r="1.5" fill="currentColor" stroke="none"/>')


def g_note():         # music
    return ('<path d="M1.8,3 V-5.2 L5,-4 V-1.6 L1.8,-2.8"/>'
            '<ellipse cx="-0.4" cy="3.4" rx="2.4" ry="1.8" fill="currentColor" stroke="none"/>')


def g_play():         # videos
    return '<path d="M-3,-4.8 L4.8,0 L-3,4.8 Z" fill="currentColor" stroke="none"/>'


def g_home():         # home
    return '<path d="M-5.2,0.2 L0,-5 L5.2,0.2 M-3.6,-1.2 V5 H3.6 V-1.2 M-1.2,5 V1.6 H1.2 V5"/>'


def g_monitor():      # desktop
    return '<path d="M-5.2,-4.4 H5.2 V2.2 H-5.2 Z M0,2.2 V4.6 M-2.8,4.8 H2.8"/>'


def g_stack():        # templates
    return '<path d="M-4.5,-1.5 H3 V5 H-4.5 Z M-3,-3.5 H4.5 V3"/>'


def g_broadcast():    # public share
    return ('<circle cx="0" cy="2.6" r="1.3" fill="currentColor" stroke="none"/>'
            '<path d="M-3,0 A4,4 0 0 1 3,0 M-5.4,-2.4 A7.4,7.4 0 0 1 5.4,-2.4"/>')


def g_globe():        # remote / network
    return ('<circle cx="0" cy="0" r="5"/>'
            '<path d="M-5,0 H5 M0,-5 C-2.8,-2 -2.8,2 0,5 M0,-5 C2.8,-2 2.8,2 0,5"/>')


def g_code():         # code / git / development
    return '<path d="M-2,-4 L-5.4,0 L-2,4 M2,-4 L5.4,0 L2,4"/>'


def g_letter(ch):     # Greek server glyphs
    return (f'<text x="0" y="4.2" text-anchor="middle" font-family="Noto Serif, serif" font-size="12" '
            f'fill="currentColor" stroke="none">{ch}</text>')


def g_pad():          # games
    return ('<path d="M-5.4,-1.8 Q-5.4,-3.6 -3.4,-3.6 H3.4 Q5.4,-3.6 5.4,-1.8 L5.8,3 Q5.8,4.6 4.2,4 L2,2 H-2 '
            'L-4.2,4 Q-5.8,4.6 -5.8,3 Z M-3.4,-1 V1.6 M-4.7,0.3 H-2.1"/>')


# ------------------------------------------------------------------ folder (scalable, 64 box)

def folder(glyph=None, open_=False):
    defs = (f'<linearGradient id="body" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{NAVY_TOP}"/><stop offset="1" stop-color="{NAVY}"/></linearGradient>'
            f'<linearGradient id="flap" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#26346b"/><stop offset="1" stop-color="{NAVY_TOP}"/></linearGradient>')
    b = []
    # Back with its tab.
    b.append(f'<path d="M6,14 H24 L28,18 H58 V54 H6 Z" fill="{NAVY_DEEP}" stroke="{GOLD}" stroke-width="1.2" stroke-opacity="0.7"/>')
    if open_:
        # Front flap tipped forward.
        b.append(f'<path d="M4,26 H60 L56,56 H8 Z" fill="url(#flap)" stroke="{GOLD}" stroke-width="1.5"/>')
        b.append(f'<path d="M7.6,29 H56.4" stroke="{GOLD}" stroke-width="1" stroke-opacity="0.3"/>')
        studs = [(4, 26), (60, 26), (8, 56), (56, 56)]
        ec = (32, 41)
    else:
        b.append(f'<rect x="4" y="22" width="56" height="34" rx="2" fill="url(#body)" stroke="{GOLD}" stroke-width="1.5"/>')
        b.append(f'<rect x="7" y="25" width="50" height="28" rx="1" fill="none" stroke="{GOLD}" stroke-width="1" stroke-opacity="0.25"/>')
        studs = [(4, 22), (60, 22), (4, 56), (60, 56)]
        ec = (32, 39)
    for x, y in studs:
        b.append(diamond(x, y, 2.6, fill=GOLD_LIGHT))
    # Emblem: a cyan-edged diamond with the folder's glyph.
    b.append(diamond(ec[0], ec[1], 11.5, fill=NAVY_DEEP, stroke=CYAN, sw=1.3, op=0.9))
    b.append(diamond(ec[0], ec[1], 8.8, stroke=GOLD, sw=0.8))
    if glyph:
        b.append(f'<g transform="translate({ec[0]},{ec[1]}) scale(0.82)" color="{GOLD_LIGHT}" fill="none" '
                 f'stroke="{GOLD_LIGHT}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">{glyph}</g>')
    else:
        b.append(diamond(ec[0], ec[1], 3, fill=CYAN))
    return svg(64, "".join(b), defs)


# ------------------------------------------------------------------ folder (16 px)

def folder16(accent):
    b = [f'<path d="M1.5,3 H6 L7,4 H14.5 V13.5 H1.5 Z" fill="{NAVY_DEEP}"/>',
         f'<rect x="1" y="5" width="14" height="9" rx="0.5" fill="{NAVY_TOP}" stroke="{GOLD}" stroke-width="1"/>',
         diamond(8, 9.5, 2.6, fill=accent)]
    return svg(16, "".join(b))


# ------------------------------------------------------------------ trash, start-here

def trash(full):
    b = [f'<path d="M14,18 H50 L46,58 H18 Z" fill="{NAVY}" stroke="{GOLD}" stroke-width="1.5"/>',
         f'<path d="M10,14 H54 V19 H10 Z" fill="{NAVY_TOP}" stroke="{GOLD}" stroke-width="1.5"/>',
         f'<path d="M26,10 H38 V14 H26 Z" fill="none" stroke="{GOLD}" stroke-width="1.5"/>',
         f'<path d="M24,26 L25.5,52 M32,26 V52 M40,26 L38.5,52" stroke="{GOLD}" stroke-width="1" stroke-opacity="0.45"/>']
    for x, y in [(10, 14), (54, 14), (18, 58), (46, 58)]:
        b.append(diamond(x, y, 2.4, fill=GOLD_LIGHT))
    if full:
        # Data cells spilling over the rim.
        for i, (x, y, s) in enumerate([(22, 9, 4), (30, 5, 5), (39, 8, 4), (45, 3, 3), (17, 4, 3)]):
            b.append(f'<rect x="{x}" y="{y}" width="{s}" height="{s}" fill="{CYAN}" fill-opacity="{0.9 - i * 0.12}"/>')
    return svg(64, "".join(b))


def start_here():
    # Root Town's Twilight Bracelet: a gold ring with three studs around a cyan diamond.
    b = [f'<circle cx="32" cy="32" r="22" fill="{NAVY_DEEP}" stroke="{GOLD}" stroke-width="3"/>',
         f'<circle cx="32" cy="32" r="16" fill="none" stroke="{GOLD}" stroke-width="1" stroke-opacity="0.45"/>',
         diamond(32, 32, 9, fill=CYAN, stroke="#ffffff", sw=0.8, op=0.95)]
    for a in (90, 210, 330):
        import math
        x = 32 + 22 * math.cos(math.radians(a))
        y = 32 - 22 * math.sin(math.radians(a))
        b.append(diamond(round(x, 2), round(y, 2), 4.5, fill=GOLD_LIGHT, stroke=NAVY_DEEP, sw=1))
    return svg(64, "".join(b))


# ------------------------------------------------------------------ names

# icon name(s) -> (glyph, 16 px accent)
PLACES = {
    ("folder",): (None, CYAN),
    ("folder-documents", "folder_wordprocessing", "folder-text", "folder-txt", "folder-notes"): (g_lines(), GOLD_LIGHT),
    ("folder-download", "folder-downloads"): (g_down(), CYAN),
    ("folder-pictures", "folder-images", "folder-image", "folder-photos", "folder-photo", "folder-picture"): (g_picture(), "#7fd6a8"),
    ("folder-music", "folder-sound"): (g_note(), "#d79bff"),
    ("folder-videos", "folder-video", "folder-videocamera"): (g_play(), "#ff8f8f"),
    ("folder-templates",): (g_stack(), GOLD_LIGHT),
    ("folder-publicshare", "folder-public"): (g_broadcast(), CYAN),
    ("folder-remote", "folder-network", "network-workgroup"): (g_globe(), CYAN),
    ("folder-code", "folder-development", "folder-git", "folder-github", "folder-gitlab", "folder-script"): (g_code(), "#8fe3ff"),
    ("folder-projects",): (g_letter("Σ"), GOLD_LIGHT),
    ("folder-games", "folder-steam"): (g_pad(), "#ff8f8f"),
    ("folder-root",): (g_letter("Ω"), "#ff8f8f"),
    ("user-home", "folder-home", "folder_home"): (g_home(), GOLD_LIGHT),
    ("user-desktop", "folder-desktop"): (g_monitor(), CYAN),
}
OPENABLE = {"folder", "folder-documents", "folder-download", "folder-pictures", "folder-music", "folder-videos",
            "folder-templates", "folder-publicshare", "folder-remote", "user-home"}


def write(rel, text):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


count = 0
for names, (glyph, accent) in PLACES.items():
    for n in names:
        write(f"scalable/places/{n}.svg", folder(glyph))
        write(f"16x16/places/{n}.svg", folder16(accent))
        count += 1
        if n in OPENABLE:
            open_name = "folder-open" if n == "folder" else f"{n}-open"
            write(f"scalable/places/{open_name}.svg", folder(glyph, open_=True))
            write(f"16x16/places/{open_name}.svg", folder16(accent))
            count += 1
for n, full in [("user-trash", False), ("user-trash-full", True)]:
    write(f"scalable/places/{n}.svg", trash(full))
    count += 1
for n in ["start-here", "start-here-kde", "start-here-kde-plasma", "start-here-archlinux", "start-here-cachyos"]:
    write(f"scalable/places/{n}.svg", start_here())
    count += 1


# ------------------------------------------------------------------ tray / status (v2)
# 22 px grid, recolored by Plasma from the color scheme: Text is ink, Highlight is the
# data cyan, NeutralText the gold (bronze in light), NegativeText red.

STATUS_STYLE = ('<style type="text/css" id="current-color-scheme">'
                '.ColorScheme-Text{color:#eaf0fb;}.ColorScheme-Highlight{color:#8fe3ff;}'
                '.ColorScheme-NeutralText{color:#f5c85a;}.ColorScheme-NegativeText{color:#ff6074;}</style>')


def st(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 22 22"><defs>{STATUS_STYLE}</defs>{body}</svg>\n'


def stroke(cls, d, w=1.6, op=1.0, extra=""):
    return (f'<path class="ColorScheme-{cls}" style="fill:none;stroke:currentColor" stroke-width="{w}" '
            f'stroke-linecap="round" stroke-linejoin="round" stroke-opacity="{op}" d="{d}"{extra}/>')


def fill(cls, d, op=1.0):
    return f'<path class="ColorScheme-{cls}" style="fill:currentColor" fill-opacity="{op}" d="{d}"/>'


def sdiamond(cx, cy, r):
    return f"M{cx},{cy - r} L{cx + r},{cy} L{cx},{cy + r} L{cx - r},{cy} Z"


SLASH = stroke("NegativeText", "M4,18 L18,4", 1.8)


def wifi(level, mark=None, dashed=False, off=False):
    """level 0..3 arcs lit; mark: None | 'secure' | 'limited'."""
    arcs = ["M8.2,13.6 A4,4 0 0 1 13.8,13.6", "M5.4,10.8 A8,8 0 0 1 16.6,10.8", "M2.6,8 A12,12 0 0 1 19.4,8"]
    out = []
    for i, d in enumerate(arcs):
        lit = i < level and not off
        dash = ' stroke-dasharray="2 1.6"' if dashed else ""
        out.append(stroke("Highlight" if lit else "Text", d, 1.6, 1.0 if lit else 0.3, dash))
    out.append(fill("NeutralText" if not off else "Text", sdiamond(11, 17.2, 2.2), 1.0 if not off else 0.4))
    if mark == "secure":
        out.append(fill("NeutralText", sdiamond(18, 16.5, 2.4)))
    if mark == "limited":
        out.append(stroke("NeutralText", "M18.5,12.5 V16", 1.6) + fill("NeutralText", sdiamond(18.5, 18.6, 0.9)))
    if off:
        out.append(SLASH)
    return st("".join(out))


def wired(on=True, dashed=False, off=False, mark=None):
    dash = ' stroke-dasharray="2 1.6"' if dashed else ""
    out = [stroke("NeutralText", sdiamond(5.5, 11, 3.2), 1.5),
           stroke("NeutralText", sdiamond(16.5, 11, 3.2), 1.5),
           stroke("Highlight" if on and not off else "Text", "M8.7,11 H13.3", 1.8, 1.0 if on and not off else 0.35, dash)]
    if on and not off:
        out.append(fill("Highlight", sdiamond(5.5, 11, 1.2)) + fill("Highlight", sdiamond(16.5, 11, 1.2)))
    if mark == "limited":
        out.append(stroke("NeutralText", "M11,3 V6.5", 1.6) + fill("NeutralText", sdiamond(11, 8.6, 0.9)))
    if off:
        out.append(SLASH)
    return st("".join(out))


def vpn(on=True, dashed=False):
    dash = ' stroke-dasharray="2 1.4"' if dashed else ""
    return st(stroke("NeutralText", "M11,2.5 L18.5,6 V11 C18.5,15.5 15,18.5 11,19.8 C7,18.5 3.5,15.5 3.5,11 V6 Z", 1.5, 1, dash)
              + (fill("Highlight", sdiamond(11, 11, 3)) if on else ""))


def speaker(level, muted=False, danger=False):
    out = [fill("NeutralText", "M3,8.2 H6.4 L10.6,4.4 V17.6 L6.4,13.8 H3 Z")]
    if muted:
        out.append(stroke("NegativeText", "M13.5,8 L19,13.5 M19,8 L13.5,13.5", 1.8))
        return st("".join(out))
    arcs = ["M13.4,8.6 A3.4,3.4 0 0 1 13.4,13.4", "M15.4,6.4 A6.4,6.4 0 0 1 15.4,15.6", "M17.4,4.2 A9.4,9.4 0 0 1 17.4,17.8"]
    for i, d in enumerate(arcs):
        lit = i < level
        cls = "NegativeText" if (danger and lit) else ("Highlight" if lit else "Text")
        out.append(stroke(cls, d, 1.6, 1.0 if lit else 0.3))
    return st("".join(out))


def mic(level, muted=False):
    out = [stroke("NeutralText", "M8,5 A3,3 0 0 1 14,5 V10.5 A3,3 0 0 1 8,10.5 Z", 1.5),
           stroke("NeutralText", "M5,10 A6,6 0 0 0 17,10 M11,16 V19 M7.5,19.5 H14.5", 1.5)]
    if muted:
        out.append(SLASH)
    else:
        for i in range(3):
            lit = i < level
            out.append(fill("Highlight" if lit else "Text", f"M9.4,{11.2 - i * 2.4} H12.6 V{12.4 - i * 2.4} H9.4 Z", 1.0 if lit else 0.3))
    return st("".join(out))


def battery(pct, charging=False, missing=False, charged=False):
    out = [fill("NeutralText", "M9,1.6 H13 V3.2 H9 Z")]
    dash = ' stroke-dasharray="2 1.4"' if missing else ""
    out.append(stroke("NeutralText", "M6,3.4 H16 V20.2 H6 Z", 1.4, 1, dash))
    if missing:
        out.append(stroke("Text", "M9,9 A2,2 0 1 1 11,11 V13", 1.4, 0.8) + fill("Text", sdiamond(11, 16, 0.9), 0.8))
        return st("".join(out))
    h = 15.2 * max(0, min(100, pct)) / 100
    if h > 0.2:
        cls = "NegativeText" if pct <= 10 and not charging else ("NeutralText" if pct <= 20 and not charging else "Highlight")
        out.append(fill(cls, f"M7.6,{19 - h:.2f} H14.4 V19 H7.6 Z", 0.9))
    if charging:
        out.append(fill("NeutralText", "M12.6,5.8 L8.4,12.4 H11 L9.8,17.6 L14,10.6 H11.4 Z"))
        out.append(stroke("Text", "M12.6,5.8 L8.4,12.4 H11 L9.8,17.6 L14,10.6 H11.4 Z", 0.6, 0.6))
    if charged:
        out.append(fill("Text", sdiamond(11, 11, 2.2), 0.9))
    return st("".join(out))


def bluetooth(on=True, off=False, paired=False):
    cls = "Highlight" if on and not off else "Text"
    out = [stroke("NeutralText", sdiamond(11, 11, 9.4), 1.2, 0.8),
           stroke(cls, "M7.6,7.6 L14.4,14 L11,17 V5 L14.4,8 L7.6,14.4", 1.5, 1.0 if on and not off else 0.5)]
    if paired:
        out.append(fill("Highlight", sdiamond(5.2, 11, 1)) + fill("Highlight", sdiamond(16.8, 11, 1)))
    if off:
        out.append(SLASH)
    return st("".join(out))


def airplane(on=True):
    out = [fill("NeutralText" if on else "Text",
                "M11,2.5 C11.9,2.5 12.2,3.6 12.2,4.8 V8.6 L19.5,12.6 V14.3 L12.2,12 V16.2 L14.6,18 V19.5 L11,18.4 "
                "L7.4,19.5 V18 L9.8,16.2 V12 L2.5,14.3 V12.6 L9.8,8.6 V4.8 C9.8,3.6 10.1,2.5 11,2.5 Z", 1.0 if on else 0.5)]
    if not on:
        out.append(SLASH)
    return st("".join(out))


STATUS = {}
def add(names, text):
    for n in names:
        for v in (n, n + "-panel", n + "-symbolic"):
            STATUS[v] = text

# Wi-Fi
for lvl, names in {0: ["network-wireless-0", "network-wireless-signal-none", "network-wireless-connected-00"],
                   1: ["network-wireless-20", "network-wireless-signal-weak", "network-wireless-signal-low", "network-wireless-connected-25"],
                   2: ["network-wireless-40", "network-wireless-60", "network-wireless-signal-ok", "network-wireless-connected-50"],
                   3: ["network-wireless-80", "network-wireless-100", "network-wireless-signal-good", "network-wireless-signal-excellent",
                       "network-wireless-connected-75", "network-wireless-connected-100", "network-wireless-connected", "network-wireless",
                       "network-wireless-on", "network-wireless-available"]}.items():
    add(names, wifi(lvl))
    add([n.replace("signal-", "secure-signal-") for n in names if "signal-" in n], wifi(lvl, "secure"))
    add([n + "-limited" for n in names if n.split("-")[-1].isdigit() and "connected" not in n], wifi(lvl, "limited"))
add(["network-wireless-encrypted"], wifi(3, "secure"))
add(["network-wireless-acquiring"], wifi(3, dashed=True))
add(["network-wireless-disconnected", "network-wireless-offline", "network-wireless-off", "network-wireless-no-route"], wifi(0, off=True))
add(["network-wireless-hotspot"], wifi(3, "secure"))
# Wired, VPN, generic
add(["network-wired-activated", "network-wired", "network-wired-secure", "network-wired-available", "network-idle",
     "network-transmit-receive", "network-transmit", "network-receive", "network-connect"], wired(True))
add(["network-wired-acquiring"], wired(True, dashed=True))
add(["network-wired-disconnected", "network-wired-offline", "network-wired-unavailable", "network-offline",
     "network-unavailable", "network-error", "network-disconnect"], wired(False, off=True))
add(["network-wired-no-route", "network-limited"], wired(True, mark="limited"))
add(["network-vpn"], vpn(True))
add(["network-vpn-acquiring"], vpn(True, dashed=True))
# Volume and microphone
add(["audio-volume-high", "audio-volume-high-warning"], speaker(3))
add(["audio-volume-high-danger"], speaker(3, danger=True))
add(["audio-volume-medium"], speaker(2))
add(["audio-volume-low"], speaker(1))
add(["audio-volume-low-zero", "audio-volume-zero"], speaker(0))
add(["audio-volume-muted", "audio-volume-muted-blocking", "audio-volume-muted-blocked", "audio-volume-off", "audio-off"], speaker(0, muted=True))
add(["microphone-sensitivity-high"], mic(3))
add(["microphone-sensitivity-medium"], mic(2))
add(["microphone-sensitivity-low"], mic(1))
add(["microphone-sensitivity-muted"], mic(0, muted=True))
# Battery
PROFILES = ["", "-profile-balanced", "-profile-performance", "-profile-powersave"]
for pct in range(0, 101, 10):
    for prof in PROFILES:
        add([f"battery-{pct:03d}{prof}"], battery(pct))
        add([f"battery-{pct:03d}-charging{prof}"], battery(pct, charging=True))
for name, pct in [("battery-full", 100), ("battery-good", 70), ("battery-medium", 50), ("battery-low", 20),
                  ("battery-caution", 10), ("battery-empty", 0)]:
    add([name], battery(pct))
    add([name + "-charging"], battery(pct, charging=True))
add(["battery-100-charged", "battery-full-charged", "battery-charged", "battery_charged", "battery_plugged"], battery(100, charged=True))
add(["battery-missing"], battery(0, missing=True))
# Bluetooth, airplane
add(["bluetooth-active", "bluetooth-online", "bluetooth", "preferences-system-bluetooth", "network-bluetooth-activated", "network-bluetooth"], bluetooth(True))
add(["bluetooth-paired"], bluetooth(True, paired=True))
add(["bluetooth-disabled", "bluetooth-offline", "network-bluetooth-inactive"], bluetooth(False, off=True))
def bell(badge=False, off=False):
    cls = "Text" if off else "NeutralText"
    out = [stroke(cls, "M6,15.5 V10.5 A5,5 0 0 1 16,10.5 V15.5 L17.6,17.2 H4.4 Z", 1.5, 0.5 if off else 1.0),
           stroke(cls, "M9.2,19.2 A1.9,1.9 0 0 0 12.8,19.2", 1.5, 0.5 if off else 1.0),
           fill(cls, sdiamond(11, 4.4, 1.2), 0.5 if off else 1.0)]
    if badge:
        out.append(fill("Highlight", sdiamond(16.6, 6.4, 3.4)))
    if off:
        out.append(SLASH)
    return st("".join(out))


add(["notifications", "notification-inactive", "preferences-desktop-notification", "preferences-desktop-notification-bell"], bell())
add(["notification-active", "notification-new", "notifications-new"], bell(badge=True))
add(["notification-disabled", "notifications-disabled"], bell(off=True))
def sun(dim=False, crescent=False):
    import math
    op = 0.45 if dim else 1.0
    out = [fill("NeutralText", sdiamond(11, 11, 4.2), op)]
    for k in range(8):
        a = math.radians(k * 45)
        r1, r2 = 6.6, 9.4 if k % 2 == 0 else 8.4
        out.append(stroke("NeutralText", f"M{11 + r1 * math.cos(a):.2f},{11 + r1 * math.sin(a):.2f} L{11 + r2 * math.cos(a):.2f},{11 + r2 * math.sin(a):.2f}", 1.5, op))
    if crescent:
        out.append(fill("Highlight", "M17.6,13.2 A3.6,3.6 0 1 0 17.6,20.4 A2.8,2.8 0 1 1 17.6,13.2 Z"))
    return st("".join(out))


def moon(on=True):
    out = [fill("NeutralText" if on else "Text", "M13.6,3.4 A8,8 0 1 0 18.6,15.8 A6.4,6.4 0 1 1 13.6,3.4 Z", 1.0 if on else 0.45)]
    if on:
        out.append(fill("Highlight", sdiamond(16.6, 6.4, 2)))
    else:
        out.append(SLASH)
    return st("".join(out))


def media(kind, framed=True):
    out = []
    if framed:
        out.append(stroke("NeutralText", sdiamond(11, 11, 9.4), 1.3, 0.85))
    cls = "Highlight" if framed else "NeutralText"
    if kind == "play":
        out.append(fill(cls, "M8.4,6.6 L15.6,11 L8.4,15.4 Z"))
    elif kind == "pause":
        out.append(fill(cls, "M7.6,6.8 H10 V15.2 H7.6 Z M12,6.8 H14.4 V15.2 H12 Z"))
    elif kind == "stop":
        out.append(fill(cls, "M7.4,7.4 H14.6 V14.6 H7.4 Z"))
    elif kind == "next":
        out.append(fill(cls, "M5.6,6.6 L11.4,11 L5.6,15.4 Z M11.4,6.6 L17.2,11 L11.4,15.4 Z"))
    elif kind == "prev":
        out.append(fill(cls, "M16.4,6.6 L10.6,11 L16.4,15.4 Z M10.6,6.6 L4.8,11 L10.6,15.4 Z"))
    return st("".join(out))


add(["brightness-high", "brightness", "video-display-brightness", "display-brightness"], sun())
add(["brightness-low"], sun(dim=True))
add(["redshift-status-on"], moon(True))
add(["redshift-status-day"], sun(dim=True, crescent=True))
add(["redshift-status-off"], moon(False))
add(["media-playback-playing"], media("play"))
add(["media-playback-paused"], media("pause"))
add(["media-playback-stopped"], media("stop"))
add(["media-playback-start"], media("play", framed=False))
add(["media-playback-pause"], media("pause", framed=False))
add(["media-playback-stop"], media("stop", framed=False))
add(["media-skip-forward"], media("next", framed=False))
add(["media-skip-backward"], media("prev", framed=False))
add(["airplane-mode"], airplane(True))
add(["airplane-mode-off"], airplane(False))

for n, text in STATUS.items():
    write(f"scalable/status/{n}.svg", text)
print(f"{len(STATUS)} status icons")


# ------------------------------------------------------------------ file types (v3)
# Every mimetype name the inherited theme (Papirus-Dark) has gets a .hack "data tablet":
# a glass page with a folded corner, bronze rim, studs, a category accent bar, the
# category's glyph in a diamond, and the type's short name in gold. Exact names win
# over generic fallbacks in icon lookup, so each specific name must be shipped.

import re

PAPIRUS = os.path.expanduser("~/.local/share/icons/Papirus-Dark/64x64/mimetypes")


def g_grid():
    return '<path d="M-5,-4.5 H5 V4.5 H-5 Z M-5,-1.5 H5 M-5,1.5 H5 M-1.6,-4.5 V4.5 M1.8,-4.5 V4.5"/>'


def g_bars():
    return '<path d="M-5,4.5 H5 M-3.6,4.5 V0.5 M-0.4,4.5 V-3.5 M2.8,4.5 V-1.5"/>'


def g_book():
    return '<path d="M0,-3.6 C-2,-5 -4.2,-5 -5.4,-4.4 V4 C-4.2,3.4 -2,3.4 0,4.8 C2,3.4 4.2,3.4 5.4,4 V-4.4 C4.2,-5 2,-5 0,-3.6 Z M0,-3.6 V4.8"/>'


def g_box():
    return '<path d="M-5,-2.4 L0,-5 L5,-2.4 V3 L0,5.6 L-5,3 Z M-5,-2.4 L0,0.2 L5,-2.4 M0,0.2 V5.6"/>'


def g_disc():
    return '<circle cx="0" cy="0" r="5.2"/><circle cx="0" cy="0" r="1.4" fill="currentColor" stroke="none"/>'


def g_font():
    return ('<text x="0" y="3.8" text-anchor="middle" font-family="Noto Serif, serif" font-size="10" '
            'fill="currentColor" stroke="none">Aa</text>')


def g_diamond_dot():
    return '<path d="M0,-4.6 L4.6,0 L0,4.6 L-4.6,0 Z" fill="currentColor" fill-opacity="0.35"/>'


CATS = {
    #           glyph            accent
    "code":    (g_code(),        "#8fe3ff"),
    "doc":     (g_lines(),       GOLD_LIGHT),
    "sheet":   (g_grid(),        "#7fd6a8"),
    "slides":  (g_bars(),        "#ffb36b"),
    "book":    (g_book(),        "#ff8f8f"),
    "image":   (g_picture(),     "#7fd6a8"),
    "audio":   (g_note(),        "#d79bff"),
    "video":   (g_play(),        "#ff8f8f"),
    "archive": (g_stack(),       GOLD_LIGHT),
    "package": (g_box(),         GOLD_LIGHT),
    "disc":    (g_disc(),        "#8fe3ff"),
    "exec":    (g_letter("Ξ"),   "#8fe3ff"),
    "font":    (g_font(),        INK),
    "web":     (g_globe(),       "#8fe3ff"),
    "key":     (g_letter("Λ"),   GOLD_LIGHT),
    "game":    (g_pad(),         "#ff9fd0"),
    "design":  (g_letter("Δ"),   "#ffb36b"),
    "generic": (g_diamond_dot(), "#8d98b6"),
}

RULES = [
    ("sheet", r"wps-office-(xls|xlt|et)|kmymoney"),
    ("slides", r"wps-office-(dps|dpt|pot|pps|ppt)"),
    ("doc", r"wps-office-(wps|wpt|doc|dot)|^message-|^multipart-|ms-publisher|mswrite|applix-word|xopp|xoj"),
    ("book", r"cb7|cbt|cbr"),
    ("key", r"keepass|kdbx"),
    ("game", r"love-game|world-of-goo|gnonogram"),
    ("game", r"nintendo|gameboy|game-boy|wii|gamecube|genesis|megadrive|sega|snes|nes-rom|n64|wonderswan|"
             r"neo-?geo|atari|pce|pc-engine|virtual-boy|lynx|nds|3ds|gba|\brom\b|-rom$|\.rom$"),
    ("design", r"acad|dwg|dxf|kicad|openboardview|illustrator|afdesigner|gvdesign|scribus|visio|mxfile|"
               r"sweethome3d|blender|freecad|fcstd|\bstl\b|-stl$|3d|sketch|xara|coreldraw|krita|inkscape|librecad"),
    ("web", r"kml|kmz|gpx|oziexplorer|igc|nmea|ant\.fit|google-earth|geojson|osm"),
    ("audio", r"bitwig|ableton|flp|midi|tracker|shorten|-mod$|xm$|it$|ram$|realaudio"),
    ("video", r"realmedia|-asf$|wpl|flash\.movie|shockwave"),
    ("doc", r"ms-word|wordperfect|hwp|oasis-text|openoffice4-.*text|mbox|tnef|winhlp|chm|help"),
    ("sheet", r"ms-access|sqlite|\bdb\b|dbf|spss|mdb|database|fusiontable"),
    ("exec", r"wine|x-ms-|\bexe\b|-exe$|msi|bat$|cmd$|extension"),
    ("disc", r"vmware|squashfs|efi\.(img|iso)|x-content-|blank-cd|dvd|bluray"),
    ("code", r"mathematica|wolfram|matlab|maple|dart|wasm|cbor|relaxng|-pkix-|tcpdump|pcap"),
    ("image", r"^image-|x-image|-image-|^application-x-(krita|gimp|xcf|inkscape)|svg|photoshop|psd|raw"),
    ("audio", r"^audio-|x-audio|sound|music|playlist|mpegurl|ogg$"),
    ("video", r"^video-|x-video|matroska|mp4|webm|flv|avi|quicktime"),
    ("font", r"font|truetype|opentype|woff"),
    ("book", r"pdf|epub|djvu|ebook|mobi|comicbook|cbz|cbr|fictionbook|postscript"),
    ("sheet", r"spreadsheet|excel|calc|csv|sheet|tab-separated|gnumeric"),
    ("slides", r"presentation|powerpoint|impress|slides|keynote"),
    ("disc", r"iso9660|cd-image|disk-image|diskimage|vmdk|vdi|qcow|virtualbox|vbox|raw-disk|apple-diskimage"),
    ("package", r"\bdeb\b|-deb$|rpm|archlinux|flatpak|snap|appimage|package|java-archive|jar$|msi|apk|x-ruby-gem|python-wheel"),
    ("archive", r"zip|tar|7z|rar|xz|gzip|bzip|lzma|lzip|zstd|compress|cpio|-ar$|archive|cabinet|lha|arj|ace|stuffit"),
    ("key", r"cert|pkcs|pem|x509|pgp|gpg|keyring|ssh|key$|-key-|keystore"),
    ("exec", r"executable|sharedlib|sharedobject|-object$|elf|ms-dos|msdownload|x-desktop|desktop$|bytecode|dll|appliance"),
    ("web", r"html|xhtml|css|web|php|asp|jsp|url|link|torrent|bittorrent"),
    ("doc", r"msword|wordprocessing|opendocument\.text|text-plain|plain$|rtf|abiword|office-document|writer|"
            r"x-office-document|markdown|text-x-tex|latex|log$|readme|text-x-generic|txt|^text-x-changelog|document"),
    ("code", r"^text-|script|source|python|ruby|perl|java|json|yaml|toml|xml|sql|rust|golang|kotlin|swift|lua|"
             r"haskell|scala|csharp|cpp|c\+\+|chdr|csrc|makefile|cmake|qml|patch|diff|config|ini|x-ipynb|jupyter"),
]

LABELS = {
    "python": "PY", "python3": "PY", "rust": "RS", "javascript": "JS", "typescript": "TS", "csrc": "C",
    "c": "C", "chdr": "H", "c++src": "C++", "cpp": "C++", "c++hdr": "HPP", "java": "JAVA", "go": "GO",
    "shellscript": "SH", "sh": "SH", "json": "JSON", "yaml": "YML", "toml": "TOML", "xml": "XML",
    "html": "HTML", "css": "CSS", "markdown": "MD", "pdf": "PDF", "zip": "ZIP", "tar": "TAR",
    "compressed-tar": "TGZ", "7z-compressed": "7Z", "rar": "RAR", "iso9660-image": "ISO", "cd-image": "ISO",
    "deb": "DEB", "rpm": "RPM", "png": "PNG", "jpeg": "JPG", "gif": "GIF", "svg+xml": "SVG", "webp": "WEBP",
    "mpeg": "MP3", "mp3": "MP3", "flac": "FLAC", "ogg": "OGG", "wav": "WAV", "mp4": "MP4", "matroska": "MKV",
    "webm": "WEBM", "plain": "TXT", "sql": "SQL", "lua": "LUA", "ruby": "RB", "perl": "PL", "php": "PHP",
    "kotlin": "KT", "swift": "SWIFT", "qml": "QML", "cmake": "CMAKE", "makefile": "MAKE", "patch": "DIFF",
    "diff": "DIFF", "csv": "CSV", "epub+zip": "EPUB", "x-xz": "XZ", "xz": "XZ", "zstd": "ZST", "gzip": "GZ",
    "bzip": "BZ2", "executable": "EXE", "sharedlib": "SO", "msword": "DOC", "msexcel": "XLS",
    "ms-powerpoint": "PPT", "torrent": "TOR", "bittorrent": "TOR", "appimage": "APP", "flatpak": "PAK",
    "java-archive": "JAR", "desktop": "DESK", "ipynb+json": "IPY", "tex": "TEX", "log": "LOG",
    "spreadsheet": "XLS", "presentation": "PPT", "document": "DOC", "octet-stream": "BIN", "blender": "BLND",
    "cd-image": "ISO", "executable": "EXE", "generic": "",
}


def classify(name):
    for cat, pat in RULES:
        if re.search(pat, name):
            return cat
    return "generic"


def label_for(name):
    for key in sorted(LABELS, key=len, reverse=True):
        if name.endswith("-" + key) or name.endswith("." + key) or name.endswith("x-" + key):
            return LABELS[key]
    tail = re.split(r"[-.+]", name)[-1]
    tail = re.sub(r"^x", "", tail) if tail.startswith("x") and len(tail) > 3 else tail
    return tail[:4].upper() if tail and tail not in ("generic", "x") else ""


def tablet(glyph, accent, label):
    defs = (f'<linearGradient id="page" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{NAVY_TOP}"/><stop offset="1" stop-color="{NAVY}"/></linearGradient>')
    b = [f'<path d="M14,5 H40 L51,16 V59 H14 Z" fill="url(#page)" stroke="{GOLD}" stroke-width="1.5" stroke-linejoin="round"/>',
         f'<path d="M40,5 V16 H51" fill="#26346b" stroke="{GOLD}" stroke-width="1.2" stroke-linejoin="round"/>',
         f'<rect x="16.5" y="8" width="2.2" height="48" fill="{accent}" fill-opacity="0.85"/>']
    for x, y in [(14, 5), (14, 59), (51, 59)]:
        b.append(diamond(x, y, 2.4, fill=GOLD_LIGHT))
    cy = 27 if label else 32
    b.append(diamond(33, cy, 10.5, fill=NAVY_DEEP, stroke=CYAN, sw=1.2, op=0.9))
    b.append(f'<g transform="translate(33,{cy}) scale(0.78)" color="{accent}" fill="none" stroke="{accent}" '
             f'stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">{glyph}</g>')
    if label:
        size = 10 if len(label) <= 3 else 8.2
        b.append(f'<text x="33" y="52" text-anchor="middle" font-family="Noto Serif, serif" font-size="{size}" '
                 f'letter-spacing="0.6" fill="{GOLD_LIGHT}">{label}</text>')
    return svg(64, "".join(b), defs)


def tablet16(accent):
    b = [f'<path d="M3,1.5 H9.5 L13,5 V14.5 H3 Z" fill="{NAVY_TOP}" stroke="{GOLD}" stroke-width="1"/>',
         f'<rect x="4.4" y="3" width="1.4" height="10" fill="{accent}"/>',
         diamond(9, 9.5, 2.4, fill=accent)]
    return svg(16, "".join(b))


mime_names = sorted(f[:-4] for f in os.listdir(PAPIRUS) if f.endswith(".svg")) if os.path.isdir(PAPIRUS) else []
for extra in ["inode-directory", "text-x-generic", "application-x-generic", "unknown", "application-octet-stream", "x-office-document",
              "x-office-spreadsheet", "x-office-presentation", "package-x-generic", "audio-x-generic",
              "video-x-generic", "image-x-generic", "font-x-generic", "text-x-script", "application-x-executable"]:
    if extra not in mime_names:
        mime_names.append(extra)
cat_count = {}
for n in mime_names:
    if n in ("inode-directory", "inode-x-directory", "folder"):
        write(f"scalable/mimetypes/{n}.svg", folder(None))
        write(f"16x16/mimetypes/{n}.svg", folder16(CYAN))
        continue
    cat = classify(n)
    glyph, accent = CATS[cat]
    write(f"scalable/mimetypes/{n}.svg", tablet(glyph, accent, label_for(n) if cat != "generic" or n.count("-") > 1 else ""))
    write(f"16x16/mimetypes/{n}.svg", tablet16(accent))
    cat_count[cat] = cat_count.get(cat, 0) + 1
print(f"{len(mime_names)} file-type icons:", ", ".join(f"{k} {v}" for k, v in sorted(cat_count.items(), key=lambda kv: -kv[1])))

write("index.theme", """[Icon Theme]
Name=HelbaWorld
Comment=.hack (The World): glass folders with a bronze rim and diamond emblems; everything else from your icon theme
Inherits=Papirus-Dark,breeze-dark,hicolor
Example=folder
Directories=16x16/places,16x16/mimetypes,scalable/places,scalable/status,scalable/mimetypes

[16x16/places]
Context=Places
Size=16
Type=Fixed

[scalable/places]
Context=Places
Size=64
MinSize=16
MaxSize=512
Type=Scalable

[16x16/mimetypes]
Context=MimeTypes
Size=16
Type=Fixed

[scalable/mimetypes]
Context=MimeTypes
Size=64
MinSize=16
MaxSize=512
Type=Scalable

[scalable/status]
Context=Status
Size=22
MinSize=16
MaxSize=64
Type=Scalable
""")
print(f"{count} icons written to {OUT}")
