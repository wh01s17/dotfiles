# Correcciones sobre la base congelada

El escritorio 1.0.1 mantiene la base Omarchy 4.0.4 y las personalizaciones
wh01s17. No instala Omarchy 4.0.6 ni sus repositorios, kernel o migraciones.

`omarchy-4.0.4-fixes.json` conserva bloques exactos del
[diff oficial 4.0.4 → 4.0.6](https://github.com/omacom/omarchy/compare/v4.0.4...v4.0.6),
con los commits de origen y licencia MIT. Se seleccionaron:

- separación de opciones y argumentos en comandos, paquetes y hooks;
- comprobación del estado real del bloqueo y recuperación sin tomar el de otro proceso;
- temporizadores de inactividad: cero desactiva la acción;
- espera de salida y arranque al reiniciar el shell;
- API Lua para activar/desactivar monitores, también en el plugin personalizado;
- calendario calculado en UTC, consistente con el reloj personalizado ya corregido;
- detección de la GPU que controla la pantalla antes de forzar variables NVIDIA;
- eliminación completa de las variantes estándar de reglas UFW al desactivar SSH;
- conservación de `__sourceDir` para los scripts de plugins externos;
- provisión sin la entrada automática `{{ cwd }}/bin` de mise.

No se aplica el `--` de upstream en `launch-editor`: ese script es `$EDITOR`,
y con `--` el editor toma como archivo el `+línea` que pasan `less`,
lazygit o yazi (`nvim -- +3 f.txt` abre `+3` y `f.txt`).

Se conservaron la solución propia de colores Qt 6.12, el tema, los plugins,
los atajos, las aplicaciones y la política de tapa. El parche de colores de
upstream usa un alias de importación; el renombrado mantiene `Colors` para
compatibilidad con los plugins wh01s17.

`tools/backport-omarchy.py` revisa todos los contextos antes de escribir y
acepta una segunda ejecución sin cambios. Si un archivo difiere en un bloque
afectado, se detiene para revisión. Cada archivo se sustituye atómicamente.

`mise-work-cleanup.sh` adapta la
[migración de seguridad #11336](https://github.com/omacom/omarchy/pull/11336):
retira la confianza anterior, elimina el archivo estándar o respalda el
personalizado antes de quitar la asignación insegura. Conserva enlaces y
configuraciones ignoradas. Usa una marca de éxito para no revocar otra vez una
configuración que revises y vuelvas a autorizar. No limpia la sesión de un
shell ya abierto: hay que volver a iniciar sesión o reiniciar.

El comando para desactivar SSH queda corregido, pero la actualización no lo
ejecuta ni cambia las reglas actuales: el equipo puede estar usando SSH.

Pruebas: `TEST_DOTFILES=~/dotfiles python3 -B -m unittest discover -s tests -v`.
Las pruebas de integración ejecutan helpers con sustitutos de pacman, sudo y
mise: ejecútalas en un entorno desechable. La validación de suspensión y PAM
se hace en el equipo de destino, según [UPDATE.md](../UPDATE.md).

## Correcciones de Omarchy 4.5.0

Revisadas el 2026-11-19 contra las [notas de 4.5](https://omarchy.org/news/2026/11/omarchy-4-5/).
Se aplicaron directamente sobre el runtime y los plugins wh01s17 (renombrados
con `tools/rename.py`), sin cambiar la base 4.0.4 ni el tema.

Seguridad:

- #8374 estado de la grabación de pantalla fuera de `/tmp`;
- #8170 nombres de hook y de estado que son rutas (en `hook-install`, la
  comprobación va después del bloque de 4.0.6 para no romper su contexto);
- #9873 pila polkit de huella/FIDO2 sobre `system-auth` (sin migración: el
  runtime no tiene `migrations/` y el equipo no tenía `polkit-1`);
- #14667 `sshd` y su puerto solo con una clave autorizada;
- #9457, adaptado: `sudo-passwordless` vence a una hora absoluta
  (`--on-calendar`), que también corre durante la suspensión. No se trajo
  el resto de #9457/#9467/#10217: upstream lo revirtió en #17000.

Plugins y shell:

- reloj: #16684 (`WallClock`, sin inundar el log al terminar el horario de
  verano de America/Santiago); también en `wh01s17.clock`, a segundos;
- audio: #7783 (caída al desconectar un dispositivo con el panel abierto), #14855;
- red: #16485 y #14133 sin el bloque de `connectionKey`, que no existe en 4.0.4;
- monitor: #16147 (reactivar mantiene modo, posición y escala; marca como
  `superseded` el bloque correspondiente de 4.0.6), #16923, #16950, #16310, #14525;
- bandeja: #14661; popups: #15111; bloqueo: #7806; sesión: #15226, #15908;
- energía: #7779, #17265, #16272 y #16278 (sin i18n), #16562.

Estilo, solo lo que no cambia la apariencia propia de la barra (fuente
Departure Mono, iconos pixel, corazones de batería): #6946 cierre de las
notificaciones al pasar el puntero, #13916 altura de los desplegables, #9345
perilla del slider hasta el final de la pista, #16243 y #16488 tooltips.

Descartados: #15065, #17003 y #16089 (reescalan glifos y moverían los iconos
pixel), `Style.qml` de 4.5 (quita la clave `family` del tema), #16470 y
#16469 (animaciones de paneles y notificaciones: dependen de cambios de 4.5
ausentes), #16991 y #16293 (la barra de 4.0.4 no se desvanece ni tiene
franja), #13419/#14458 (solo pantallas con escala fraccionaria), #15786,
#16750, #15867, #13431, #15294 y el factory reset (no existe en este runtime).

### Paneles desplegados: animación 4.5 y modo pixel

- #16470 (paneles que crecen desde la barra y se transforman entre sí en la
  misma sección) portado a `KeyboardPanel`, `PopupCard`, `PluginBarApi` y a las
  dos barras; la sección sale de `slot.region`, porque `BarModel` de 4.0.4 no
  tiene `navigationRegions`. `Style.easeOut` y `Style.duration` añadidos.
- Modo pixel propio (`[pixel]` en `shell.toml`, `Commons/PixelGeometry.js`,
  `Ui/PixelBar.qml`): esquinas en escalera en `BorderSurface`, sliders y
  medidores por bloques, y animación en pasos (`Style.stepped`). En modo pixel
  el panel se despliega desde la barra en saltos en vez de escalarse y
  desvanecerse. La barra y sus widgets usan `Style.roundingRadius` y
  `pixelCorners: false`, así que no cambian.

### Panel de agentes de 4.5

El plugin `agents` se sustituyó por el de 4.5.0 (renombrado con
`tools/rename.py`): panel, `collectors.py`, iconos de proveedores y los
scripts `wh01s17-agent*` (uso por proveedor, cuentas). Se añadió lo que
necesita y no existía en 4.0.4: `Commons/I18n.qml` con `Plural.js` y
`Numbers.js`, `bin/wh01s17-i18n`, los catálogos `default/i18n` (en, es-MX,
`locales.json`, `plural.jq`), `wh01s17-mise-default-tools`, `ShellIpc` (aquí un
`IpcHandler` simple), contenido diferido en `KeyboardPanel`
(`content`/`loadedContent`) y `reorderable` en `PanelKeyCatcher`. El medidor
usa `PixelBar` en modo pixel. El icono de la barra es el mismo.

Del resto de paneles, 4.5 solo cambia i18n y detalles; el aspecto nuevo
(crecer desde la barra, transformarse entre paneles) ya está en `KeyboardPanel`.
