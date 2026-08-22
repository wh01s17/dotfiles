# Wallpaper design

The wallpaper system is intentionally private and minimal: deep negative space with only the W mark and the `wh01s17` wordmark.

## Rules

- Native canvas: 3840×2160, sRGB.
- Exact official W geometry from `brand/logo.svg`.
- Exact `wh01s17` spelling rendered with JetBrains Mono Nerd Font.
- Flat colors only: no CRT scanlines, noise, glow, gradients, faux-terminal windows, or 3D imagery.
- No slogans, profession labels, terminal prompts, geographic data, or operating-system metadata.
- Primary palette: `#0a0e0f`, `#11161a`, `#cbd5ce`, and `#00ff9c`.
- The mark and wordmark form one vertically and horizontally centered composition.
- Large quiet regions remain available for application windows and desktop widgets.

## Masters

- `sources/01-solid-mark.svg` uses the solid W mark.
- `sources/02-outline-mark.svg` uses the outlined W mark.

Render with:

```sh
rsvg-convert --width 3840 --height 2160 --output backgrounds/01-solid-mark.png sources/01-solid-mark.svg
rsvg-convert --width 3840 --height 2160 --output backgrounds/02-outline-mark.png sources/02-outline-mark.svg
```
