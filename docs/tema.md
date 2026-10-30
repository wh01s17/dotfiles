# Tema `wh01s17`

[`themes/wh01s17`](../desktop/.config/omarchy/themes/wh01s17/) implementa una
variante oscura inspirada en `wh01s17.com`: superficies casi negras, tipografía
monoespaciada y acentos verde fósforo, cian, ámbar, rojo y púrpura.

Actívala y recorre sus cinco fondos con:

```bash
omarchy theme set wh01s17
omarchy theme current
omarchy theme bg next
```

Sus piezas son:

| Ruta | Responsabilidad |
| --- | --- |
| [`colors.toml`](../desktop/.config/omarchy/themes/wh01s17/colors.toml) | Paleta usada para generar configuraciones de aplicaciones |
| [`hyprland.lua`](../desktop/.config/omarchy/themes/wh01s17/hyprland.lua) | Bordes verde/cian, radio de 10 px y sombras del tema |
| [`icons.theme`](../desktop/.config/omarchy/themes/wh01s17/icons.theme) | Selecciona `Yaru-prussiangreen-dark` |
| [`shell.*.toml`](../desktop/.config/omarchy/themes/wh01s17/) | Barra, controles, tipografía (Departure Mono), menús, lock, notificaciones, popups, polkit, espaciado y tooltips |
| [`backgrounds/`](../desktop/.config/omarchy/themes/wh01s17/backgrounds/) | Cinco wallpapers PNG 4K listos para usar |
| [`sources/`](../desktop/.config/omarchy/themes/wh01s17/sources/) | Maestros SVG, generador de los wallpapers pixel art y de los iconos pixel del shell |
| [`brand/logo.svg`](../desktop/.config/omarchy/themes/wh01s17/brand/logo.svg) | Geometría oficial de la marca |

El tema se carga con los valores predeterminados y después se aplican las
preferencias personales de `~/.config/hypr`. Ambos fijan el mismo radio de
10 px; si difieren, el de `looknfeel.lua` prevalece sobre el del tema, mientras
sus colores de borde y sombras se conservan. Tras editar un archivo del tema,
vuelve a aplicarlo con `omarchy theme set wh01s17`.

[`themes/wh01s17/README.md`](../desktop/.config/omarchy/themes/wh01s17/README.md)
documenta la paleta y
[`DESIGN.md`](../desktop/.config/omarchy/themes/wh01s17/DESIGN.md) las reglas de
composición. Los fondos son:

| Fondo | Contenido | Fuente |
| --- | --- | --- |
| `01-solid-mark.png` | Marca W sólida y `wh01s17` | `sources/01-solid-mark.svg` |
| `02-outline-mark.png` | Marca W contorneada y `wh01s17` | `sources/02-outline-mark.svg` |
| `06-pixel-moon-black.png` | Luna llena 8-bit con los verdes del tema sobre negro `#000000` | `sources/pixel-art.py` |
| `07-pixel-moon-wordmark-black.png` | Cuarto creciente 8-bit con `wh01s17` en pixel art sobre negro `#000000` | `sources/pixel-art.py` |
| `08-pixel-gengar-wordmark-black.png` | Gengar de Fastfetch con sus colores originales y `wh01s17` sobre negro `#000000` | `sources/pixel-art.py` |
| `09-pixel-gengar-black.png` | El mismo Gengar sobre negro `#000000`, sin `wh01s17` | `sources/pixel-art.py` |

Las lunas reproducen la cara visible real: los mares y cráteres principales se
ubican por latitud y longitud selenográficas y se iluminan según la fase. El
Gengar es el sprite de `fastfetch/gengar.png` calcado píxel por píxel. Todo se
dibuja en una cuadrícula de 240×135 que se escala 16× sin interpolación.

Para regenerar los PNG:

```bash
cd ~/.config/omarchy/themes/wh01s17
rsvg-convert --width 3840 --height 2160 \
  --output backgrounds/01-solid-mark.png sources/01-solid-mark.svg
rsvg-convert --width 3840 --height 2160 \
  --output backgrounds/02-outline-mark.png sources/02-outline-mark.svg
python3 sources/pixel-art.py
omarchy theme set wh01s17
```

El último comando copia los fondos regenerados al tema activo.

## Tipografía e iconos del shell

`shell.font.toml` declara `family = "Departure Mono"`, una monoespaciada
pixelada (OFL) que sólo usa el shell: barra, menú, paneles y popups. Kitty y el
resto del sistema conservan su fuente. Departure Mono no trae iconos, así que
fontconfig resuelve los que faltan con
[`60-wh01s17-pixel-icons.conf`](../apps/.config/fontconfig/conf.d/60-wh01s17-pixel-icons.conf):
primero `wh01s17 Pixel Icons` y después Symbols Nerd Font.

`wh01s17 Pixel Icons` coloca dibujos de
[Pixelarticons](https://pixelarticons.com/) (MIT) en los mismos code points de
Nerd Font que ya usan el menú, sus extensiones, la barra y sus scripts. Así,
cada icono con equivalente se vuelve 8-bit sin tocar QML ni JSONC, y los que no
lo tienen (la huella del lock, logos propios) siguen con su glifo Nerd Font. La
tabla de equivalencias y los iconos dibujados a mano (Bluetooth) están en
[`sources/pixel-icons.py`](../desktop/.config/omarchy/themes/wh01s17/sources/pixel-icons.py).
Ambas fuentes se instalan desde
[`apps/.local/share/fonts/wh01s17/`](../apps/.local/share/fonts/wh01s17/) con
sus licencias.

Para mapear otro icono, añádelo a `ICONS` y regenera la fuente (necesita
`python-fonttools`):

```bash
cd ~/dotfiles/desktop/.config/omarchy/themes/wh01s17
python3 sources/pixel-icons.py
fc-cache -f
omarchy restart shell
```
