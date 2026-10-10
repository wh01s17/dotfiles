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
| [`hyprland.lua`](../desktop/.config/omarchy/themes/wh01s17/hyprland.lua) | Bordes verde/cian, radio de 6 px y sombras del tema |
| [`icons.theme`](../desktop/.config/omarchy/themes/wh01s17/icons.theme) | Selecciona `Yaru-prussiangreen-dark` |
| [`shell.*.toml`](../desktop/.config/omarchy/themes/wh01s17/) | Barra, controles, tipografía, menús, lock, notificaciones, popups, polkit, espaciado y tooltips |
| [`backgrounds/`](../desktop/.config/omarchy/themes/wh01s17/backgrounds/) | Cinco wallpapers PNG 4K listos para usar |
| [`sources/`](../desktop/.config/omarchy/themes/wh01s17/sources/) | Maestros SVG y generador de los wallpapers pixel art |
| [`brand/logo.svg`](../desktop/.config/omarchy/themes/wh01s17/brand/logo.svg) | Geometría oficial de la marca |

El tema se carga con los valores predeterminados y después se aplican las
preferencias personales de `~/.config/hypr`. Por eso el radio de 3 px de
`looknfeel.lua` prevalece sobre los 6 px propuestos por el tema, mientras sus
colores de borde y sombras se conservan. Tras editar un archivo del tema,
vuelve a aplicarlo con `omarchy theme set wh01s17`.

[`themes/wh01s17/README.md`](../desktop/.config/omarchy/themes/wh01s17/README.md)
documenta la paleta y
[`DESIGN.md`](../desktop/.config/omarchy/themes/wh01s17/DESIGN.md) las reglas de
composición. Los fondos son:

| Fondo | Contenido | Fuente |
| --- | --- | --- |
| `01-solid-mark.png` | Marca W sólida y `wh01s17` | `sources/01-solid-mark.svg` |
| `02-outline-mark.png` | Marca W contorneada y `wh01s17` | `sources/02-outline-mark.svg` |
| `03-pixel-moon.png` | Luna llena 8-bit con los verdes del tema | `sources/pixel-art.py` |
| `04-pixel-moon-wordmark.png` | Cuarto creciente 8-bit con `wh01s17` en pixel art | `sources/pixel-art.py` |
| `05-pixel-gengar-wordmark.png` | Gengar de Fastfetch con sus colores originales y `wh01s17` | `sources/pixel-art.py` |

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
