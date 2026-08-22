# WH01S17

An Omarchy theme derived from the visual system of [wh01s17.com](https://www.wh01s17.com/): deep dark surfaces, precise monospaced typography, phosphor-green signal color, and compact geometry.

## Palette

- Void: `#0a0e0f`
- Surface: `#11161a`
- Raised surface: `#171e23`
- Border: `#243038`
- Foreground: `#cbd5ce`
- Signal: `#00ff9c`
- Diagnostic cyan: `#45d9ea`
- Warning amber: `#e8b53f`
- Fault red: `#ff6b66`
- Trace purple: `#b98cff`

## Wallpapers

- `01-solid-mark.png`: solid brand mark and `wh01s17`, 3840×2160.
- `02-outline-mark.png`: outlined brand mark and `wh01s17`, 3840×2160.

Both are deterministic vector compositions rendered to exact 4K PNGs. They contain no slogans, terminal prompts, location data, system references, CRT effects, raster noise, glow, gradients, or 3D imagery. Editable masters live in `sources/`; the design rationale is preserved in `DESIGN.md`.

## Apply

```sh
omarchy theme set wh01s17
```

The theme lets Omarchy generate application-specific configurations from `colors.toml`, then adds branded shell surfaces, a green/cyan Hyprland border, six-pixel rounding, a restrained phosphor shadow, and Yaru's dark prussian-green icons.

The logo in `brand/logo.svg` is the official mark published by wh01s17.com and is kept here as the design source of truth.
