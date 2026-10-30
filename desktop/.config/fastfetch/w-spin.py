#!/usr/bin/env python3
"""Spin the wh01s17 W as a 3D ASCII render, in the spirit of Codex's logo.

The W from brand/logo.svg (three bars joined by two feet) is extruded into
five boxes. Each frame casts one perspective ray per character cell, lights
the nearest face with a point light, fades it with depth, and maps the light
to an ASCII ramp tinted with the theme accent.

Usage:
    w-spin.py --static [--accent HEX]
        Print the resting frame and the "wh01s17 OS" wordmark below it, e.g.
        as Fastfetch's command-raw logo.
    w-spin.py --play ROWS_UP COLUMN [--accent HEX]
        Animate in place over a frame already on screen whose top-left corner
        is ROWS_UP rows above the cursor, at COLUMN (1-based), then come to
        rest on the --static frame. Ctrl-C skips to the resting frame.

The accent defaults to the active Omarchy theme's, then to the wh01s17 green.
WH01S17_SPIN_SECONDS sets the length of the spin (2.4 s by default).
"""

import argparse
import math
import os
import sys
import time

WIDTH, HEIGHT = 40, 20  # character cells left of Fastfetch's report
CELL_ASPECT = 2.0  # a terminal cell is about twice as tall as it is wide
RAMP = " .:-=+*#%@"

# logo.svg geometry (512 units): (x0, y0, x1, y1) of each bar and foot.
BOXES_2D = [
    (88, 104, 168, 344),
    (216, 104, 296, 344),
    (344, 104, 424, 344),
    (152, 344, 232, 408),
    (280, 344, 360, 408),
]
DEPTH = 64  # extrusion, in the same units

REST_YAW = math.radians(22)  # resting pose: turned enough to show depth
TILT = math.radians(-18)  # constant pitch so the top faces show
LEAN = math.radians(8)  # roll about the view axis: the W leans left, a backslant
TURNS = 1
DURATION = float(os.environ.get("WH01S17_SPIN_SECONDS", "2.4"))
FPS = 30

CAMERA = 2.6  # distance from the centre, in W extents: lower is more perspective
LIGHT = (-1.6, 1.8, -2.4)  # view-space point light, in W extents: upper left, in front
FOG = 0.35  # how much the far side of the W darkens
DEFAULT_ACCENT = "84c959"
WHITE = (0xF3, 0xFB, 0xEE)  # wh01s17 bright foreground, for rims and sheen
SHEEN = (0.80, 0.92)  # Blinn-Phong cosines where a face starts to and fully shines


def normalized(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v)


def boxes_3d():
    """The W as 3D boxes centred on the origin, y up, front face at -z."""
    xs = [x for b in BOXES_2D for x in (b[0], b[2])]
    ys = [y for b in BOXES_2D for y in (b[1], b[3])]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    return [
        ((x0 - cx, cy - y1, -DEPTH / 2), (x1 - cx, cy - y0, DEPTH / 2))
        for x0, y0, x1, y1 in BOXES_2D
    ]


BOXES = boxes_3d()


def matmul(a, b):
    return tuple(tuple(sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3)) for r in range(3))


def rotation(yaw):
    """Rows of the object-to-view rotation: yaw about y, pitch, then lean."""
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(TILT), math.sin(TILT)
    cr, sr = math.cos(LEAN), math.sin(LEAN)
    spin = ((cy, 0.0, sy), (0.0, 1.0, 0.0), (-sy, 0.0, cy))
    pitch = ((1.0, 0.0, 0.0), (0.0, cp, -sp), (0.0, sp, cp))
    roll = ((cr, -sr, 0.0), (sr, cr, 0.0), (0.0, 0.0, 1.0))
    return matmul(roll, matmul(pitch, spin))


EXTENT = math.sqrt(sum(max(abs(p[i]) for b in BOXES for p in b) ** 2 for i in range(3)))
EYE = (0.0, 0.0, -CAMERA * EXTENT)  # view space, looking along +z


def to_view(m, v):
    return tuple(sum(m[r][i] * v[i] for i in range(3)) for r in range(3))


def to_object(m, v):
    return tuple(sum(m[r][i] * v[r] for r in range(3)) for i in range(3))


def fit_scale():
    """Image-plane units per cell column, so the W fits the frame at every yaw."""
    corners = [
        (x, y, z)
        for lo, hi in BOXES
        for x in (lo[0], hi[0])
        for y in (lo[1], hi[1])
        for z in (lo[2], hi[2])
    ]
    half_w = half_h = 0.0
    for step in range(72):
        m = rotation(2 * math.pi * step / 72)
        for c in corners:
            x, y, z = to_view(m, c)
            k = -EYE[2] / (z - EYE[2])  # projection onto the z = 0 image plane
            half_w = max(half_w, abs(x * k))
            half_h = max(half_h, abs(y * k))
    return max(2 * half_w * 1.04 / WIDTH, 2 * half_h * 1.06 / (HEIGHT * CELL_ASPECT))


SCALE = fit_scale()


def hit(origin, direction):
    """Nearest (point, normal) where the object-space ray meets a box, or None."""
    best = None
    for lo, hi in BOXES:
        t0, t1, axis, sign = -math.inf, math.inf, 0, 0.0
        for a in range(3):
            o, d = origin[a], direction[a]
            if abs(d) < 1e-9:
                if o < lo[a] or o > hi[a]:
                    break
                continue
            ta, tb = (lo[a] - o) / d, (hi[a] - o) / d
            s = -1.0
            if ta > tb:
                ta, tb, s = tb, ta, 1.0
            if ta > t0:
                t0, axis, sign = ta, a, s
            t1 = min(t1, tb)
            if t0 > t1:
                break
        else:
            if t0 > 0 and (best is None or t0 < best[0]):
                normal = [0.0, 0.0, 0.0]
                normal[axis] = sign
                best = (t0, tuple(normal))
    if best is None:
        return None
    return tuple(origin[i] + best[0] * direction[i] for i in range(3)), best[1]


def inside(point):
    return any(all(lo[i] <= point[i] <= hi[i] for i in range(3)) for lo, hi in BOXES)


def on_rim(point):
    """Whether a front-face point lies within a row of an exposed top edge."""
    above = (point[0], point[1] + SCALE * CELL_ASPECT, point[2] + 1e-6)
    return not inside(above)


def render(yaw, accent):
    """Return the frame as HEIGHT strings of truecolor ASCII."""
    m = rotation(yaw)
    origin = to_object(m, EYE)
    lamp = tuple(c * EXTENT for c in LIGHT)
    cells = []
    for row in range(HEIGHT):
        vy = (HEIGHT / 2 - row - 0.5) * SCALE * CELL_ASPECT
        line = []
        for col in range(WIDTH):
            vx = (col + 0.5 - WIDTH / 2) * SCALE
            direction = to_object(m, normalized((vx, vy, -EYE[2])))
            line.append(hit(origin, direction))
        cells.append(line)

    front = (0.0, 0.0, -1.0)
    lines = []
    for row in range(HEIGHT):
        out, last = [], None
        for col in range(WIDTH):
            if cells[row][col] is None:
                out.append(" ")
                continue
            point, n = cells[row][col]
            at = to_view(m, point)
            view_n = to_view(m, n)
            light = normalized(tuple(lamp[i] - at[i] for i in range(3)))
            eye = normalized(tuple(EYE[i] - at[i] for i in range(3)))
            lambert = max(0.0, sum(view_n[i] * light[i] for i in range(3)))
            far = min(1.0, max(0.0, (at[2] + EXTENT) / (2 * EXTENT)))
            v = min(1.0, 0.2 + 1.0 * lambert) * (1 - FOG * far)
            ch = RAMP[min(len(RAMP) - 1, max(1, int(v * (len(RAMP) - 1) + 0.5)))]
            color = shade(accent, v)
            # White details: the top rim of the front face, and a sheen that
            # slides over each face as it turns through the light's reflection.
            if n == front and on_rim(point):
                color = WHITE
            else:
                half = normalized(tuple(light[i] + eye[i] for i in range(3)))
                spec = sum(view_n[i] * half[i] for i in range(3))
                k = 0.6 * min(1.0, max(0.0, (spec - SHEEN[0]) / (SHEEN[1] - SHEEN[0]))) ** 2
                color = tuple(int(c + (w - c) * k) for c, w in zip(color, WHITE))
            if color != last:
                out.append("\x1b[38;2;%d;%d;%dm" % color)
                last = color
            out.append(ch)
        lines.append("".join(out) + "\x1b[0m")
    return lines


def shade(accent, v):
    """Accent darkened in shadow and lifted toward white in full light."""
    if v < 0.75:
        k = 0.35 + 0.65 * v / 0.75
        return tuple(int(c * k) for c in accent)
    w = (v - 0.75) / 0.25 * 0.45
    return tuple(int(c + (255 - c) * w) for c in accent)


# The 5x7 pixel glyphs of the theme's pixel-art wallpapers (sources/pixel-art.py).
GLYPHS = {
    "w": [".....", ".....", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
    "h": ["#....", "#....", "#.##.", "##..#", "#...#", "#...#", "#...#"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "s": [".....", ".....", ".####", "#....", ".###.", "....#", "####."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    " ": ["...."] * 7,  # with the glyph gaps, a word space of six pixels
}
WORDMARK = "wh01s17 OS"
LETTERS = (0xCB, 0xD5, 0xCE)  # wh01s17 foreground; digits take the accent

# Octants split a cell into 2x4 square pixels. Unicode only encodes the
# patterns that no older block character already draws; these are the rest.
# Bit i is the pixel at row i // 2, column i % 2.
OCTANT_OLD = {
    0b00000000: " ",
    0b00000001: "\U0001cea8",
    0b00000010: "\U0001ceab",
    0b00000011: "\U0001fb82",
    0b00000101: "\u2598",
    0b00001010: "\u259d",
    0b00001111: "\u2580",
    0b00010100: "\U0001fbe6",
    0b00101000: "\U0001fbe7",
    0b00111111: "\U0001fb85",
    0b01000000: "\U0001cea3",
    0b01010000: "\u2596",
    0b01010101: "\u258c",
    0b01011010: "\u259e",
    0b01011111: "\u259b",
    0b10000000: "\U0001cea0",
    0b10100000: "\u2597",
    0b10100101: "\u259a",
    0b10101010: "\u2590",
    0b10101111: "\u259c",
    0b11000000: "\u2582",
    0b11110000: "\u2584",
    0b11110101: "\u2599",
    0b11111010: "\u259f",
    0b11111100: "\u2586",
    0b11111111: "\u2588",
}


def octant(bits):
    """The block character that lights the pixels in `bits`."""
    if bits in OCTANT_OLD:
        return OCTANT_OLD[bits]
    # U+1CD00 onwards lists the remaining patterns in increasing order.
    index = sum(1 for b in range(bits) if b not in OCTANT_OLD)
    return chr(0x1CD00 + index)


def wordmark(accent):
    """WORDMARK in octant pixels, centred in WIDTH cells; letters light, digits accent."""
    pixels, x = {}, 0
    for ch in WORDMARK:
        color = accent if ch.isdigit() else LETTERS
        for row, line in enumerate(GLYPHS[ch]):
            for col, bit in enumerate(line):
                if bit == "#":
                    pixels[(x + col, row)] = color
        x += len(GLYPHS[ch][0]) + 1
    cols = (x - 1 + 1) // 2
    pad = " " * ((WIDTH - cols) // 2)
    lines = []
    for top in (0, 4):
        out, last = [pad], None
        for c in range(cols):
            bits, color = 0, None
            for i in range(8):
                px = pixels.get((2 * c + i % 2, top + i // 2))
                if px:
                    bits |= 1 << i
                    color = px
            if color and color != last:
                out.append("\x1b[38;2;%d;%d;%dm" % color)
                last = color
            out.append(octant(bits))
        lines.append("".join(out).rstrip() + "\x1b[0m")
    return lines


def theme_accent():
    """The accent declared by the active Omarchy theme, or None."""
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    try:
        with open(os.path.join(state, "omarchy/current/theme/colors.toml")) as colors:
            for line in colors:
                key, _, value = line.partition("=")
                if key.strip() == "accent":
                    return value.strip().strip('"')
    except OSError:
        pass
    return None


def parse_hex(value):
    value = value.lstrip("#")
    try:
        return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))
    except ValueError:
        return parse_hex(DEFAULT_ACCENT)


def ease_out(t):
    return 1 - (1 - t) ** 3


def play(rows_up, column, accent):
    frames = max(1, int(DURATION * FPS))
    try:
        rows = os.get_terminal_size(sys.stdout.fileno()).lines
    except OSError:
        rows = HEIGHT + rows_up
    # Rows that scrolled above the screen cannot be reached; skip them.
    skip = max(0, rows_up - (rows - 1))
    if skip >= HEIGHT:
        return

    out = sys.stdout
    out.write("\x1b[?25l\x1b7")

    def draw(lines):
        buf = ["\x1b8"]
        if rows_up - skip:
            buf.append("\x1b[%dA" % (rows_up - skip))
        for i, line in enumerate(lines[skip:]):
            if i:
                buf.append("\x1b[1B")
            buf.append("\x1b[%dG\x1b[%dX%s" % (column, WIDTH, line))
        buf.append("\x1b8")
        out.write("".join(buf))
        out.flush()

    try:
        start = time.monotonic()
        for i in range(1, frames + 1):
            t = ease_out(i / frames)
            draw(render(REST_YAW - 2 * math.pi * TURNS * (1 - t), accent))
            delay = start + i / FPS - time.monotonic()
            if delay > 0:
                time.sleep(delay)
    except KeyboardInterrupt:
        pass
    finally:
        draw(render(REST_YAW, accent))
        out.write("\x1b[?25h")
        out.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--static", action="store_true")
    mode.add_argument("--play", nargs=2, type=int, metavar=("ROWS_UP", "COLUMN"))
    parser.add_argument("--accent")
    args = parser.parse_args()
    accent = parse_hex(args.accent or theme_accent() or DEFAULT_ACCENT)

    if args.static:
        sys.stdout.write("\n".join(render(REST_YAW, accent) + wordmark(accent)) + "\n")
    else:
        play(*args.play, accent)


if __name__ == "__main__":
    main()
