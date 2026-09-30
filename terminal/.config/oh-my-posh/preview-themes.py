#!/usr/bin/env python3
"""Show the effective official and Omarchy prompts side by side in fzf."""

from __future__ import annotations

import argparse
import itertools
import re
import subprocess
import unicodedata


ESCAPE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\))")
RESET = "\x1b]8;;\x1b\\\x1b[0m"


def cell_width(character: str) -> int:
    if unicodedata.combining(character) or unicodedata.category(character) in {"Cc", "Cf"}:
        return 0
    return 2 if unicodedata.east_asian_width(character) in {"F", "W"} else 1


def fit(line: str, limit: int) -> tuple[str, int]:
    """Clip a colored line without counting ANSI sequences as terminal cells."""
    pieces = []
    width = 0
    position = 0
    for match in ESCAPE.finditer(line):
        for character in line[position : match.start()]:
            size = cell_width(character)
            if width + size > limit:
                return "".join(pieces) + RESET, width
            pieces.append(character)
            width += size
        pieces.append(match.group())
        position = match.end()
    for character in line[position:]:
        size = cell_width(character)
        if width + size > limit:
            break
        pieces.append(character)
        width += size
    return "".join(pieces) + RESET, width


def preview(config: str, pwd: str) -> list[str]:
    rendered = subprocess.run(
        ["oh-my-posh", "print", "preview", "--config", config, "--pwd", pwd],
        check=True, capture_output=True, text=True,
    )
    return rendered.stdout.splitlines()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original", required=True)
    parser.add_argument("--omarchy", required=True)
    parser.add_argument("--pwd", required=True)
    parser.add_argument("--columns", type=int, default=120)
    args = parser.parse_args()
    half = max(12, (args.columns - 3) // 2)
    left = preview(args.original, args.pwd)
    right = preview(args.omarchy, args.pwd)
    print(f"{'OFICIAL':<{half}} │ OMARCHY")
    print(f"{'─' * half}─┼─{'─' * half}")
    for original, themed in itertools.zip_longest(left, right, fillvalue=""):
        original_text, original_width = fit(original, half)
        themed_text, _ = fit(themed, half)
        print(f"{original_text}{' ' * (half - original_width)} │ {themed_text}")


if __name__ == "__main__":
    main()
