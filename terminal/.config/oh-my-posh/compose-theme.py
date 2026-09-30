#!/usr/bin/env python3
"""Build a small Oh My Posh config that extends an untouched local theme."""

from __future__ import annotations

import argparse
import colorsys
import copy
import json
import re
import shutil
import subprocess
import tomllib
from pathlib import Path


HERE = Path(__file__).resolve().parent
OVERLAY = HERE / "functional-overlay.json"
SCHEMA = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json"
RUNTIMES = {"python", "node", "go", "rust", "java", "php", "ruby", "flutter", "lua", "perl", "haskell"}
ANSI_NAMES = (
    "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
    "darkGray", "lightRed", "lightGreen", "lightYellow", "lightBlue",
    "lightMagenta", "lightCyan", "lightWhite",
)
HEX_COLOR = re.compile(r"#[0-9a-fA-F]{6}(?![0-9a-fA-F])|#[0-9a-fA-F]{3}(?![0-9a-fA-F])")
COLOR_KEYS = {
    "foreground", "background", "foreground_templates", "background_templates",
    "accent_color", "terminal_background", "cycle", "color", "colors",
}
MARKUP_KEYS = {
    "template", "templates", "filler", "leading_diamond", "trailing_diamond",
    "powerline_symbol", "console_title_template",
}


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return value


def append_template(original: str, addition: str) -> str:
    ending = original[len(original.rstrip()) :]
    return original.rstrip() + addition + ending


def read_omarchy_palette(path: Path) -> tuple[dict[str, str], str]:
    """Read Kitty's current colors; ANSI names keep following future Omarchy themes."""
    colors = {}
    accent = None
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] == "active_border_color" and HEX_COLOR.fullmatch(parts[1]):
            accent = parts[1]
        if len(parts) >= 2 and parts[0].startswith("color") and parts[0][5:].isdigit():
            number = int(parts[0][5:])
            if 0 <= number < 16 and HEX_COLOR.fullmatch(parts[1]):
                colors[ANSI_NAMES[number]] = parts[1]
    if len(colors) != 16:
        raise ValueError(f"{path}: expected all 16 Kitty ANSI colors")
    colors_file = path.with_name("colors.toml")
    if colors_file.is_file():
        configured_accent = tomllib.loads(colors_file.read_text(encoding="utf-8")).get("accent")
        if isinstance(configured_accent, str) and HEX_COLOR.fullmatch(configured_accent):
            accent = configured_accent
    return colors, accent or colors["green"]


def rgb(color: str) -> tuple[int, int, int]:
    digits = color.lstrip("#")
    if len(digits) == 3:
        digits = "".join(character * 2 for character in digits)
    return tuple(int(digits[i : i + 2], 16) for i in (0, 2, 4))


def lab(color: str) -> tuple[float, float, float]:
    channels = [value / 255 for value in rgb(color)]
    linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
    x = (0.4124 * linear[0] + 0.3576 * linear[1] + 0.1805 * linear[2]) / 0.95047
    y = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    z = (0.0193 * linear[0] + 0.1192 * linear[1] + 0.9505 * linear[2]) / 1.08883
    transform = lambda value: value ** (1 / 3) if value > 0.008856 else 7.787 * value + 16 / 116
    fx, fy, fz = map(transform, (x, y, z))
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def recolor(config: dict, kitty_colors: dict[str, str], accent_color: str) -> dict:
    """Replace color values structurally while keeping symbols and layout intact."""
    lab_colors = {name: lab(value) for name, value in kitty_colors.items()}
    source_palette = config.get("palette", {})

    def source_color(value: str) -> str | None:
        for _ in range(3):
            if isinstance(value, str) and value.startswith("p:"):
                value = source_palette.get(value[2:], "")
            else:
                break
        return value if isinstance(value, str) and HEX_COLOR.fullmatch(value) else None

    hues = []
    for block in config.get("blocks", []):
        for segment in block.get("segments", []):
            semantic = segment.get("type") in {"status", "root", "battery", "executiontime"}
            for role, weight in (("background", 3.0), ("foreground", 1.0 if segment.get("background") else 2.0)):
                color = source_color(segment.get(role))
                if not color:
                    continue
                hue, saturation, _ = colorsys.rgb_to_hsv(*(channel / 255 for channel in rgb(color)))
                if saturation >= 0.22 and lab(color)[0] >= 30:
                    hues.append((hue * 360, weight * (0.2 if semantic else 1.0)))

    def hue_distance(first: float, second: float) -> float:
        distance = abs(first - second)
        return min(distance, 360 - distance)

    dominant = max(hues, key=lambda item: sum(weight for hue, weight in hues if hue_distance(hue, item[0]) <= 55))[0] if hues else None
    accent_lab = lab(accent_color)
    chromatic = [name for name in kitty_colors if name not in {"black", "darkGray", "white", "lightWhite"}]
    accent_name = min(chromatic, key=lambda name: sum((a - b) ** 2 for a, b in zip(accent_lab, lab_colors[name])))
    base_accent = accent_name[5].lower() + accent_name[6:] if accent_name.startswith("light") else accent_name
    light_accent = "light" + base_accent[0].upper() + base_accent[1:]

    def nearest(color: str, gradient: bool) -> str:
        point = lab(color)
        hue, saturation, _ = colorsys.rgb_to_hsv(*(channel / 255 for channel in rgb(color)))
        if dominant is not None and saturation >= 0.22 and point[0] >= 30 and hue_distance(hue * 360, dominant) <= 65:
            name = light_accent if point[0] >= 75 and light_accent in kitty_colors else accent_name
        else:
            name = min(lab_colors, key=lambda candidate: sum((a - b) ** 2 for a, b in zip(point, lab_colors[candidate])))
        # Gradients require hex stops in Oh My Posh; other ANSI names remain dynamic.
        return kitty_colors[name] if gradient else name

    def replace_colors(value: str, markup_only: bool) -> str:
        gradient = "gradient(" in value
        if markup_only:
            return re.sub(r"<[^<>]+>", lambda match: HEX_COLOR.sub(lambda color: nearest(color.group(), gradient), match.group()), value)
        return HEX_COLOR.sub(lambda match: nearest(match.group(), gradient), value)

    def walk(value: object, key: str = "") -> object:
        if isinstance(value, dict):
            return {name: walk(item, "palette_value" if name == "palette" else name if key != "palette_value" else "palette_value")
                    for name, item in value.items()}
        if isinstance(value, list):
            return [walk(item, key) for item in value]
        if isinstance(value, str):
            if key in COLOR_KEYS or key == "palette_value" or key.endswith("_color"):
                return replace_colors(value, False)
            if key in MARKUP_KEYS:
                return replace_colors(value, True)
            if "<" in value and HEX_COLOR.search(value):
                return replace_colors(value, True)
        return value

    themed = walk(config)

    def luminance(color: str) -> float:
        channels = [value / 255 for value in rgb(color)]
        linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

    def resolved(value: str) -> str | None:
        if not isinstance(value, str):
            return None
        for _ in range(3):
            if value.startswith("p:"):
                value = themed.get("palette", {}).get(value[2:], "")
            else:
                break
        if value in kitty_colors:
            return kitty_colors[value]
        return value if HEX_COLOR.fullmatch(value) else None

    for block in themed.get("blocks", []):
        for segment in block.get("segments", []):
            foreground = resolved(segment.get("foreground", ""))
            background = resolved(segment.get("background", ""))
            if not foreground or not background:
                continue
            light, dark = sorted((luminance(foreground), luminance(background)), reverse=True)
            if (light + 0.05) / (dark + 0.05) >= 4.5:
                continue
            background_lightness = luminance(background)
            segment["foreground"] = max(
                ("black", "lightWhite"),
                key=lambda name: (max(luminance(kitty_colors[name]), background_lightness) + 0.05)
                / (min(luminance(kitty_colors[name]), background_lightness) + 0.05),
            )
    return themed


def stabilize_added_segments(exported: dict, overrides: dict) -> dict:
    """Keep functional additions in overlay order after Oh My Posh resolves extends."""
    for override in overrides.get("blocks", []):
        index = override.get("index")
        if not isinstance(index, int) or index < 1 or index > len(exported.get("blocks", [])):
            continue
        aliases = [segment["alias"] for segment in override.get("segments", []) if segment.get("alias", "").startswith("Functional")]
        if not aliases:
            continue
        segments = exported["blocks"][index - 1]["segments"]
        added = {segment.get("alias"): segment for segment in segments if segment.get("alias") in aliases}
        exported["blocks"][index - 1]["segments"] = (
            [segment for segment in segments if segment.get("alias") not in added]
            + [added[alias] for alias in aliases if alias in added]
        )
    return exported


def compose(base: dict, rules: dict, extends: str, pure_local: bool) -> dict:
    blocks = base.get("blocks")
    if not isinstance(blocks, list) or not blocks:
        raise ValueError("The base theme has no prompt blocks")

    result: dict = {"$schema": SCHEMA, "version": 4, "extends": extends}
    if not base.get("streaming") and not base.get("async"):
        result["streaming"] = rules["streaming_ms"]
    if pure_local:
        return result

    result["transient_prompt"] = copy.deepcopy(rules["transient_prompt"])
    changes: dict[int, dict] = {}

    def block_change(index: int) -> dict:
        if index not in changes:
            block = blocks[index]
            changes[index] = {
                "index": index + 1,
                "type": block.get("type", "prompt"),
            }
            if "alignment" in block:
                changes[index]["alignment"] = block["alignment"]
        return changes[index]

    def segment_change(block_index: int, segment_index: int) -> dict:
        block = block_change(block_index)
        overrides = block.setdefault("segments", [])
        for item in overrides:
            if item.get("index") == segment_index + 1:
                return item
        original = blocks[block_index]["segments"][segment_index]
        item = {"index": segment_index + 1, "type": original["type"]}
        overrides.append(item)
        return item

    originals = [
        (block_index, segment_index, segment)
        for block_index, block in enumerate(blocks)
        for segment_index, segment in enumerate(block.get("segments", []))
    ]
    types = {segment.get("type") for _, _, segment in originals}
    all_templates = " ".join(
        str(segment.get("template", ""))
        + " ".join(str(item) for item in segment.get("templates", []))
        for _, _, segment in originals
    )

    right_index = next(
        (i for i, block in enumerate(blocks) if block.get("type") == "rprompt"),
        None,
    )
    if right_index is None:
        right_index = next(
            (i for i, block in enumerate(blocks) if block.get("alignment") == "right"),
            None,
        )
    if right_index is not None:
        block_change(right_index)["overflow"] = rules["right_overflow"]

    accent = "default"
    color_candidates = []
    if right_index is not None:
        color_candidates.extend(blocks[right_index].get("segments", []))
    color_candidates.extend(segment for _, _, segment in originals)
    for segment in color_candidates:
        color = segment.get("foreground")
        if isinstance(color, str) and color and "{{" not in color:
            accent = color
            break

    left_index = next(
        (i for i, block in enumerate(blocks) if block.get("alignment", "left") == "left"),
        0,
    )

    path_entry = next((entry for entry in originals if entry[2].get("type") == "path"), None)
    if path_entry:
        bi, si, path = path_entry
        options = path.get("options") or {}
        if options.get("max_width") != rules["path"]["max_width"]:
            segment_change(bi, si).setdefault("options", {})["max_width"] = rules["path"]["max_width"]
        if options.get("style") != "powerlevel":
            segment_change(bi, si).setdefault("options", {})["style"] = "powerlevel"
        template = path.get("template")
        if isinstance(template, str) and template and ".Writable" not in template:
            segment_change(bi, si)["template"] = append_template(
                template, rules["path"]["readonly_suffix"]
            )
    else:
        block_change(left_index).setdefault("segments", []).append(
            {
                "type": "path",
                "alias": "FunctionalPath",
                "style": "plain",
                "foreground": accent,
                "options": {"style": "powerlevel", "max_width": rules["path"]["max_width"]},
                "template": "{{ .Path }}" + rules["path"]["readonly_suffix"] + " ",
            }
        )

    git_entry = next((entry for entry in originals if entry[2].get("type") == "git"), None)
    if git_entry:
        bi, si, git = git_entry
        update = segment_change(bi, si)
        original_options = git.get("options") or {}
        options = update.setdefault("options", {})
        if not original_options.get("branch_template"):
            options["branch_template"] = rules["git"]["branch_template"]
        modes = copy.deepcopy(original_options.get("untracked_modes") or {})
        if "*" not in modes:
            modes["*"] = rules["git"]["untracked_mode"]
            options["untracked_modes"] = modes
        excluded = list(git.get("exclude_folders") or [])
        if "~" not in excluded:
            update["exclude_folders"] = excluded + ["~"]

        template = git.get("template")
        if isinstance(template, str) and template:
            enriched = template
            for fragment in rules["git"]["fragments"]:
                if not any(field in enriched for field in fragment["unless_any"]):
                    enriched = append_template(enriched, fragment["template"])
            if enriched != template:
                update["template"] = enriched
        if not options:
            update.pop("options")
    else:
        git_template = "{{ .HEAD }}"
        for fragment in rules["git"]["fragments"]:
            git_template += fragment["template"]
        block_change(left_index).setdefault("segments", []).append(
            {
                "type": "git",
                "alias": "FunctionalGit",
                "style": "plain",
                "foreground": accent,
                "exclude_folders": ["~"],
                "options": {
                    "branch_template": rules["git"]["branch_template"],
                    "untracked_modes": {"*": rules["git"]["untracked_mode"]},
                },
                "template": git_template + " ",
            }
        )

    for bi, si, segment in originals:
        kind = segment.get("type")
        if kind in RUNTIMES and not (segment.get("options") or {}).get("cache_duration"):
            segment_change(bi, si).setdefault("options", {})["cache_duration"] = rules["runtime_version_cache"]
        if kind == "executiontime":
            if (segment.get("options") or {}).get("threshold") != rules["executiontime_threshold_ms"]:
                segment_change(bi, si).setdefault("options", {})["threshold"] = rules["executiontime_threshold_ms"]
            if (segment.get("options") or {}).get("always_enabled"):
                segment_change(bi, si).setdefault("options", {})["always_enabled"] = False
        elif kind == "status":
            template = segment.get("template")
            if isinstance(template, str) and template and not any(
                marker in template for marker in (".Code", ".String")
            ):
                segment_change(bi, si)["template"] = append_template(template, rules["status_suffix"])

    additions = []
    for item in rules["missing_segments"]:
        feature = item["feature"]
        marker = item.get("marker")
        if marker and marker in all_templates:
            continue
        if feature not in {"jobs", "direnv", "context"} and feature in types:
            continue
        if set(item.get("skip_when_types", [])) & types:
            continue
        required = item.get("requires_command")
        if required and shutil.which(required) is None:
            continue
        segment = copy.deepcopy(item["segment"])
        if feature in RUNTIMES:
            segment.setdefault("options", {}).setdefault("cache_duration", rules["runtime_version_cache"])
        segment["foreground"] = accent
        additions.append(segment)

    if additions:
        if right_index is None:
            result.setdefault("blocks", []).append(
                {
                    "type": "rprompt",
                    "alignment": "right",
                    "overflow": rules["right_overflow"],
                    "segments": additions,
                }
            )
        else:
            block_change(right_index).setdefault("segments", []).extend(additions)

    result["blocks"] = [changes[index] for index in sorted(changes)] + result.get("blocks", [])
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--extends", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--pure-local", action="store_true")
    parser.add_argument("--omarchy", action="store_true")
    parser.add_argument("--omarchy-kitty", type=Path, default=Path.home() / ".local/state/omarchy/current/theme/kitty.conf")
    args = parser.parse_args()
    base = read_object(args.base)
    rules = read_object(OVERLAY)
    if rules.get("version") != 1:
        raise ValueError(f"Unsupported overlay version in {OVERLAY}")
    omarchy_colors = None
    omarchy_accent = None
    if args.omarchy and not args.pure_local:
        try:
            omarchy_colors, omarchy_accent = read_omarchy_palette(args.omarchy_kitty)
        except (OSError, ValueError) as error:
            parser.error(f"No se pudo leer la paleta de Omarchy: {error}")
    effective = compose(base, rules, args.extends, args.pure_local)
    has_right = any(
        block.get("type") == "rprompt" or block.get("alignment") == "right"
        for block in base["blocks"]
    )
    # Native extends cannot introduce a new block. Resolve the small override
    # against the local base, then append only the missing right block.
    added_right = next(
        (block for block in effective.get("blocks", [])
         if block.get("type") == "rprompt" and "index" not in block),
        None,
    )
    if not has_right and added_right is not None and not args.pure_local:
        effective["blocks"].remove(added_right)
        args.output.write_text(json.dumps(effective, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        exported = subprocess.run(
            ["oh-my-posh", "config", "export", "--config", str(args.output)],
            check=True, capture_output=True, text=True,
        )
        effective = json.loads(exported.stdout)
        effective["blocks"].append(added_right)
        effective.pop("extends", None)
    if args.omarchy and not args.pure_local:
        # Materialize inheritance before changing colors; the downloaded base stays untouched.
        args.output.write_text(json.dumps(effective, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        exported = subprocess.run(
            ["oh-my-posh", "config", "export", "--config", str(args.output)],
            check=True, capture_output=True, text=True,
        )
        effective = recolor(stabilize_added_segments(json.loads(exported.stdout), effective), omarchy_colors, omarchy_accent)
        effective.pop("extends", None)
    args.output.write_text(json.dumps(effective, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
