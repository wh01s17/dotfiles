# Dotfiles para Omarchy Quattro

Configuración personal para **Omarchy 4 (Quattro)**, **Hyprland 0.56+**, **Omarchy Shell/Quickshell**, **Kitty** y **Zsh**, administrada con [GNU Stow](https://www.gnu.org/software/stow/).

Stow trata cada directorio de primer nivel como un paquete y crea enlaces simbólicos dentro de `$HOME`. La fuente real continúa versionada en este repositorio.

## Estructura

```text
dotfiles/
├── desktop/
│   └── .config/
│       ├── hypr/                   # Configuración Lua de Hyprland
│       └── omarchy/
│           ├── shell.json          # Barra, widgets e idle de Omarchy Shell
│           ├── plugins/
│           │   └── wh01s17.clock/  # Reloj oficial clonado con refresco por segundo
│           └── bar/
│               ├── modules/        # Componente QML para módulos propios
│               └── scripts/        # CTF, Pomodoro y servicios
├── terminal/
│   ├── .config/kitty/kitty.conf    # Kitty y tema dinámico de Omarchy
│   └── .zshrc
└── README.md
```

Los paquetes Stow son:

| Paquete | Destino | Contenido |
| --- | --- | --- |
| `desktop` | `~/.config/` | Hyprland y Omarchy Shell |
| `terminal` | `$HOME` y `~/.config/` | Zsh y Kitty |

## Requisitos

La configuración está pensada para Omarchy Quattro. Además de Git y GNU Stow, los módulos propios necesitan estas herramientas:

```bash
sudo pacman -S --needed git stow curl jq iproute2 wl-clipboard libnotify util-linux
```

Solaar y WayScriber son opcionales, pero sus entradas de autostart y atajos sólo funcionarán cuando estén instalados.

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

Si Stow informa un conflicto, respalda únicamente la ruta indicada. En una instalación existente de Quattro, el conflicto más habitual es `shell.json`:

```bash
mv "$HOME/.config/omarchy/shell.json" \
  "$HOME/.config/omarchy/shell.json.before-dotfiles"
```

No uses `stow --adopt` sin revisar sus efectos: puede incorporar archivos locales dentro del repositorio.

### 3. Crear los enlaces

```bash
stow --restow --target="$HOME" desktop terminal
```

Comprueba los destinos importantes:

```bash
readlink -f "$HOME/.config/hypr"
readlink -f "$HOME/.config/omarchy/shell.json"
readlink -f "$HOME/.config/omarchy/bar"
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
| [`monitors.lua`](desktop/.config/hypr/monitors.lua) | Escala 1×, panel `eDP-1` y proyector `HDMI-A-1` reflejado |
| [`input.lua`](desktop/.config/hypr/input.lua) | Teclado US `altgr-intl`, Caps Lock, repetición y salida de tableta |
| [`bindings.lua`](desktop/.config/hypr/bindings.lua) | Multimedia y controles de WayScriber |
| [`looknfeel.lua`](desktop/.config/hypr/looknfeel.lua) | Gaps de 2 px, borde de 1 px, radio de 3 px y transición de escritorios |
| [`autostart.lua`](desktop/.config/hypr/autostart.lua) | Inicio automático de Solaar |

Los controladores NVIDIA ya los detecta Omarchy Quattro, por lo que no se duplican variables específicas de GPU en la configuración personal.

## Omarchy Shell

La barra se define en [`shell.json`](desktop/.config/omarchy/shell.json). Usa widgets nativos para las funciones integradas y un módulo QML reutilizable para los scripts personales.

### Distribución

| Zona | Módulos |
| --- | --- |
| Izquierda | Menú Omarchy, escritorios, separador y panel CTF |
| Centro | Reloj con segundos, clima oficial de Omarchy, actualizaciones e indicadores de estado |
| Derecha | Bandeja, Pomodoro, portapapeles, servicios, Bluetooth, red, audio, CPU y energía |

El reloj `wh01s17.clock` es un clon persistente del widget oficial. Conserva
su calendario y controles, pero usa precisión de segundos para que el formato
`HH:mm:ss` se actualice continuamente en lugar de mostrar siempre `00`.

Los indicadores nativos agrupan dictado, grabación, recordatorios, luz nocturna, silencio de notificaciones y bloqueo de idle.

### Componente de estado

[`StatusModule.qml`](desktop/.config/omarchy/bar/modules/StatusModule.qml) ejecuta scripts mediante `bash`, interpreta JSON compatible con Waybar y ofrece:

- actualización periódica;
- tooltip;
- clic izquierdo, central y derecho;
- acciones de scroll;
- colores por clase;
- actualización inmediata después de una acción.

## Panel CTF

[`ctf-ip.sh`](desktop/.config/omarchy/bar/scripts/ctf-ip.sh) muestra:

| Segmento | Origen | Color |
| --- | --- | --- |
| Víctima | IP definida con `target` | Rojo |
| VPN | `tun0`, `tun1`, `tap0`, `tap1`, `wg0`, `wg1` o `ppp0` | Cian |
| WLAN | Interfaz de la ruta predeterminada, o `CTF_LAN_IFACES` | Verde |
| Ausente | Sin dato | Gris |

Controles de la barra:

- clic izquierdo: copiar víctima;
- clic derecho: limpiar víctima.

Comandos de Zsh:

```bash
target 10.10.11.42
myip
ctfcopy
ctfclear
```

Estado: `${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/bar/ctf`.

## Pomodoro

[`pomodoro.sh`](desktop/.config/omarchy/bar/scripts/pomodoro.sh) conserva cuatro sistemas:

| Sistema | Trabajo | Descanso | Descanso largo |
| --- | ---: | ---: | ---: |
| Equilibrado | 40 min | 10 min | 20 min cada 4 sesiones |
| Clásico | 25 min | 5 min | 15 min cada 4 sesiones |
| Enfoque profundo | 50 min | 10 min | 20 min cada 4 sesiones |
| Ultradiano | 90 min | 20 min | 30 min cada 2 sesiones |

Controles:

- clic izquierdo: iniciar o pausar;
- clic central: saltar fase;
- clic derecho: elegir sistema;
- scroll: ajustar ±1 minuto.

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

- clic izquierdo: abrir un servicio HTTP;
- clic central: copiar un endpoint;
- clic derecho: mostrar el resumen.

Las variables `SERVICES_DEV_PORTS`, `SERVICES_HTTP_PORTS` y `SERVICES_REVERSE_PORTS` permiten reemplazar las listas predeterminadas.

## Kitty y temas

Kitty incluye directamente el tema generado por Quattro:

```text
~/.local/state/omarchy/current/theme/kitty.conf
```

Esto permite que `omarchy theme set <tema>` cambie sus colores. La fuente, opacidad, tabs y atajos personales permanecen en [`kitty.conf`](terminal/.config/kitty/kitty.conf).

## Pruebas

Validación estática:

```bash
Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua"
jq empty "$HOME/.config/omarchy/shell.json"
qmllint -I /usr/share/omarchy/shell \
  "$HOME/.config/omarchy/bar/modules/StatusModule.qml"
bash -n "$HOME/.config/omarchy/bar/scripts/"*.sh
zsh -n "$HOME/.zshrc"
```

Validación de la sesión:

```bash
hyprctl reload
hyprctl configerrors
omarchy restart shell
```

## Actualizar o retirar

```bash
cd "$HOME/dotfiles"
git pull --ff-only
stow --restow --target="$HOME" desktop terminal
omarchy restart shell
```

Para retirar únicamente los enlaces:

```bash
cd "$HOME/dotfiles"
stow --delete --target="$HOME" desktop terminal
```
