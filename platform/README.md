# platform

Paquete Stow sólo para Arch puro: el runtime del escritorio wh01s17
(shell, comandos y valores por defecto). Es una copia congelada de Omarchy
4.0.4-1 (licencia MIT, ver `.local/share/wh01s17/LICENSE` y `UPSTREAM`),
renombrada a wh01s17: comandos `wh01s17-*`, variables `WH01S17_*`,
`~/.config/wh01s17` y plugins internos `core.*`.

| Ruta | Contenido |
| --- | --- |
| `.local/share/wh01s17/` | Runtime (`WH01S17_PATH`): shell, `bin/`, `default/`, `config/`, `install/` |
| `.local/share/wh01s17/system/` | Archivos de sistema; `install.sh` de arch-desktop elige cuáles aplicar |
| `.local/share/wh01s17/nvim/config/` | Configuración LazyVim; se copia a `~/.config/nvim` si falta |
| `.config/uwsm/env.d/10-wh01s17` | Entorno de la sesión: `WH01S17_PATH` y `PATH` |
| `.config/systemd/user/` | Servicios de usuario |

Los paquetes `desktop` y `terminal` de estos dotfiles siguen usando los
nombres de Omarchy (los usa tu Omarchy actual); en Arch, arch-desktop genera
una versión renombrada con `tools/arch-dotfiles.py`.

Regenerar desde un equipo con Omarchy (necesita fontTools):

```bash
~/workspace/arch-desktop/tools/vendor-omarchy.py --force
```

Los cambios hechos a mano dentro de la copia se pierden al regenerarla.
