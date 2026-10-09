# Wallpaper design

The wallpaper system is intentionally private and minimal: deep negative space with only the W mark and the `wh01s17` wordmark.

## Rules

- Native canvas: 3840×2160, sRGB.
- Exact official W geometry from `brand/logo.svg`.
- Exact `wh01s17` spelling rendered with JetBrains Mono Nerd Font.
- Flat colors only: no CRT scanlines, noise, glow, gradients, faux-terminal windows, or 3D imagery.
- No slogans, profession labels, terminal prompts, geographic data, or operating-system metadata.
- Primary palette: `#0a0e0f`, `#11161a`, `#cbd5ce`, and `#84c959`.
- The mark and wordmark form one vertically and horizontally centered composition.
- Large quiet regions remain available for application windows and desktop widgets.

## Masters

- `sources/01-solid-mark.svg` uses the solid W mark.
- `sources/02-outline-mark.svg` uses the outlined W mark.
- `sources/pixel-art.py` renders `03-pixel-moon.png` (full moon) and `04-pixel-moon-wordmark.png` (first quarter with a pixel-glyph `wh01s17`): the real lunar near side, maria and craters placed by selenographic coordinates, as an 8-bit sprite in the theme greens on a 240×135 grid scaled 16×.
- `sources/pixel-art.py` also renders `05-pixel-gengar-wordmark.png`: the Gen 1 Gengar sprite traced from `~/.config/fastfetch/gengar.png`, in its original colors, above the pixel `wh01s17`.
- The pixel-art wallpapers (03–05) intentionally trade the flat/no-dither rule and the JetBrains Mono wordmark for the 8-bit look.

Render with:

```sh
rsvg-convert --width 3840 --height 2160 --output backgrounds/01-solid-mark.png sources/01-solid-mark.svg
rsvg-convert --width 3840 --height 2160 --output backgrounds/02-outline-mark.png sources/02-outline-mark.svg
python3 sources/pixel-art.py
```
