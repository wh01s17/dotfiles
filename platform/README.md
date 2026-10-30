# Runtime wh01s17

Shell, comandos, sesión y valores por defecto del escritorio. Este paquete
se enlaza directamente desde el repo con Stow, al igual que `desktop`,
`terminal`, `maintenance` y `apps`.

El runtime vive en `~/.local/share/wh01s17`; `WH01S17_PATH` y los comandos
`wh01s17-*` se configuran mediante `~/.config/uwsm/env.d/10-wh01s17`.
Los archivos de sistema se instalan desde `installer/install.sh`.

La base histórica se importó de Omarchy 4.0.4 y recibió correcciones
seleccionadas. No requiere ese sistema ni sus repositorios para instalarse o
actualizarse. Se mantiene aquí como código fuente del escritorio.
La licencia MIT y la procedencia se conservan en
[LICENSE](.local/share/wh01s17/LICENSE) y [UPSTREAM](.local/share/wh01s17/UPSTREAM).
