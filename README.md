# Escritorio wh01s17 para Arch Linux

Escritorio propio con Hyprland, shell QML, plugins, tema, Kitty y Zsh.
El instalador y la configuración se mantienen juntos en este repositorio.
Los paquetes se enlazan directamente con GNU Stow: no hay compilación ni
renombrado intermedio.

## Estructura

| Directorio | Responsabilidad |
| --- | --- |
| `desktop/` | Hyprland, `~/.config/wh01s17`, plugins, tema y Fastfetch |
| `terminal/` | Zsh, Kitty y Starship |
| `maintenance/` | Sincronizador de dotfiles y timers de mantenimiento |
| `platform/` | Runtime independiente: shell, comandos `wh01s17-*`, sesión y valores por defecto |
| `apps/` | Aplicaciones, mise, fuentes y lanzadores |
| `installer/` | Instalación, paquetes, hardware, parches y pruebas de integración |
| `system/` | Configuración del sistema que se instala con sudo |
| `docs/` | Documentación de tema, CTF y Pomodoro |

## Instalación

En un Arch ya instalado, como usuario normal:

```bash
git clone https://github.com/wh01s17/dotfiles.git ~/dotfiles
cd ~/dotfiles
./installer/install.sh --dry-run
./installer/install.sh
```

Para instalar también el sistema base desde el ISO, consulta
[la guía de instalación](installer/INSTALL.md). El instalador elige el perfil
del equipo y configura paquetes, servicios y archivos de sistema.

## Actualizar con un comando

```bash
~/dotfiles/update.sh
```

Actualiza Git con `--ff-only`, aplica los enlaces, comprueba la configuración
y activa la sincronización automática. En instalaciones anteriores también
redirige los enlaces de `.arch-build` y elimina esa copia tras completar las
comprobaciones. Conserva los perfiles locales y no ejecuta etapas de disco,
cifrado ni instalación de paquetes.

La primera vez, para obtener el actualizador en otro equipo:

```bash
git -C ~/dotfiles pull --ff-only && ~/dotfiles/update.sh --local
```

## Sincronización automática

Edita los originales de este repo. Como las aplicaciones leen esos archivos
mediante enlaces, los cambios no necesitan generar copias. El timer
`dotfiles-sync.timer` revisa cambios cada cinco segundos y actualiza los
enlaces para incorporar archivos nuevos o eliminados. También funciona
después de `git pull`; no descarga cambios por su cuenta ni instala paquetes.
Los cambios en el tema activo regeneran su copia de estado y recargan
Hyprland, la paleta del shell y los terminales compatibles, sin cambiar el
wallpaper ni ejecutar hooks de instalación de aplicaciones. Los cambios de
configuración de Hyprland también provocan una recarga. Otras aplicaciones
que no recargan su configuración necesitan reiniciarse.

```bash
dotfiles-sync --force
journalctl --user -u dotfiles-sync.service -n 40
systemctl --user disable --now dotfiles-sync.timer  # desactivar
```

El instalador habilita el timer. Para activarlo en una instalación existente,
tras enlazar `maintenance`:

```bash
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-sync.timer
```

## Hyprland en Lua

[`hyprland.lua`](desktop/.config/hypr/hyprland.lua) carga primero los valores predeterminados de wh01s17 y después estas personalizaciones:

| Archivo | Personalización |
| --- | --- |
| [`monitors.lua`](desktop/.config/hypr/monitors.lua) | Escala gestionada por el runtime y carga del perfil local de monitores |
| [`input.lua`](desktop/.config/hypr/input.lua) | Teclado US `altgr-intl`, Caps Lock, repetición y salida de tableta |
| [`bindings.lua`](desktop/.config/hypr/bindings.lua) | Multimedia y controles de WayScriber |
| [`looknfeel.lua`](desktop/.config/hypr/looknfeel.lua) | Gaps, bordes, radio, blur y transición de escritorios |
| [`autostart.lua`](desktop/.config/hypr/autostart.lua) | Inicio automático de WayScriber |
| [`hyprsunset.conf`](desktop/.config/hypr/hyprsunset.conf) | Perfiles horarios de temperatura de color |
| [`xdph.conf`](desktop/.config/hypr/xdph.conf) | Selector de pantalla para `xdg-desktop-portal-hyprland` |
| [`.luarc.json`](desktop/.config/hypr/.luarc.json) | Stubs y globales `hl`/`o` para el servidor de lenguaje Lua |

Los controladores NVIDIA ya los detecta wh01s17, por lo que no se duplican variables específicas de GPU en la configuración personal.

### Perfiles por equipo

Las diferencias de hardware se guardan en perfiles versionados y se eligen
mediante dos selectores locales ignorados por Git. La selección no depende del
hostname, por lo que sigue funcionando aunque el equipo cambie de nombre.

| Perfil | Monitores | Kitty |
| --- | --- | --- |
| `hp-gray` | Panel del notebook y proyector HDMI reflejado | 11 pt |
| `omen` | Monitor 4K, monitor 1080p y panel del notebook | 14 pt |

Selecciona el mismo perfil para Hyprland y Kitty desde la raíz del repositorio:

```bash
printf 'return "hp-gray"\n' > desktop/.config/hypr/machine-profile.lua
printf 'include profiles/hp-gray.conf\n' > terminal/.config/kitty/machine-profile.conf
```

En el Omen, reemplaza `hp-gray` por `omen`. Si no existe un selector, Hyprland
usa resolución preferida y posición automática; Kitty conserva sus valores
predeterminados.

Los dos selectores están ignorados por Git para que cada equipo conserve su
elección. Stow sí los enlaza cuando existen, porque trabaja con el árbol del
sistema de archivos y no con el índice de Git.

El panel **Display** usa el clon local `wh01s17.monitor`. La acción de escala
delega en el comando original del runtime, que registra la salida enfocada y su
nueva escala en `~/.local/state/wh01s17/monitor-scaling.log`, y después recarga
Hyprland. [`monitor_scales.lua`](desktop/.config/hypr/monitor_scales.lua) toma
el último valor de cada conector y los perfiles lo aplican individualmente. De
este modo `DP-1` puede permanecer a 2× mientras `eDP-1` y `HDMI-A-1` siguen a
1×. En `hp-gray`, donde HDMI refleja la pantalla interna, ambas salidas usan
la escala guardada para `eDP-1`; así la recarga no devuelve el proyector a 1×.
El perfil `omen` también recalcula las posiciones lógicas usando la escala del
monitor que determina cada desplazamiento.

`GDK_SCALE` se mantiene en 1 para los perfiles mixtos porque es una variable
global; el escalado por salida queda a cargo de Hyprland. Los valores dinámicos
viven en el estado local de wh01s17 y no ensucian el repositorio al usar el
panel.

### Entrada y atajos personales

[`input.lua`](desktop/.config/hypr/input.lua) activa Num Lock, usa repetición
de 40 caracteres por segundo tras 600 ms, reduce el scroll del touchpad a
`0.4` y dirige la tableta a `DP-1`. Cambia `tablet.output` si el monitor de
dibujo tiene otro nombre; obtén los nombres con `hyprctl monitors all`.

Los atajos adicionales no sustituyen los predeterminados de wh01s17:

| Atajo | Acción |
| --- | --- |
| `Ctrl+Alt+A` / `Ctrl+Alt+Z` | Subir / bajar volumen; admite repetición |
| `Ctrl+Alt+O` | Reproducir o pausar |
| `Ctrl+Alt+P` / `Ctrl+Alt+I` | Pista siguiente / anterior |
| `Super+Alt+A` | Mostrar u ocultar WayScriber |
| `Super+Alt+P` | Alternar passthrough de WayScriber |
| `Super+Alt+D` | Alternar dibujo/interacción de WayScriber |
| `Super+Ctrl+Shift+←` / `→` | Estrechar / ensanchar la ventana enfocada; admite repetición |
| `Super+Ctrl+Shift+↑` / `↓` | Bajar / subir la altura de la ventana enfocada; admite repetición |

### Blur y transparencia

El blur se define dentro de `decoration` en
[`looknfeel.lua`](desktop/.config/hypr/looknfeel.lua). La configuración actual
usa un desenfoque corto de tamaño 3 con dos pasadas:

```lua
decoration = {
  rounding = 10,

  blur = {
    enabled = true,
    size = 3,
    passes = 2,
    ignore_opacity = true,
    new_optimizations = true,
    xray = false,
  },
},
```

Los valores significan:

| Opción | Efecto |
| --- | --- |
| `size` | Distancia del desenfoque. Un valor mayor hace menos reconocible el fondo. |
| `passes` | Número de pasadas. Más pasadas suavizan el resultado y consumen más GPU. |
| `ignore_opacity` | Mantiene el cálculo del blur independiente de la opacidad global de la ventana. |
| `new_optimizations` | Activa las optimizaciones de blur recomendadas. |
| `xray` | Si es `true`, una ventana flotante ignora las ventanas en mosaico al calcular el fondo. |

`size` y `passes` deben ser al menos `1`. Como referencia, `3/1` es ligero,
`8/2` equilibrado y `12/3` fuerte. El blur sólo difumina lo que está detrás:
no vuelve transparente una ventana ni desenfoca su texto.

wh01s17 aplica por defecto una opacidad muy leve a las ventanas etiquetadas
como `default-opacity`: `0.985` activas y `0.96` inactivas. Para definir
valores exactos sin multiplicarlos por otras reglas, agrega al final de
[`hyprland.lua`](desktop/.config/hypr/hyprland.lua):

```lua
o.window({ tag = "default-opacity" }, {
  opacity = "0.94 override 0.88 override 1.0 override",
})
```

Los tres valores son opacidad activa, inactiva y a pantalla completa. Por
ejemplo, `0.94` equivale a 94 % opaco y 6 % transparente. `override` evita que
Hyprland multiplique esta regla por la opacidad predeterminada de wh01s17.
Algunas aplicaciones de video o pantalla completa eliminan deliberadamente
la etiqueta y permanecen opacas. Kitty tiene además una transparencia interna
propia, descrita más abajo.

Consulta las opciones actuales en la documentación de
[`decoration.blur`](https://wiki.hypr.land/Configuring/Basics/Variables/#blur)
y de [reglas de ventana](https://wiki.hypr.land/Configuring/Basics/Window-Rules/).

Después de cualquier cambio Lua:

```bash
hyprctl reload
hyprctl configerrors
```

### Luz nocturna y pantalla compartida

[`hyprsunset.conf`](desktop/.config/hypr/hyprsunset.conf) contiene actualmente
un perfil `identity` a las 07:00, por lo que no aplica tinte permanente. Para
activar un cambio nocturno automático, inicia `hyprsunset` desde
`autostart.lua` y agrega un perfil nocturno:

```lua
-- desktop/.config/hypr/autostart.lua
o.launch_on_start("hyprsunset")
```

```text
# desktop/.config/hypr/hyprsunset.conf
profile {
    time = 20:00
    temperature = 4000
}
```

Aplica cambios de temperatura con `wh01s17 restart hyprsunset`; `hyprctl`
no valida este archivo.

[`xdph.conf`](desktop/.config/hypr/xdph.conf) permite tokens de captura por
defecto y usa `hyprland-preview-share-picker` para elegir la pantalla al
compartir. Sus cambios se aplican al reiniciar el portal o en el siguiente
inicio de sesión.

## wh01s17 Shell

La barra se define en [`shell.json`](desktop/.config/wh01s17/shell.json). Usa widgets nativos para las funciones integradas y un módulo QML reutilizable para los scripts personales.

### Distribución

| Zona | Módulos |
| --- | --- |
| Izquierda | Menú wh01s17, escritorios, rama del repositorio activo y panel CTF |
| Centro | Indicadores, reloj con segundos, distribución de teclado, clima, Pomodoro y actualizaciones |
| Derecha | Bandeja, metrónomo, firewall, unidades montadas, portapapeles, agentes, servicios, Bluetooth, red, audio, monitores, CPU y energía |

El reloj `wh01s17.clock` es un clon persistente del widget oficial. Conserva
su calendario y controles, pero usa precisión de segundos para que el formato
`HH:mm:ss` se actualice continuamente en lugar de mostrar siempre `00`.

Los indicadores nativos agrupan dictado, grabación, recordatorios, luz nocturna, silencio de notificaciones y bloqueo de idle.

### Estilo

Con `"outline": true` en `shell.json`, la barra queda sin fondo y la rodea un
único contorno, redondeado como las ventanas y con el borde `[bar] border`, que
el tema apunta al degradado verde/cian del borde activo de Hyprland. Los
indicadores del centro sólo se despliegan al pasar el ratón sobre los módulos
centrales.

`"islands": true` usa el mismo borde, pero enmarca cada zona (izquierda, centro
y derecha) por separado: el contorno crece y se encoge con una animación corta
cuando la zona cambia de ancho y, a la derecha, empieza donde están los widgets
visibles y acompaña al cajón de la bandeja. El resto del estilo sigue la
estética del tema:

- **Escritorios:** sólo números; el activo en `accent` sobre una barra corta,
  los ocupados en el color de la barra y los vacíos atenuados.
- **CPU y RAM:** `system-usage.sh` dibuja dos medidores de cinco bloques (`C■■■■■
  M■■■■■`), verdes, ámbar desde 60 % y rojos desde 85 %.
- **Segmentos de terminal:** los módulos con `"brackets": true` se enmarcan como
  una statusline de tmux (`[ … ]`); reemplazan a los antiguos separadores `|`.
- **Cursor:** mientras hay notificaciones en pantalla, un cursor de terminal
  parpadea junto a la W del menú.
- **Tooltips:** todo módulo describe qué es al pasar el ratón. Si el widget no
  trae tooltip propio, `wh01s17.bar` muestra el nombre de `moduleLabels` (o el
  `"label"` de la entrada en `shell.json`); cada escritorio indica cuántas
  ventanas tiene.
- **Colores:** los `classColors` de `shell.json` y los colores de
  `ctf-ip.sh` y `services-monitor.sh` usan la paleta wh01s17 (`#84c959`,
  `#e8b53f`, `#ff6b66`, `#45d9ea`, `#748178`).

### Módulos propios y clones

Los clones conservan la integración de wh01s17 con sus paneles originales,
pero permiten añadir comportamiento sin editar los archivos de la
distribución. Todos se declaran en `shell.json` y sus metadatos viven en el
`manifest.json` de cada directorio.

| Módulo | Base o función | Adición destacada |
| --- | --- | --- |
| `wh01s17.clock` | `core.clock` | Segundos, semana ISO y progreso anual/vital persistente |
| `wh01s17.audio` | `core.audio` | Salidas, entradas y mezclador por aplicación navegables |
| `wh01s17.bluetooth` | `core.bluetooth` | Conexión, olvido de dispositivos, reescaneo manual (botón o `r`) y selección de salida Bluetooth |
| `wh01s17.network` | `core.network` | Wi-Fi, reescaneo manual de redes, DNS, bandas, QR, prueba de velocidad y métricas de enlace |
| `wh01s17.monitor` | `core.monitor` | Escala persistente por salida y tooltip con resolución/escala |
| `wh01s17.power` | `core.power` | Batería como cinco corazones 8-bit (medios incluidos; rojos en batería, verdes enchufado), perfiles de energía y estadísticas del sistema |
| `wh01s17.metronome` | Propio | Click track con dial de tempo, tap tempo, subdivisiones y acento |
| `wh01s17.bar` | `core.bar` | Estado de hover por monitor (revelar los indicadores en una pantalla no redistribuye las barras de las demás) e islas flotantes |
| `wh01s17.indicators` | `core.indicators` | Lee ese estado por monitor desde `wh01s17.bar` y carga sus propios indicadores desde `indicators/` |

`wh01s17.bar` reemplaza la barra completa (`bar.id` en `shell.json`), así que
no recibe las mejoras posteriores de `Bar.qml` en wh01s17. Al actualizar
wh01s17, compara con `diff -u ~/.local/share/wh01s17/shell/plugins/bar/Bar.qml
desktop/.config/wh01s17/plugins/wh01s17.bar/Bar.qml`.

### Metrónomo

[`wh01s17.metronome`](desktop/.config/wh01s17/plugins/wh01s17.metronome/) usa
un proceso Python único para sintetizar el click en PCM y sincroniza el pulso
visual cuando el sonido llega a la salida. Así evita que los temporizadores de
QML acumulen deriva bajo carga. Su entrada en `shell.json` persiste BPM,
compás, subdivisión, volumen y acento entre sesiones.

En el icono de la barra: clic izquierdo abre el panel; clic derecho inicia o
detiene; clic central mide el tempo por golpes; la rueda ajusta ±1 BPM. En el
panel se puede arrastrar o usar la rueda sobre el dial, aplicar incrementos de
1/5/10 BPM, escoger de 1 a 16 pulsos por compás, activar el acento, elegir
negras, corcheas, tresillos, swing o semicorcheas y ajustar el nivel. También
acepta IPC bajo `wh01s17.metronome`: `play`, `pause`, `togglePlay`, `tap` y
`setBpm <valor>`.

### Git, firewall, unidades y actividad

La parte izquierda muestra la rama del repositorio del directorio activo. El
hook [`git-branch-hook.zsh`](desktop/.config/wh01s17/bar/scripts/git-branch-hook.zsh)
actualiza ese directorio al cambiar con `cd`; el panel informa la rama, cambios
sin commit y desfase con el remoto, y permite copiar la rama con un clic.

Los indicadores de la derecha son módulos de estado y no realizan cambios
automáticos:

| Indicador | Información | Acciones |
| --- | --- | --- |
| Firewall | Backend, servicio, política de entrada y reglas permitidas | Clic derecho: notificación con el detalle |
| Unidades montadas | Medios extraíbles e imágenes loop montadas | Clic: abrir; panel: abrir o expulsar mediante `udisksctl` |
| Actividad | CPU, RAM, swap y lectura/escritura de disco | Clic: abre btop; clic derecho: abre Alacritty |

Los scripts guardan sus muestras o el último dispositivo visto en
`${XDG_STATE_HOME:-$HOME/.local/state}/wh01s17/bar/`; se puede redirigir cada
uno con `GIT_BRANCH_STATE_DIR`, `MOUNTS_STATE_DIR` o `SYSTEM_USAGE_STATE_DIR`.

### Idle, salvapantallas y bloqueo

En [`shell.json`](desktop/.config/wh01s17/shell.json), `idle.screensaver` está
en `150` segundos y `idle.lock` en `300`: el salvapantallas aparece tras 2:30
minutos y la sesión se bloquea tras 5 minutos. Ambos valores cuentan desde la
última actividad:

```json
"idle": {
  "screensaver": 150,
  "lock": 300
}
```

El arte ASCII mostrado por el salvapantallas vive en
[`branding/screensaver.txt`](desktop/.config/wh01s17/branding/screensaver.txt).
Los cambios de `shell.json` se recargan al guardar; si no se reflejan, ejecuta
`wh01s17 restart shell`.

El lock nativo `core.lock` está deshabilitado y lo reemplaza
`io.github.sirjul1337.lock-explorer` con diseño `neon`. La entrada
`cloneSourceRestores` en `shell.json` hace que wh01s17 restaure su fuente
clonada al reconstruir los plugins; no se versiona una copia del plugin de
terceros en este repositorio.

### Reloj y calendario

[`wh01s17.clock`](desktop/.config/wh01s17/plugins/wh01s17.clock/) es un clon
de `core.clock` con precisión de segundos, semana ISO y preferencias
persistentes dentro de su entrada de `shell.json`.

Controles de la barra:

- clic izquierdo: abrir o cerrar el calendario;
- clic central: abrir el selector de zona horaria;
- clic derecho: recorrer los formatos de fecha y hora y guardar el elegido.

Dentro del calendario, la rueda y las flechas izquierda/derecha cambian de
mes; arriba/abajo cambia de año; `T` vuelve a hoy y `W` alterna el comienzo de
semana. También funcionan `[`/`]` para meses y `{`/`}` para años. El encabezado
`W` se puede pulsar y las flechas inferiores permiten navegar con el mouse.

La barra bajo el año muestra el progreso anual. Un doble clic sobre ella
permite guardar año de nacimiento y expectativa de vida para mostrar una
segunda barra opcional; otro doble clic sobre esa segunda barra la elimina.
`Model.js` contiene los cálculos de calendario y progreso, `BarWidget.qml` la
etiqueta y sus controles, y `Panel.qml` el calendario emergente.

### Componente de estado

[`StatusModule.qml`](desktop/.config/wh01s17/bar/modules/StatusModule.qml) ejecuta scripts mediante `bash`, interpreta JSON compatible con Waybar y ofrece:

- actualización periódica;
- tooltip;
- clic izquierdo, central y derecho;
- acciones de scroll;
- colores por clase;
- actualización inmediata después de una acción.

Cada entrada QML puede usar `exec`, `interval`, texto y tooltip estáticos,
márgenes, tamaño de fuente, `classColors`, `dimClasses` y comandos para los
tres botones o la rueda. Cuando `panel` es `true`, el clic izquierdo abre un
panel con cabecera, progreso, filas y acciones provenientes del JSON; el clic
central y el derecho conservan sus comandos directos. Todos los comandos son
configuración de confianza y se ejecutan mediante `bash -c`.

Se usa `bash -c` y no `bash -lc` a propósito: un shell de login sourcea
`/etc/profile` y `~/.profile` en cada invocación, lo que costaba unos 7 ms por
llamada sin aportar nada, ya que el `PATH` que hereda Quickshell ya resuelve
todos los comandos que la barra necesita.

wh01s17 instancia la barra completa una vez por monitor, así que cada
`interval` se multiplica por el número de pantallas. Conviene elegir el
intervalo más alto que el módulo tolere, y que los scripts con estado
compartido serialicen sus escrituras (ver `system-usage.sh`).

## Panel CTF

[`ctf-ip.sh`](desktop/.config/wh01s17/bar/scripts/ctf-ip.sh) muestra en la
barra la IP de la víctima, la VPN y la red local. Segmentos, controles y
comandos de Zsh en [`docs/ctf.md`](docs/ctf.md).

## Pomodoro

[`pomodoro.sh`](desktop/.config/wh01s17/bar/scripts/pomodoro.sh) ofrece cuatro
sistemas de trabajo y descanso (equilibrado, clásico, enfoque profundo y
ultradiano). Controles y estado en [`docs/pomodoro.md`](docs/pomodoro.md).

## Clima

El clima usa el componente oficial `core.weather` del runtime, incluida su vista detallada y la configuración de ubicación integrada.

## Servicios y reverse shells

[`services-monitor.sh`](desktop/.config/wh01s17/bar/scripts/services-monitor.sh) inspecciona sockets TCP y clasifica:

| Color | Estado |
| --- | --- |
| Verde | Servicio de desarrollo sólo en loopback |
| Naranjo | Servicio expuesto a la red |
| Rojo | Listener o sesión probable de reverse shell |

Controles:

- clic izquierdo: abrir el panel de actividad;
- clic central: copiar un endpoint;
- clic derecho: mostrar el resumen.

El panel incluye botones para abrir un servicio HTTP, copiar un endpoint o
mostrar el resumen. Si hay varias opciones, usa `wh01s17 menu select`; los
servicios enlazados a `0.0.0.0` o `::` se abren mediante loopback.

Las variables `SERVICES_DEV_PORTS`, `SERVICES_HTTP_PORTS` y `SERVICES_REVERSE_PORTS` permiten reemplazar las listas predeterminadas.

`SERVICES_LISTEN_FILE` y `SERVICES_ESTABLISHED_FILE` aceptan capturas de `ss`
en lugar del estado real, lo que permite probar el detector. La clasificación
de reverse shells es heurística: combina puertos conocidos, procesos como
`nc`, `socat`, `pwncat` o `chisel`, y sesiones de shells con conexiones TCP;
debe interpretarse como aviso, no como prueba concluyente.

## Accesos auxiliares de la barra

- Portapapeles: clic en `󰅍` abre `wh01s17 menu clipboard`; el tooltip recuerda
  el atajo `Super+Ctrl+V`.
- CPU: clic en `󰍛` abre btop y clic derecho abre Alacritty. Como la barra
  corre una copia por monitor, [`system-usage.sh`](desktop/.config/wh01s17/bar/scripts/system-usage.sh)
  toma un `flock` y comparte el resultado en
  `${XDG_STATE_HOME:-$HOME/.local/state}/wh01s17/bar/system-usage`: la primera
  copia calcula el delta de CPU y disco, y las demás reutilizan esa respuesta
  durante `SYSTEM_USAGE_MIN_REFRESH_US` (1,5 s por omisión). Sin eso las copias
  se pisaban el archivo de muestras y dos de cada tres informaban 0 %.
- Agentes y actualizaciones siguen siendo widgets nativos. Red, audio,
  monitores, Bluetooth y energía usan los clones `wh01s17.*` descritos arriba;
  mantienen los paneles y acciones de wh01s17 y añaden los controles propios.

## Tema `wh01s17`

[`themes/wh01s17`](desktop/.config/wh01s17/themes/wh01s17/) es una variante
oscura inspirada en `wh01s17.com`, con acentos verde fósforo, cian, ámbar, rojo
y púrpura. Paleta, wallpapers y regeneración en [`docs/tema.md`](docs/tema.md).

## Fastfetch

[`config.jsonc`](desktop/.config/fastfetch/config.jsonc) presenta tres bloques:

- hardware: equipo, CPU, GPU, pantallas, discos, RAM y swap;
- software: versión, rama y canal de wh01s17, kernel, escritorio, terminal,
  paquetes, tema y fuente;
- estado: antigüedad de la instalación, uptime y última actualización.

El logo es la W de [`brand/logo.svg`](desktop/.config/wh01s17/themes/wh01s17/brand/logo.svg)
renderizada en 3D con caracteres ASCII por
[`w-spin.py`](desktop/.config/fastfetch/w-spin.py), al estilo del logo animado
de Codex. Las tres barras y los dos pies de la W se extruyen como cajas; cada
celda del lienzo de 40×20 combina cuatro rayos en perspectiva para suavizar
los bordes. La iluminación y la profundidad se traducen a una rampa ASCII
de 23 tonos teñida con el `accent` del tema activo (frente claro,
costado en sombra). La W va inclinada hacia la izquierda y un reflejo suave
recorre las caras al girar. Debajo va `wh01s17 OS` con los glifos pixelados de 5×7
de los wallpapers pixel art (letras claras, números en `accent`), dibujado con
octantes Unicode: cada celda son 2×4 píxeles cuadrados, así que el rótulo cabe
en 28 columnas. Kitty dibuja los octantes por sí mismo; en otros terminales
dependen de la fuente. `config.jsonc` usa W y rótulo como logo `command-raw` en
su pose de reposo, así que también aparecen al llamar a `fastfetch` con
opciones.

El lanzador [`wh01s17.sh`](desktop/.config/fastfetch/wh01s17.sh) centra la W
y el rótulo verticalmente junto a los paneles de información. Cuando el informe ya está en
pantalla, `w-spin.py --play` hace girar la W una vuelta en su sitio durante
2,4 s (`WH01S17_SPIN_SECONDS` lo cambia), con aceleración y frenado suaves, y la deja en la misma pose de reposo;
Ctrl-C salta al final. En una redirección o cuando se entregan opciones a
`fastfetch`, el lanzador omite la animación y delega directamente al binario
para no introducir movimientos de cursor.

El alias definido en `.zshrc` mantiene el comando habitual:

```bash
fastfetch
```

El lanzador reenvía todas las opciones a `/usr/bin/fastfetch`. Para omitir la
animación puntualmente, ejecuta `/usr/bin/fastfetch` de forma directa.

## Kitty

Kitty incluye directamente el tema generado por el runtime:

```text
~/.local/state/wh01s17/current/theme/kitty.conf
```

Esto permite que `wh01s17 theme set <tema>` cambie sus colores. La
configuración personal en
[`kitty.conf`](terminal/.config/kitty/kitty.conf) establece:

- MesloLGS Nerd Font Mono y sus variantes;
- opacidad interna de fondo `0.85`;
- padding horizontal y vertical de 10 px;
- tabs con separadores Powerline, títulos truncados y colores de la paleta del
  tema (`color2` para la activa, `color8`/`color7` para las inactivas);
- `Ctrl`+flechas para redimensionar paneles;
- secuencias CSI-u distintas para `Shift+Enter` y `Alt+Shift+Enter`;
- Zsh como shell, control remoto y socket por proceso para la integración de
  wh01s17.

La opacidad `0.85` pertenece al fondo que dibuja Kitty. Si además se aplica
una regla de opacidad de Hyprland, ambos efectos intervienen visualmente; ajusta
primero Kitty y después la regla global para evitar texto excesivamente tenue.

El selector local carga 11 pt en `hp-gray` y 14 pt en `omen`. Después de
cambiar `kitty.conf` o el perfil, aplica la configuración con:

```bash
wh01s17 restart terminal
```

## Zsh y utilidades de terminal

[`terminal/.zshrc`](terminal/.zshrc) inicializa Oh My Zsh, Starship,
Zoxide y NVM; carga los plugins `git`, `zsh-syntax-highlighting`,
`zsh-autosuggestions` y `zsh-sudo`; define `nvim` como editor y antepone
`~/.local/bin` al `PATH`.

NVM no se carga al iniciar porque costaba casi un segundo por terminal. El
`.zshrc` sigue la cadena del alias `default` (`default` → `lts/*` →
`lts/<nombre>` → `vX.Y.Z`), agrega el `bin` de esa versión al `PATH` y, si no
la encuentra instalada, usa la más nueva. La función `nvm` carga NVM la primera
vez que se ejecuta. Los shims de mise se quitan del `PATH` para que `node` y
`npm` sean siempre los de NVM.

[`terminal/.config/starship.toml`](terminal/.config/starship.toml) configura
el prompt de Starship. Parte de la configuración por defecto y sólo agrega lo
necesario: el usuario siempre visible, el código de salida al final de la línea
de información, las líneas agregadas y borradas sin commit (`git_metrics`) y
los iconos de estado Git de wh01s17 con contadores de stash, modificados,
staged y untracked. El resto del archivo son los iconos del preset
`nerd-font-symbols`.

Starship no agrega una línea vacía antes del primer prompt (`add_newline =
false`); los hooks `preexec` y `precmd` de `.zshrc` separan el prompt sólo
después de cada comando ejecutado. `starship explain` describe los segmentos
del prompt actual y `starship timings` muestra cuánto tarda cada uno.

Funciones propias:

| Comando | Uso |
| --- | --- |
| `extractPorts <archivo-nmap>` | Extrae puertos abiertos y la primera IPv4; copia los puertos mediante `xclip` |
| `mkt` | Crea `nmap/`, `content/`, `exploits/` y archivos de notas/flags en el directorio actual |
| `git_config <usuario> <email>` | Configura identidad y editor globales de Git, y las credenciales de GitHub mediante `gh` |
| `git_update_all [carpeta]` | Actualiza los repositorios hijos directos (incluidos ocultos), por defecto en la carpeta actual, usando solo fast-forward |
| `ipinfo <IP> [--whois\|--geo\|--info]` | Consulta WHOIS o servicios externos de geolocalización/IP |
| `subdomain_enum <dominio>` | Combina resultados pasivos de Subfinder y Amass y elimina duplicados |
| `target`, `myip`, `ctfcopy`, `ctfclear` | Controlan el estado compartido del panel CTF |

`git_update_all "$HOME/workspace"` omite repositorios con cambios locales
(incluidos archivos sin seguimiento), operaciones Git en curso, HEAD separado
o sin upstream disponible. Conserva los commits locales y rechaza historias
divergentes. Continúa tras cada error, muestra un resumen y devuelve un estado
distinto de cero si hubo errores u omisiones. No recorre subcarpetas de forma
recursiva.

Aliases destacados: `ls`, `ll`, `la`, `l` y `lla` usan Eza; `cat` usa Bat;
`icat` usa `kitten icat`; `cd` usa Zoxide y `fastfetch` hace girar la W
del logo.

Advertencias de seguridad:

- `ipinfo` depende de una credencial de API. No publiques credenciales dentro
  de `.zshrc`: muévela a una variable de entorno o almacén de secretos y rota
  cualquier valor que ya haya sido versionado.
- Las consultas de `ipinfo` envían la IP indicada a servicios externos.

Recarga la sesión después de editar:

```bash
exec zsh
```

## Mantenimiento del disco

Btrfs reparte el disco en chunks de datos y de metadatos. Si los chunks de
datos ocupan todo el espacio sin asignar, los metadatos no pueden crecer y el
sistema responde `No space left on device` aunque `df` muestre espacio libre.
Recuperarse exige agregar un dispositivo temporal y hacer un balance; estas
tareas evitan llegar a ese punto.

Tareas de usuario (paquete `maintenance`):

| Timer | Frecuencia | Acción |
| --- | --- | --- |
| `btrfs-space-check` | Cada hora | Notifica si quedan menos de 15 GiB libres o menos de 5 GiB sin asignar. Lee `/sys`, no necesita root |
| `codex-staging-clean` | Diaria | Borra de `~/.codex/.tmp/marketplaces/.staging` las copias de actualizaciones de plugins con más de un día |
| `mise-prune` | Semanal | `mise prune --yes`: elimina versiones que ninguna configuración usa y conserva las que están en ejecución |
| `cache-prune` | Semanal | Poda con su propia herramienta las cachés que crecen sin control: `mise cache prune` (sin acceso en 30 días), `yay -Sc --aur` y `pnpm store prune`. El resto de `~/.cache` no se toca |

Los umbrales del aviso se cambian con `WARN_FREE_GIB` y `WARN_UNALLOC_GIB`.

Stow sólo crea los enlaces; los timers se activan aparte:

```bash
systemctl --user daemon-reload
systemctl --user enable --now \
  btrfs-space-check.timer codex-staging-clean.timer mise-prune.timer cache-prune.timer
```

Tareas de sistema (`system/btrfs/`, requiere que `/` sea btrfs):

| Componente | Acción |
| --- | --- |
| `btrfs-balance-auto.timer` | Balance semanal sólo de datos (`-dusage` 0, 10, 25 y 50), con prioridad baja; también con batería, para no saltarse la semana ni ignorar un arranque manual |
| `/etc/tmpfiles.d/btrfs-reclaim.conf` | Activa `dynamic_reclaim` y `periodic_reclaim` del kernel (los que tenga) en cada arranque; el instalador lo genera con el UUID de `/` |
| Snapper (`root`) | `NUMBER_LIMIT=5`: conserva cinco snapshots |
| `paccache.timer` | Semanal (de `pacman-contrib`); el drop-in `paccache.conf` deja dos versiones de cada paquete instalado y ninguna de los desinstalados |

```bash
sudo "$HOME/dotfiles/system/btrfs/install.sh"
```

El instalador copia los archivos, por lo que hay que volver a ejecutarlo
después de editarlos. Termina lanzando un primer balance y mostrando su
registro.

`NUMBER_LIMIT` es fijo: un rango (`2-5`), igual que `SPACE_LIMIT` y
`FREE_LIMIT`, requiere cuotas de btrfs, y sin ellas `snapper cleanup` falla con
`quota not working (qgroup not set)`. El balance omite los metadatos a propósito:
compactarlos les quita margen, que es justamente lo que provoca el bloqueo.

Revisión:

```bash
systemctl --user list-timers
systemctl list-timers btrfs-balance-auto.timer snapper-cleanup.timer
journalctl --user -u btrfs-space-check -n 5
sudo btrfs filesystem usage -T /
```

## Mapa de implementación

Esta tabla cubre los archivos auxiliares que normalmente no se editan durante
el uso diario:

| Ruta | Propósito |
| --- | --- |
| [`.gitignore`](.gitignore) | Ignora backups de wh01s17, bytecode/cachés de Python y los dos selectores locales de equipo |
| [`monitor_scales.lua`](desktop/.config/hypr/monitor_scales.lua) | Recupera la última escala registrada por cada salida |
| `hypr/profiles/*.lua` | Reglas versionadas de monitores para `hp-gray` y `omen` |
| `kitty/profiles/*.conf` | Tamaños de fuente versionados para los mismos perfiles |
| [`fastfetch/wh01s17.sh`](desktop/.config/fastfetch/wh01s17.sh) | Giro de la W 3D y delegación al binario real de Fastfetch |
| [`ctf-aliases.zsh`](desktop/.config/wh01s17/bar/scripts/ctf-aliases.zsh) | Puente entre `.zshrc` y `ctf-ip.sh` |
| [`manifest.json`](desktop/.config/wh01s17/plugins/wh01s17.clock/manifest.json) | Declara el reloj como plugin de barra clonado de `core.clock` |
| `wh01s17.{audio,bluetooth,network,power}/` | Clones de los paneles oficiales con sus modelos y controles ampliados |
| [`wh01s17.metronome/`](desktop/.config/wh01s17/plugins/wh01s17.metronome/) | Widget, núcleo compartido, dial, modelo y motor PCM del metrónomo |
| `bar/scripts/{firewall-status,git-branch,mounted-devices,system-usage}.sh` | Indicadores de seguridad, repositorio, medios extraíbles y actividad |
| `wh01s17.monitor/Panel.qml` | Clon de `core.monitor` que recarga el perfil tras cambiar una escala |
| `wh01s17.clock/BarWidget.qml` | Etiqueta, precisión por segundo, clics e IPC del reloj |
| `wh01s17.clock/Model.js` | Fechas, semanas ISO, formatos y progreso anual/vital |
| `wh01s17.clock/Panel.qml` | Calendario, navegación y controles persistentes |
| `themes/wh01s17/shell.*.toml` | Fragmentos visuales que wh01s17 combina al aplicar el tema |
| `themes/wh01s17/backgrounds/*.png` | Salidas 4K; `01`–`02` se regeneran desde `sources/*.svg` y `03`–`05` con `sources/pixel-art.py` |

## Pruebas

Validación estática:

```bash
./test.sh
```

[`test.sh`](test.sh) revisa los archivos del repositorio, no los de `$HOME`:

| Comprobación | Alcance |
| --- | --- |
| Stow | Simula los cinco paquetes, sin modificar archivos |
| `jq`, `luac`, `node --check`, `ast` de Python | Todos los JSON, Lua, JavaScript y Python versionados; a los modelos QML se les quita `.pragma library` |
| `bash -n` y ShellCheck | Cada `*.sh` y cada script con shebang de Bash |
| `zsh -n` | `.zshrc` y los `*.zsh` |
| Hyprland, `qmllint`, `systemd-analyze` | Sólo en la sesión local y si están instalados |

`qmllint` revisa sólo los archivos cuyos imports resuelve: en la mayoría de los
widgets, termina con código 255 sin
mostrar ningún diagnóstico.

Instala ShellCheck con `sudo pacman -S shellcheck`.
Sin él, `test.sh` omite esa comprobación localmente.

El workflow [`test.yml`](.github/workflows/test.yml) ejecuta el mismo script
en GitHub Actions en cada push y pull request. Con `CI` definida, una
herramienta faltante es un error en vez de omitirse, y las comprobaciones que
necesitan la sesión gráfica no se ejecutan.

Validación de la sesión:

```bash
hyprctl reload
hyprctl configerrors
wh01s17 restart shell
wh01s17 restart terminal
fastfetch
```

## Actualizar o retirar

```bash
cd "$HOME/dotfiles"
git pull --ff-only
dotfiles-sync --force
wh01s17 restart shell
wh01s17 restart terminal
```

Para retirar únicamente los enlaces:

```bash
cd "$HOME/dotfiles"
stow --delete --target="$HOME" platform desktop terminal maintenance
stow --delete --no-folding --target="$HOME" apps
```

Antes de retirar `maintenance`, desactiva sus timers con
`systemctl --user disable --now dotfiles-sync.timer btrfs-space-check.timer codex-staging-clean.timer mise-prune.timer cache-prune.timer`.
La parte de sistema se retira con
`sudo systemctl disable --now btrfs-balance-auto.timer` y borrando los
archivos que copió `install.sh`.

`stow --delete` retira sólo los enlaces que administra; no elimina el
repositorio, los selectores locales, el estado de CTF/Pomodoro ni las copias
`.before-dotfiles` creadas al instalar.

## Licencia

[MIT](LICENSE). El runtime y algunos plugins derivan de Omarchy; se conservan
su licencia MIT y los avisos de origen en [platform](platform/README.md).
El escritorio se instala sobre Arch y no necesita Omarchy ni sus repositorios.
