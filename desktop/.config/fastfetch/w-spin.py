#!/usr/bin/env python3
"""Turn a dotted theme W into the Arch A alongside Fastfetch.

--static prints the initial W and wordmark; --play ROWS_UP COLUMN rotates
the W twice into the Arch A, then twice back into the resting W. Both use the
active wh01s17 theme: accent for W, bright_foreground for A. Ctrl-C skips to W.
WH01S17_SPIN_SECONDS controls the duration (default 7.2 seconds).
"""

import argparse
import math
import os
import sys
import time

WIDTH, HEIGHT = 40, 20
DEFAULT_ACCENT = "84c959"
DEFAULT_FOREGROUND = "f3fbee"
REST_YAW = 0.0
FPS = 30
DEFAULT_DURATION = 7.2
# Braille gives a regular 2x4 dot grid per terminal cell, with no solid fill.
DOT_WIDTH, DOT_HEIGHT = WIDTH * 2, HEIGHT * 4
BRAILLE_BITS = ((0, 3), (1, 4), (2, 5), (6, 7))
BOXES_2D = (
    (88, 104, 168, 344), (216, 104, 296, 344),
    (344, 104, 424, 344), (152, 344, 232, 408), (280, 344, 360, 408),
)


def silhouette(x, y, logo):
    """Theme brand bars, or Arch's tapered silhouette with its open arch."""
    if logo == "w":
        sx, sy = x * 168 + 256, 256 - y * 168
        return any(x0 <= sx <= x1 and y0 <= sy <= y1
                   for x0, y0, x1, y1 in BOXES_2D)
    # Apex at y=1, flared base at -1. The asymmetric cuts distinguish Arch
    # from a generic letter A; the lower opening is a round arch.
    if not -1 <= y <= 1 or abs(x) > (1 - y) / 2:
        return False
    if y < -0.42 or (x / 0.245) ** 2 + ((y + 0.42) / 0.38) ** 2 < 1:
        if abs(x) < 0.245:
            return False
    if -0.63 < y < -0.48 and x > 0.56 + (-0.48 - y) * 2:
        return False
    if 0.32 < y < 0.48 and x < -0.13 - (y - 0.32) * 0.7:
        return False
    return True


def surface(logo):
    """Sample both faces and the thin edge of an extruded silhouette once."""
    points = []
    step = 1 / 38
    for iy in range(-38, 39):
        for ix in range(-38, 39):
            x, y = ix * step, iy * step
            if not silhouette(x, y, logo):
                continue
            points.extend(((x, y, -0.065, 0, 0, -1),
                           (x, y, 0.065, 0, 0, 1)))
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                if not silhouette(x + dx * step, y + dy * step, logo):
                    for iz in range(-2, 3):
                        points.append((x, y, iz * 0.0325, dx, dy, 0))
    return points


SURFACES = {logo: surface(logo) for logo in ("w", "arch")}


def render(yaw, accent, logo="w"):
    """Perspective-project lit surface dots, keeping the nearest per pixel."""
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(-0.08), math.sin(-0.08)
    pixels = {}
    for x, y, z, nx, ny, nz in SURFACES[logo]:
        vx, vz = cy * x + sy * z, -sy * x + cy * z
        vy, vz = cp * y - sp * vz, sp * y + cp * vz
        k = 3.8 / (3.8 + vz)
        px = round(DOT_WIDTH / 2 + vx * 33 * k)
        py = round(DOT_HEIGHT / 2 - vy * 33 * k)
        if not (0 <= px < DOT_WIDTH and 0 <= py < DOT_HEIGHT):
            continue
        previous = pixels.get((px, py))
        if previous is not None and previous[0] <= vz:
            continue
        nxx, nzz = cy * nx + sy * nz, -sy * nx + cy * nz
        nyy, nzz = cp * ny - sp * nzz, sp * ny + cp * nzz
        light = max(0.0, -0.35 * nxx + 0.45 * nyy - 0.82 * nzz)
        # Depth and a moving reflection shade the dots without changing hue.
        shine = 0.5 + 0.42 * light + 0.08 * math.cos(y * 2 + yaw)
        shine *= 1 - 0.12 * max(0.0, vz)
        pixels[(px, py)] = (vz, max(0.25, min(1.0, shine)))
    lines = []
    for row in range(HEIGHT):
        out, last = [], None
        for col in range(WIDTH):
            bits, values = 0, []
            for dy in range(4):
                for dx in range(2):
                    pixel = pixels.get((col * 2 + dx, row * 4 + dy))
                    if pixel:
                        bits |= 1 << BRAILLE_BITS[dy][dx]
                        values.append(pixel[1])
            if not bits:
                out.append(" ")
                continue
            intensity = sum(values) / len(values)
            # Quantize the lighting to limit escape sequences per frame.
            intensity = round(intensity * 16) / 16
            color = tuple(round(c * intensity) for c in accent)
            if color != last:
                out.append("\x1b[38;2;%d;%d;%dm" % color)
                last = color
            out.append(chr(0x2800 + bits))
        lines.append("".join(out) + "\x1b[0m")
    return lines


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


def theme_colors():
    """Read semantic colors from the active theme, with standalone fallbacks."""
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    palette = {}
    try:
        with open(os.path.join(state, "wh01s17/current/theme/colors.toml")) as colors:
            for line in colors:
                key, _, value = line.partition("=")
                if key.strip() in ("accent", "bright_foreground", "foreground"):
                    palette[key.strip()] = value.split('"')[1]
    except (OSError, IndexError):
        pass
    return palette


def parse_hex(value):
    value = value.lstrip("#")
    try:
        if len(value) != 6:
            raise ValueError("expected six hex digits")
        return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))
    except ValueError:
        return parse_hex(DEFAULT_ACCENT)


def ease_out(t):
    return t * t * t * (10 + t * (-15 + 6 * t))


def animation_frame(progress, accent, foreground):
    """Two turns W → A, pause on A, then two turns A → resting W.

    Swap silhouettes only at the last edge-on pose of each leg, so the new
    logo finishes facing forward and the rotation keeps the same direction.
    """
    if progress < 0.06:
        return render(REST_YAW, accent, "w")
    if progress < 0.46:
        turn = ease_out((progress - 0.06) / 0.40)
        angle = 4 * math.pi * turn
        if angle < 3.5 * math.pi:
            return render(angle, accent, "w")
        return render(angle - 4 * math.pi, foreground, "arch")
    if progress < 0.56:
        return render(REST_YAW, foreground, "arch")
    if progress < 0.96:
        turn = ease_out((progress - 0.56) / 0.40)
        angle = 4 * math.pi * turn
        if angle < 3.5 * math.pi:
            return render(angle, foreground, "arch")
        return render(angle - 4 * math.pi, accent, "w")
    return render(REST_YAW, accent, "w")


def play(rows_up, column, accent, foreground):
    try:
        duration = float(os.environ.get("WH01S17_SPIN_SECONDS", str(DEFAULT_DURATION)))
    except ValueError:
        duration = DEFAULT_DURATION
    if not math.isfinite(duration) or duration <= 0:
        duration = DEFAULT_DURATION
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
        deadline = start
        while True:
            progress = min(1.0, (time.monotonic() - start) / duration)
            draw(animation_frame(progress, accent, foreground))
            if progress >= 1.0:
                break
            # Drop missed frames instead of stretching the animation on slower CPUs.
            deadline += 1 / FPS
            now = time.monotonic()
            if deadline < now:
                deadline = now
            time.sleep(max(0.0, deadline - now))
    except KeyboardInterrupt:
        pass
    finally:
        draw(render(REST_YAW, accent, "w"))
        out.write("\x1b[?25h")
        out.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--static", action="store_true")
    mode.add_argument("--play", nargs=2, type=int, metavar=("ROWS_UP", "COLUMN"))
    parser.add_argument("--accent")
    parser.add_argument("--foreground", help="Arch color (default: theme bright_foreground)")
    parser.add_argument("--logo", choices=("w", "arch"), default="w",
                        help="logo to print in static mode")
    args = parser.parse_args()
    palette = theme_colors()
    accent = parse_hex(args.accent or palette.get("accent") or DEFAULT_ACCENT)
    foreground = parse_hex(args.foreground or palette.get("bright_foreground")
                           or palette.get("foreground") or DEFAULT_FOREGROUND)

    if args.static:
        color = accent if args.logo == "w" else foreground
        sys.stdout.write("\n".join(render(REST_YAW, color, args.logo) + wordmark(accent)) + "\n")
    else:
        play(*args.play, accent, foreground)


if __name__ == "__main__":
    main()
