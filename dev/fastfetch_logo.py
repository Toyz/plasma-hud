#!/usr/bin/env python3
"""Draw the Chaos Gate sigil as braille art for the fastfetch logo.

    python3 dev/fastfetch_logo.py [gate|bracelet|drain] [out.txt]
        (default: drain -> packages/fastfetch/helba-world.txt)

Braille cells are 2x4 dots, so circles come out round. Each character takes the color
of the most important element among its dots, written as fastfetch $N codes:
$1 gold (yellow), $2 cyan, $3 dim (blue), $4 bright core (white).
"""
import math
import os
import sys

COLS, ROWS = 30, 15                 # characters
W, H = COLS * 2, ROWS * 4           # dots
CX, CY = W / 2 - 0.5, H / 2 - 0.5

# element -> (priority, color code)
CORE, NODE, DIAMOND, RING, TICK, INNER, SPOKE = range(7)
STYLE = {CORE: (7, "4"), NODE: (6, "2"), DIAMOND: (5, "2"), RING: (4, "1"),
         TICK: (3, "1"), INNER: (2, "3"), SPOKE: (1, "3")}

R_OUT, R_IN = 28.5, 20.5
NODE_ANGLES = [k * math.pi / 4 for k in range(8)]


def gate(x, y):
    """The Chaos Gate: rune ring, dashed inner ring, spokes, center diamond."""
    dx, dy = x - CX, y - CY
    r = math.hypot(dx, dy)
    a = math.atan2(dy, dx) % (2 * math.pi)
    hits = []
    # Bright core: a small filled diamond.
    if abs(dx) + abs(dy) <= 3.2:
        hits.append(CORE)
    # Center diamond outline, cyan.
    d = abs(dx) + abs(dy)
    if 10.0 <= d <= 11.6:
        hits.append(DIAMOND)
    # Rune nodes on the outer ring: hollow diamonds.
    for na in NODE_ANGLES:
        nx, ny = CX + R_OUT * math.cos(na), CY + R_OUT * math.sin(na)
        nd = abs(x - nx) + abs(y - ny)
        if 2.2 <= nd <= 3.9 or nd <= 0.8:
            hits.append(NODE)
    # Outer ring, broken around each node.
    near_node = min(abs((a - na + math.pi) % (2 * math.pi) - math.pi) for na in NODE_ANGLES) * R_OUT
    if abs(r - R_OUT) <= 1.3 and near_node > 5.0:
        hits.append(RING)
    # Ticks just outside the ring, halfway between nodes.
    for k in range(8):
        ta = (k + 0.5) * math.pi / 4
        if abs((a - ta + math.pi) % (2 * math.pi) - math.pi) * r < 0.9 and R_OUT + 1.5 <= r <= R_OUT + 3.5:
            hits.append(TICK)
    # Inner ring, dashed.
    if abs(r - R_IN) <= 0.8 and (a * R_IN) % 6.0 < 3.6:
        hits.append(INNER)
    # Diagonal spokes from the diamond to the inner ring, dotted.
    for k in range(4):
        sa = math.pi / 4 + k * math.pi / 2
        along = dx * math.cos(sa) + dy * math.sin(sa)
        across = -dx * math.sin(sa) + dy * math.cos(sa)
        if abs(across) < 0.7 and 8.5 <= along <= R_IN - 1.5 and int(along) % 3 != 0:
            hits.append(SPOKE)
    return hits


def tri_edge(px, py, verts, w):
    """Distance-ish test: is (px, py) within w of the triangle's outline?"""
    best = 1e9
    for i in range(3):
        (ax, ay), (bx, by) = verts[i], verts[(i + 1) % 3]
        vx, vy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy)))
        best = min(best, math.hypot(px - ax - t * vx, py - ay - t * vy))
    return best <= w


def in_tri(px, py, verts):
    (ax, ay), (bx, by), (cx, cy) = verts
    d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
    d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
    d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)


def bracelet(x, y):
    """The Twilight Bracelet: the band at an angle, the jewel in front, drain rays above."""
    hits = []
    cx, cy = CX, CY + 9
    rx, ry = 27.0, 11.0
    # Band: two ellipse edges (outer gold, inner dim) with segment marks between.
    e_out = math.hypot((x - cx) / rx, (y - cy) / ry)
    e_in = math.hypot((x - cx) / (rx - 4.5), (y - cy - 1.2) / (ry - 3.0))
    if abs(e_out - 1.0) < 0.045:
        hits.append(RING)
    if abs(e_in - 1.0) < 0.06:
        hits.append(INNER if y < cy else RING)
    if e_out < 1.0 and e_in > 1.0:
        a = math.atan2((y - cy) / ry, (x - cx) / rx)
        if abs(((a / (math.pi / 8)) % 1.0) - 0.5) > 0.44:
            hits.append(TICK)
    # Jewel at the front of the band: inverted triangle, eye in the middle.
    jy = cy + ry - 1.5
    jewel = [(cx - 8.5, jy - 6.5), (cx + 8.5, jy - 6.5), (cx, jy + 6.5)]
    if tri_edge(x, y, jewel, 0.8):
        hits.append(DIAMOND)
    if in_tri(x, y, jewel) and not tri_edge(x, y, jewel, 0.8):
        hits = [h for h in hits if h not in (RING, INNER, TICK)]
    eye = math.hypot((x - cx) / 3.2, (y - (jy - 2.2)) / 1.8)
    if eye <= 1.0:
        hits.append(CORE)
    # Drain rays: three beams fanning up from the jewel, dotted, brighter near it.
    for k, ang in enumerate((-0.42, 0.0, 0.42)):
        ox, oy = cx, jy - 7.5
        dx, dy = x - ox, y - oy
        along = -dy * math.cos(ang) + dx * math.sin(ang)
        across = dx * math.cos(ang) + dy * math.sin(ang)
        if 2.0 < along < 34.0 and abs(across) < 0.6 + along * 0.02 and int(along) % 4 != 0:
            hits.append(NODE if along < 9 else SPOKE)
    return hits


def drain(x, y):
    """The Data Drain sigil: three crescent blades turning around a triangle core."""
    hits = []
    dx, dy = x - CX, y - CY
    r = math.hypot(dx, dy)
    for k in range(3):
        a = -math.pi / 2 + k * 2 * math.pi / 3
        # Each blade: inside one circle, outside another offset along the swirl.
        c1 = (CX + 13.0 * math.cos(a), CY + 13.0 * math.sin(a))
        c2 = (CX + 13.0 * math.cos(a + 0.55) + 2.0 * math.cos(a), CY + 13.0 * math.sin(a + 0.55) + 2.0 * math.sin(a))
        d1 = math.hypot(x - c1[0], y - c1[1])
        d2 = math.hypot(x - c2[0], y - c2[1])
        inside = d1 < 15.0 and d2 > 13.0 and r > 9.5
        if inside:
            edge = d1 > 13.6 or d2 < 14.4 or r < 10.9
            hits.append(RING if edge else (SPOKE if (int(x) + int(y)) % 3 == 0 else None))
    hits = [h for h in hits if h is not None]
    # Triangle core, point up, and the light inside it.
    tri = [(CX, CY - 8.5), (CX + 7.4, CY + 4.3), (CX - 7.4, CY + 4.3)]
    if tri_edge(x, y, tri, 0.75):
        hits.append(DIAMOND)
    if math.hypot(dx, dy - 0.5) <= 2.2:
        hits.append(CORE)
    # Faint dashed outer ring with three nodes between the blades.
    if abs(r - 28.5) <= 0.7 and (math.atan2(dy, dx) * 28.5) % 5.0 < 2.6:
        hits.append(INNER)
    for k in range(3):
        a = math.pi / 2 + k * 2 * math.pi / 3
        nx, ny = CX + 28.5 * math.cos(a), CY + 28.5 * math.sin(a)
        nd = abs(x - nx) + abs(y - ny)
        if 1.8 <= nd <= 3.4 or nd <= 0.7:
            hits.append(NODE)
    return hits


DESIGNS = {"gate": gate, "bracelet": bracelet, "drain": drain}
element = drain


# Braille dot bit for (col, row) inside a 2x4 cell.
BITS = {(0, 0): 0x01, (0, 1): 0x02, (0, 2): 0x04, (1, 0): 0x08,
        (1, 1): 0x10, (1, 2): 0x20, (0, 3): 0x40, (1, 3): 0x80}


def render():
    lines = []
    for row in range(ROWS):
        out, cur = [], None
        for col in range(COLS):
            bits, best = 0, None
            for (bx, by), bit in BITS.items():
                hits = element(col * 2 + bx, row * 4 + by)
                if hits:
                    bits |= bit
                    top = max(hits, key=lambda e: STYLE[e][0])
                    if best is None or STYLE[top][0] > STYLE[best][0]:
                        best = top
            if bits:
                code = STYLE[best][1]
                if code != cur:
                    out.append("$" + code)
                    cur = code
                out.append(chr(0x2800 + bits))
            else:
                out.append(" ")
        lines.append("".join(out).rstrip())
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    element = DESIGNS[sys.argv[1] if len(sys.argv) > 1 else "drain"]
    dest = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "../packages/fastfetch/helba-world.txt")
    open(dest, "w").write(render())
    print("wrote", dest)
