# platform

Paquete Stow sólo para Arch puro: una copia congelada del runtime de
Omarchy 4.0.4-1 (licencia MIT, ver `.local/share/omarchy/LICENSE`).
Con él, los paquetes `desktop`, `terminal` y `maintenance` funcionan igual
que en Omarchy, sin el repositorio de paquetes de Omarchy.

No lo instales en un equipo con Omarchy: allí `/usr/share/omarchy` ya
proporciona lo mismo.

| Ruta | Contenido |
| --- | --- |
| `.local/share/omarchy/` | Runtime (`OMARCHY_PATH`): shell, `bin/`, `default/`, `config/`, `install/` |
| `.local/share/omarchy/system/` | Archivos que los paquetes instalan fuera de `/usr/share/omarchy`; `arch/install.sh` elige cuáles aplicar |
| `.local/share/omarchy/nvim/config/` | Configuración LazyVim de `omarchy-nvim`; se copia a `~/.config/nvim` si falta |
| `.config/uwsm/env.d/10-omarchy` | Entorno de la sesión: `OMARCHY_PATH` y `PATH` |
| `.config/systemd/user/` | Servicios de usuario que apuntan a la copia |

## Diferencias con Omarchy

- Sin los temas de serie ni las migraciones: sólo se usa el tema `wh01s17`.
- `omarchy-update` actualiza Arch (pacman, AUR, mise) sin tocar el repositorio
  de Omarchy ni hacer `git pull` en `OMARCHY_PATH` (que aquí es `~/dotfiles`).
- Los comandos de canales, reinstalación y enlace de desarrollo están
  desactivados.

Regenerar desde un equipo con Omarchy:

```bash
~/workspace/post-install-linux/arch/tools/vendor-omarchy.py --force
```

Los cambios propios hechos a mano dentro de la copia se pierden al
regenerarla; revisa `git diff` antes de hacer commit.
