# Dotfiles para Omarchy Quattro

Configuración personal para **Omarchy 4 (Quattro)**, **Hyprland 0.56+**, **Omarchy Shell/Quickshell**, **Kitty** y **Zsh**, administrada con [GNU Stow](https://www.gnu.org/software/stow/).

Stow trata cada directorio de primer nivel como un paquete y crea enlaces simbólicos dentro de `$HOME`. La fuente real continúa versionada en este repositorio.

## Estructura

```text
dotfiles/
├── desktop/
│   └── .config/
│       ├── fastfetch/                  # Informe, wordmark ANSI y logo de Gengar
│       ├── hypr/                       # Configuración Lua de Hyprland
│       │   └── profiles/              # Monitores por equipo
│       └── omarchy/
│           ├── shell.json              # Barra, widgets e idle de Omarchy Shell
│           ├── bar/
│           │   ├── modules/            # Componente QML reutilizable
│           │   └── scripts/            # CTF, Pomodoro y servicios
│           ├── branding/               # Marca ASCII para el salvapantallas
│           ├── plugins/
│           │   └── wh01s17.clock/      # Reloj y calendario propios
│           └── themes/
│               └── wh01s17/            # Tema, wallpapers y maestros SVG
├── terminal/
│   ├── .config/kitty/
│   │   ├── kitty.conf             # Base común y tema dinámico
│   │   └── profiles/              # Tamaño de fuente por equipo
│   └── .zshrc
└── README.md
```

Los paquetes Stow son:

| Paquete | Destino | Contenido |
| --- | --- | --- |
| `desktop` | `~/.config/` | Fastfetch, Hyprland y Omarchy Shell |
| `terminal` | `$HOME` y `~/.config/` | Zsh y Kitty |

## Requisitos

La configuración está pensada para Omarchy Quattro. Además de Git y GNU
Stow, los módulos propios necesitan estas herramientas:

```bash
sudo pacman -S --needed \
  git stow curl jq iproute2 wl-clipboard libnotify util-linux xdg-utils
```

Cada comando cubre una dependencia concreta: `ip` y `ss` provienen de
`iproute2`, `wl-copy` de `wl-clipboard`, `notify-send` de `libnotify`, `flock`
de `util-linux` y `xdg-open` de `xdg-utils`.

La sesión de terminal espera además:

- Oh My Zsh, Powerlevel10k y los plugins `zsh-syntax-highlighting`,
  `zsh-autosuggestions` y `zsh-sudo`;
- `eza`, `bat`, `zoxide`, `xclip`, `host` y `whois` para los aliases y
  funciones de `~/.zshrc`;
- NVM y un Node predeterminado, porque la inicialización ejecuta
  `nvm use default`;
- MesloLGS Nerd Font Mono para Kitty y los glifos de la barra;
- Fastfetch para el informe visual del sistema.

Solaar y WayScriber son opcionales, pero sus entradas de autostart y atajos
sólo funcionarán cuando estén instalados. `subfinder`, `amass`, LM Studio,
OpenCode, John the Ripper y el entorno local de Perl también son opcionales y
sólo afectan las funciones o rutas de Zsh que los nombran.

Para regenerar los wallpapers SVG se necesita `rsvg-convert` (`librsvg`), y
para ejecutar `qmllint` durante el desarrollo se necesita Qt Declarative.

Waybar, Walker, Mako, hypridle e hyprlock no son necesarios: Quattro reemplaza esos componentes con Omarchy Shell/Quickshell.

## Instalación con Stow

### 1. Clonar

```bash
git clone https://github.com/wh01s17/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
```

### 2. Simular y resolver conflictos

```bash
stow --simulate --verbose=2 --target="$HOME" desktop terminal
```

Si Stow informa un conflicto, respalda únicamente la ruta indicada. En una
instalación existente de Quattro, los conflictos más habituales son
`shell.json` y el branding del salvapantallas:

```bash
mv "$HOME/.config/omarchy/shell.json" \
  "$HOME/.config/omarchy/shell.json.before-dotfiles"
mv "$HOME/.config/omarchy/branding/screensaver.txt" \
  "$HOME/.config/omarchy/branding/screensaver.txt.before-dotfiles"
```

Ejecuta sólo el `mv` correspondiente a una ruta que Stow haya marcado como
conflicto. No sobrescribas una copia `.before-dotfiles` existente.

No uses `stow --adopt` sin revisar sus efectos: puede incorporar archivos locales dentro del repositorio.

### 3. Crear los enlaces

```bash
stow --restow --target="$HOME" desktop terminal
```

Comprueba los destinos importantes:

```bash
readlink -f "$HOME/.config/hypr"
readlink -f "$HOME/.config/fastfetch/config.jsonc"
readlink -f "$HOME/.config/omarchy/shell.json"
readlink -f "$HOME/.config/omarchy/bar"
readlink -f "$HOME/.config/omarchy/branding/screensaver.txt"
readlink -f "$HOME/.config/omarchy/themes/wh01s17"
readlink -f "$HOME/.config/kitty"
readlink -f "$HOME/.zshrc"
```

### 4. Aplicar y validar

```bash
hyprctl reload
hyprctl configerrors
omarchy restart shell
omarchy restart terminal
exec zsh
```

`shell.json` y los módulos QML se recargan automáticamente al guardarse. El reinicio explícito del shell resulta útil después de instalar por primera vez todos los enlaces.

## Hyprland en Lua

[`hyprland.lua`](desktop/.config/hypr/hyprland.lua) carga primero los valores predeterminados de Omarchy y después estas personalizaciones:

| Archivo | Personalización |
| --- | --- |
| [`monitors.lua`](desktop/.config/hypr/monitors.lua) | Escala 1× y carga del perfil local de monitores |
| [`input.lua`](desktop/.config/hypr/input.lua) | Teclado US `altgr-intl`, Caps Lock, repetición y salida de tableta |
| [`bindings.lua`](desktop/.config/hypr/bindings.lua) | Multimedia y controles de WayScriber |
| [`looknfeel.lua`](desktop/.config/hypr/looknfeel.lua) | Gaps, bordes, radio, blur y transición de escritorios |
| [`autostart.lua`](desktop/.config/hypr/autostart.lua) | Inicio automático de Solaar |
| [`hyprsunset.conf`](desktop/.config/hypr/hyprsunset.conf) | Perfiles horarios de temperatura de color |
| [`xdph.conf`](desktop/.config/hypr/xdph.conf) | Selector de pantalla para `xdg-desktop-portal-hyprland` |
| [`.luarc.json`](desktop/.config/hypr/.luarc.json) | Stubs y globales `hl`/`o` para el servidor de lenguaje Lua |

Los controladores NVIDIA ya los detecta Omarchy Quattro, por lo que no se duplican variables específicas de GPU en la configuración personal.

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

### Entrada y atajos personales

[`input.lua`](desktop/.config/hypr/input.lua) activa Num Lock, usa repetición
de 40 caracteres por segundo tras 600 ms, reduce el scroll del touchpad a
`0.4` y dirige la tableta a `DP-1`. Cambia `tablet.output` si el monitor de
dibujo tiene otro nombre; obtén los nombres con `hyprctl monitors all`.

Los atajos adicionales no sustituyen los predeterminados de Omarchy:

| Atajo | Acción |
| --- | --- |
| `Ctrl+Alt+A` / `Ctrl+Alt+Z` | Subir / bajar volumen; admite repetición |
| `Ctrl+Alt+O` | Reproducir o pausar |
| `Ctrl+Alt+P` / `Ctrl+Alt+I` | Pista siguiente / anterior |
| `Super+Alt+A` | Mostrar u ocultar WayScriber |
| `Super+Alt+P` | Alternar passthrough de WayScriber |
| `Super+Alt+D` | Alternar dibujo/interacción de WayScriber |

### Blur y transparencia

El blur se define dentro de `decoration` en
[`looknfeel.lua`](desktop/.config/hypr/looknfeel.lua). La configuración actual
usa un desenfoque corto de tamaño 3 con dos pasadas:

```lua
decoration = {
  rounding = 3,

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

Omarchy aplica por defecto una opacidad muy leve a las ventanas etiquetadas
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
Hyprland multiplique esta regla por la opacidad predeterminada de Omarchy.
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

Aplica cambios de temperatura con `omarchy restart hyprsunset`; `hyprctl`
no valida este archivo.

[`xdph.conf`](desktop/.config/hypr/xdph.conf) permite tokens de captura por
defecto y usa `hyprland-preview-share-picker` para elegir la pantalla al
compartir. Sus cambios se aplican al reiniciar el portal o en el siguiente
inicio de sesión.

## Omarchy Shell

La barra se define en [`shell.json`](desktop/.config/omarchy/shell.json). Usa widgets nativos para las funciones integradas y un módulo QML reutilizable para los scripts personales.

### Distribución

| Zona | Módulos |
| --- | --- |
| Izquierda | Menú Omarchy, escritorios, separador y panel CTF |
| Centro | Reloj con segundos, distribución de teclado, clima, actualizaciones e indicadores de estado |
| Derecha | Bandeja, agentes, Pomodoro, portapapeles, servicios, Bluetooth, red, audio, monitores, CPU y energía |

El reloj `wh01s17.clock` es un clon persistente del widget oficial. Conserva
su calendario y controles, pero usa precisión de segundos para que el formato
`HH:mm:ss` se actualice continuamente en lugar de mostrar siempre `00`.

Los indicadores nativos agrupan dictado, grabación, recordatorios, luz nocturna, silencio de notificaciones y bloqueo de idle.

### Idle, salvapantallas y bloqueo

En [`shell.json`](desktop/.config/omarchy/shell.json), `idle.screensaver` está
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
[`branding/screensaver.txt`](desktop/.config/omarchy/branding/screensaver.txt).
Los cambios de `shell.json` se recargan al guardar; si no se reflejan, ejecuta
`omarchy restart shell`.

### Reloj y calendario

[`wh01s17.clock`](desktop/.config/omarchy/plugins/wh01s17.clock/) es un clon
de `omarchy.clock` con precisión de segundos, semana ISO y preferencias
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

[`StatusModule.qml`](desktop/.config/omarchy/bar/modules/StatusModule.qml) ejecuta scripts mediante `bash`, interpreta JSON compatible con Waybar y ofrece:

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
configuración de confianza y se ejecutan mediante `bash -lc`.

## Panel CTF

[`ctf-ip.sh`](desktop/.config/omarchy/bar/scripts/ctf-ip.sh) muestra:

| Segmento | Origen | Color |
| --- | --- | --- |
| Víctima | IP definida con `target` | Rojo |
| VPN | `tun0`, `tun1`, `tap0`, `tap1`, `wg0`, `wg1` o `ppp0` | Cian |
| WLAN | Interfaz de la ruta predeterminada, o `CTF_LAN_IFACES` | Verde |
| Ausente | Sin dato | Gris |

Controles de la barra:

- clic izquierdo: abrir el panel de conexiones;
- clic derecho: limpiar víctima.

El panel ofrece botones para copiar o limpiar el objetivo.

Comandos de Zsh:

```bash
target 10.10.11.42
myip
ctfcopy
ctfclear
```

Estado: `${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/bar/ctf`.

Configuración opcional por entorno:

| Variable | Uso |
| --- | --- |
| `CTF_VPN_IFACES` | Lista de interfaces VPN que se revisarán |
| `CTF_LAN_IFACES` | Lista explícita de interfaces LAN; reemplaza la detección por ruta predeterminada |
| `CTF_STATE_DIR` | Directorio alternativo para el objetivo persistente |

El script valida direcciones IPv4 antes de guardarlas y migra, si existe, el
estado antiguo de `~/.config/waybar/state/ctf`.

## Pomodoro

[`pomodoro.sh`](desktop/.config/omarchy/bar/scripts/pomodoro.sh) conserva cuatro sistemas:

| Sistema | Trabajo | Descanso | Descanso largo |
| --- | ---: | ---: | ---: |
| Equilibrado | 40 min | 10 min | 20 min cada 4 sesiones |
| Clásico | 25 min | 5 min | 15 min cada 4 sesiones |
| Enfoque profundo | 50 min | 10 min | 20 min cada 4 sesiones |
| Ultradiano | 90 min | 20 min | 30 min cada 2 sesiones |

Controles:

- clic izquierdo: abrir el panel Pomodoro;
- clic central: saltar fase;
- clic derecho: elegir sistema;
- scroll: ajustar ±1 minuto.

El panel permite iniciar/pausar, saltar, reiniciar y elegir sistema. Las mismas
acciones están disponibles desde terminal:

```bash
~/.config/omarchy/bar/scripts/pomodoro.sh toggle
~/.config/omarchy/bar/scripts/pomodoro.sh reset
~/.config/omarchy/bar/scripts/pomodoro.sh skip
~/.config/omarchy/bar/scripts/pomodoro.sh preset balanced
```

Los identificadores de preset son `balanced`, `classic`, `deep` y
`ultradian`. `POMODORO_PRESET` define el predeterminado y
`POMODORO_STATE_DIR` permite mover el estado. Los ajustes manuales están
limitados al rango de 1 minuto a 4 horas.

Durante una fase de enfoque activa, el script usa el servicio de notificaciones de Omarchy para activar DND. El estado vive en `${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/bar/pomodoro`.

## Clima

El clima usa el componente oficial `omarchy.weather` de Quattro, incluida su vista detallada y la configuración de ubicación integrada.

## Servicios y reverse shells

[`services-monitor.sh`](desktop/.config/omarchy/bar/scripts/services-monitor.sh) inspecciona sockets TCP y clasifica:

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
mostrar el resumen. Si hay varias opciones, usa `omarchy menu select`; los
servicios enlazados a `0.0.0.0` o `::` se abren mediante loopback.

Las variables `SERVICES_DEV_PORTS`, `SERVICES_HTTP_PORTS` y `SERVICES_REVERSE_PORTS` permiten reemplazar las listas predeterminadas.

`SERVICES_LISTEN_FILE` y `SERVICES_ESTABLISHED_FILE` aceptan capturas de `ss`
en lugar del estado real, lo que permite probar el detector. La clasificación
de reverse shells es heurística: combina puertos conocidos, procesos como
`nc`, `socat`, `pwncat` o `chisel`, y sesiones de shells con conexiones TCP;
debe interpretarse como aviso, no como prueba concluyente.

## Accesos auxiliares de la barra

- Portapapeles: clic en `󰅍` abre `omarchy menu clipboard`; el tooltip recuerda
  el atajo `Super+Ctrl+V`.
- CPU: clic en `󰍛` abre btop y clic derecho abre Alacritty.
- Los widgets nativos de agentes, red, audio, monitores, Bluetooth, energía y
  actualizaciones conservan los paneles y acciones de Omarchy.

## Tema `wh01s17`

[`themes/wh01s17`](desktop/.config/omarchy/themes/wh01s17/) implementa una
variante oscura inspirada en `wh01s17.com`: superficies casi negras, tipografía
monoespaciada y acentos verde fósforo, cian, ámbar, rojo y púrpura.

Actívala y recorre sus dos fondos con:

```bash
omarchy theme set wh01s17
omarchy theme current
omarchy theme bg next
```

Sus piezas son:

| Ruta | Responsabilidad |
| --- | --- |
| [`colors.toml`](desktop/.config/omarchy/themes/wh01s17/colors.toml) | Paleta usada para generar configuraciones de aplicaciones |
| [`hyprland.lua`](desktop/.config/omarchy/themes/wh01s17/hyprland.lua) | Bordes verde/cian, radio de 6 px y sombras del tema |
| [`icons.theme`](desktop/.config/omarchy/themes/wh01s17/icons.theme) | Selecciona `Yaru-prussiangreen-dark` |
| [`shell.*.toml`](desktop/.config/omarchy/themes/wh01s17/) | Barra, controles, tipografía, menús, lock, notificaciones, popups, polkit, espaciado y tooltips |
| [`backgrounds/`](desktop/.config/omarchy/themes/wh01s17/backgrounds/) | Dos wallpapers PNG 4K listos para usar |
| [`sources/`](desktop/.config/omarchy/themes/wh01s17/sources/) | Maestros SVG editables de los wallpapers |
| [`brand/logo.svg`](desktop/.config/omarchy/themes/wh01s17/brand/logo.svg) | Geometría oficial de la marca |

El tema se carga con los valores predeterminados y después se aplican las
preferencias personales de `~/.config/hypr`. Por eso el radio de 3 px de
`looknfeel.lua` prevalece sobre los 6 px propuestos por el tema, mientras sus
colores de borde y sombras se conservan. Tras editar un archivo del tema,
vuelve a aplicarlo con `omarchy theme set wh01s17`.

[`themes/wh01s17/README.md`](desktop/.config/omarchy/themes/wh01s17/README.md)
documenta la paleta y
[`DESIGN.md`](desktop/.config/omarchy/themes/wh01s17/DESIGN.md) las reglas de
composición. Para regenerar los PNG desde los maestros:

```bash
cd ~/.config/omarchy/themes/wh01s17
rsvg-convert --width 3840 --height 2160 \
  --output backgrounds/01-solid-mark.png sources/01-solid-mark.svg
rsvg-convert --width 3840 --height 2160 \
  --output backgrounds/02-outline-mark.png sources/02-outline-mark.svg
```

## Fastfetch

[`config.jsonc`](desktop/.config/fastfetch/config.jsonc) presenta tres bloques:

- hardware: equipo, CPU, GPU, pantallas, discos, RAM y swap;
- software: versión, rama y canal de Omarchy, kernel, escritorio, terminal,
  paquetes, tema y fuente;
- estado: antigüedad de la instalación, uptime y última actualización.

El logo [`gengar.png`](desktop/.config/fastfetch/gengar.png) se dibuja mediante
el protocolo gráfico directo de Kitty, a 40×20 celdas con proporción
conservada. La imagen no contiene el wordmark: el lanzador
[`wh01s17.sh`](desktop/.config/fastfetch/wh01s17.sh) compone
`WH01S17` con una variante condensada del arte de seis filas usado por
[`branding/screensaver.txt`](desktop/.config/omarchy/branding/screensaver.txt).
Conserva sus bloques, esquinas y remates, pero reduce cada glifo a cinco
columnas para no invadir los paneles. `W`, `H` y `S` usan el blanco brillante
ANSI; todos los números usan el único color `accent` leído del `colors.toml`
del tema activo. En `wh01s17` es verde fósforo y al cambiar de tema se adapta a
su color predominante. Sigue siendo texto seleccionable del terminal, no una
segunda imagen.

El lanzador aumenta temporalmente el margen superior del logo y pinta el
wordmark dentro de ese espacio mediante posicionamiento ANSI. De ese modo,
texto y Gengar forman una sola columna izquierda de 28 filas, centrada con los
paneles de información de la derecha. El rótulo no desplaza todo el informe ni
deja un bloque vacío a su derecha o debajo. En una redirección o cuando se
entregan opciones a `fastfetch`, el lanzador omite la composición interactiva y
delega directamente al binario para no introducir movimientos de cursor.

El alias definido en `.zshrc` mantiene el comando habitual:

```bash
fastfetch
```

El lanzador reenvía todas las opciones a `/usr/bin/fastfetch`. Para omitir el
wordmark puntualmente, ejecuta `/usr/bin/fastfetch` de forma directa.

En un terminal sin soporte para el protocolo gráfico de Kitty, la información
seguirá siendo útil, pero el logo puede no mostrarse correctamente.

## Kitty

Kitty incluye directamente el tema generado por Quattro:

```text
~/.local/state/omarchy/current/theme/kitty.conf
```

Esto permite que `omarchy theme set <tema>` cambie sus colores. La
configuración personal en
[`kitty.conf`](terminal/.config/kitty/kitty.conf) establece:

- MesloLGS Nerd Font Mono y sus variantes;
- opacidad interna de fondo `0.85`;
- padding horizontal y vertical de 10 px;
- tabs con separadores Powerline y títulos truncados;
- `Ctrl`+flechas para redimensionar paneles;
- secuencias CSI-u distintas para `Shift+Enter` y `Alt+Shift+Enter`;
- Zsh como shell, control remoto y socket por proceso para la integración de
  Omarchy.

La opacidad `0.85` pertenece al fondo que dibuja Kitty. Si además se aplica
una regla de opacidad de Hyprland, ambos efectos intervienen visualmente; ajusta
primero Kitty y después la regla global para evitar texto excesivamente tenue.

El selector local carga 11 pt en `hp-gray` y 14 pt en `omen`. Después de
cambiar `kitty.conf` o el perfil, aplica la configuración con:

```bash
omarchy restart terminal
```

## Zsh y utilidades de terminal

[`terminal/.zshrc`](terminal/.zshrc) inicializa Oh My Zsh, Powerlevel10k,
Zoxide y NVM; carga los plugins `git`, `zsh-syntax-highlighting`,
`zsh-autosuggestions` y `zsh-sudo`; define `nvim` como editor y agrega rutas
locales de Perl, Ruby, LM Studio, OpenCode y John the Ripper.

Funciones propias:

| Comando | Uso |
| --- | --- |
| `extractPorts <archivo-nmap>` | Extrae puertos abiertos y la primera IPv4; copia los puertos mediante `xclip` |
| `mkt` | Crea `nmap/`, `content/`, `exploits/` y archivos de notas/flags en el directorio actual |
| `git_config <usuario> <email> <token>` | Configura identidad, editor y credenciales globales de Git |
| `ipinfo <IP> [--whois\|--geo\|--info]` | Consulta WHOIS o servicios externos de geolocalización/IP |
| `subdomain_enum <dominio>` | Combina resultados pasivos de Subfinder y Amass y elimina duplicados |
| `target`, `myip`, `ctfcopy`, `ctfclear` | Controlan el estado compartido del panel CTF |

Aliases destacados: `ls`, `ll`, `la`, `l` y `lla` usan Eza; `cat` usa Bat;
`icat` usa `kitten icat`; `cd` usa Zoxide y `fastfetch` agrega el wordmark ANSI
antes del informe. El alias `john` y varias entradas de `PATH` contienen rutas
específicas de este usuario y deben adaptarse si el repositorio se instala con
otro nombre de cuenta o estructura de directorios.

Advertencias de seguridad:

- `git_config` configura `credential.helper store` y guarda el token sin
  cifrar en `~/.git-credentials`; no lo uses en una máquina compartida.
- `ipinfo` depende de una credencial de API. No publiques credenciales dentro
  de `.zshrc`: muévela a una variable de entorno o almacén de secretos y rota
  cualquier valor que ya haya sido versionado.
- Las consultas de `ipinfo` envían la IP indicada a servicios externos.

Recarga la sesión después de editar:

```bash
exec zsh
```

## Mapa de implementación

Esta tabla cubre los archivos auxiliares que normalmente no se editan durante
el uso diario:

| Ruta | Propósito |
| --- | --- |
| [`.gitignore`](.gitignore) | Ignora backups de Omarchy y los dos selectores locales de equipo |
| `hypr/profiles/*.lua` | Reglas versionadas de monitores para `hp-gray` y `omen` |
| `kitty/profiles/*.conf` | Tamaños de fuente versionados para los mismos perfiles |
| [`fastfetch/wh01s17.sh`](desktop/.config/fastfetch/wh01s17.sh) | Wordmark textual 8-bit y delegación al binario real de Fastfetch |
| [`ctf-aliases.zsh`](desktop/.config/omarchy/bar/scripts/ctf-aliases.zsh) | Puente entre `.zshrc` y `ctf-ip.sh` |
| [`manifest.json`](desktop/.config/omarchy/plugins/wh01s17.clock/manifest.json) | Declara el reloj como plugin de barra clonado de `omarchy.clock` |
| `wh01s17.clock/BarWidget.qml` | Etiqueta, precisión por segundo, clics e IPC del reloj |
| `wh01s17.clock/Model.js` | Fechas, semanas ISO, formatos y progreso anual/vital |
| `wh01s17.clock/Panel.qml` | Calendario, navegación y controles persistentes |
| `themes/wh01s17/shell.*.toml` | Fragmentos visuales que Omarchy combina al aplicar el tema |
| `themes/wh01s17/backgrounds/*.png` | Salidas 4K; se regeneran desde `sources/*.svg` |

## Pruebas

Validación estática:

```bash
stow --simulate --verbose=2 --target="$HOME" desktop terminal
Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua"
jq empty "$HOME/.config/omarchy/shell.json"
jq empty "$HOME/.config/fastfetch/config.jsonc"
qmllint -I /usr/share/omarchy/shell \
  "$HOME/.config/omarchy/bar/modules/StatusModule.qml" \
  "$HOME/.config/omarchy/plugins/wh01s17.clock/Panel.qml"
node --check \
  "$HOME/.config/omarchy/plugins/wh01s17.clock/Model.js"
bash -n "$HOME/.config/fastfetch/wh01s17.sh"
for script in "$HOME/.config/omarchy/bar/scripts/"*.sh; do
  bash -n "$script"
done
zsh -n "$HOME/.zshrc"
zsh -n "$HOME/.config/omarchy/bar/scripts/ctf-aliases.zsh"
```

La simulación de Stow no modifica archivos. `qmllint` puede mostrar avisos de
tipado procedentes de los componentes dinámicos de Omarchy; los errores de
sintaxis sí deben corregirse.

Validación de la sesión:

```bash
hyprctl reload
hyprctl configerrors
omarchy restart shell
omarchy restart terminal
fastfetch
```

## Actualizar o retirar

```bash
cd "$HOME/dotfiles"
git pull --ff-only
stow --restow --target="$HOME" desktop terminal
omarchy restart shell
omarchy restart terminal
```

Para retirar únicamente los enlaces:

```bash
cd "$HOME/dotfiles"
stow --delete --target="$HOME" desktop terminal
```

`stow --delete` retira sólo los enlaces que administra; no elimina el
repositorio, los selectores locales, el estado de CTF/Pomodoro ni las copias
`.before-dotfiles` creadas al instalar.
