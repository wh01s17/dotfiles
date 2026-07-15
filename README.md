# Dotfiles

Configuración personal para **Omarchy**, **Hyprland**, **Waybar**, **Kitty** y **Zsh**, administrada con [GNU Stow](https://www.gnu.org/software/stow/).

Stow trata cada directorio de primer nivel como un paquete y crea enlaces simbólicos dentro de `$HOME`. Por ejemplo, `desktop/.config/waybar` termina disponible como `~/.config/waybar`, pero la fuente real continúa versionada en este repositorio.

## Estructura

```text
dotfiles/
├── desktop/
│   └── .config/
│       ├── hypr/       # Hyprland, hypridle, hyprlock y monitores
│       └── waybar/     # Barra, estilos y scripts personalizados
├── terminal/
│   ├── .config/kitty/  # Kitty y tema Tokyo Night
│   └── .zshrc          # Shell, aliases y funciones
└── README.md
```

Los paquetes Stow activos son:

| Paquete | Destino principal | Contenido |
| --- | --- | --- |
| `desktop` | `~/.config/` | Hyprland y Waybar |
| `terminal` | `$HOME` y `~/.config/` | `.zshrc` y Kitty |

## Instalación con Stow

### 1. Requisitos

El entorno está pensado para una instalación de Omarchy con Hyprland. Además, necesita Git y GNU Stow:

```bash
sudo pacman -S --needed git stow
```

Los módulos personalizados de Waybar también usan estas herramientas:

```bash
sudo pacman -S --needed jq iproute2 wl-clipboard libnotify util-linux pamixer btop
```

Walker, Waybar y una Nerd Font normalmente ya vienen configurados por Omarchy. Los iconos de la barra requieren `JetBrainsMono Nerd Font`; Kitty usa `CodeNewRoman Nerd Font Mono`.

### 2. Clonar el repositorio

```bash
git clone https://github.com/wh01s17/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
```

### 3. Revisar posibles conflictos

Antes de crear enlaces, conviene simular la operación:

```bash
stow --simulate --verbose=2 --target="$HOME" desktop terminal
```

Si Stow informa que un archivo existente impediría crear un enlace, respáldalo primero. Por ejemplo:

```bash
mv "$HOME/.config/waybar" "$HOME/.config/waybar.before-dotfiles"
```

Haz lo mismo solamente con las rutas que Stow reporte como conflicto. No uses `stow --adopt` sin revisar sus efectos: esa opción puede incorporar archivos locales dentro del repositorio.

### 4. Crear los enlaces

```bash
stow --target="$HOME" desktop terminal
```

Para reinstalar enlaces después de mover o modificar paquetes:

```bash
stow --restow --target="$HOME" desktop terminal
```

Comprueba los destinos con:

```bash
readlink -f "$HOME/.config/waybar"
readlink -f "$HOME/.config/hypr"
readlink -f "$HOME/.config/kitty"
readlink -f "$HOME/.zshrc"
```

### 5. Aplicar la configuración

```bash
omarchy restart waybar
hyprctl reload
hyprctl configerrors
exec zsh
```

`style.css` se recarga automáticamente cuando cambia. Los cambios de `config.jsonc` o de la disposición de módulos requieren reiniciar Waybar.

### Actualizar o retirar los dotfiles

```bash
cd "$HOME/dotfiles"
git pull --ff-only
stow --restow --target="$HOME" desktop terminal
omarchy restart waybar
```

Para retirar solamente los enlaces, sin borrar el repositorio:

```bash
cd "$HOME/dotfiles"
stow --delete --target="$HOME" desktop terminal
```

## Waybar

La configuración principal está en [`desktop/.config/waybar/config.jsonc`](desktop/.config/waybar/config.jsonc) y sus estilos en [`desktop/.config/waybar/style.css`](desktop/.config/waybar/style.css). La barra mide 26 px, vive en la parte superior y hereda los colores del tema activo de Omarchy mediante `~/.config/omarchy/current/theme/waybar.css`.

### Distribución

| Zona | Módulos |
| --- | --- |
| Izquierda | Omarchy, escritorios Hyprland, separador y panel CTF |
| Centro | Reloj, Pomodoro, clima, actualizaciones, Voxtype, grabación, idle y silencio de notificaciones |
| Derecha | Historial del portapapeles, servicios/reverse shells, bandeja expandible, Bluetooth, red, audio, CPU y batería |

### Módulos de la izquierda

| Módulo | Qué muestra | Controles |
| --- | --- | --- |
| `custom/omarchy` | Logo de Omarchy | Clic izquierdo: menú de Omarchy. Clic derecho: terminal. |
| `hyprland/workspaces` | Escritorios 1–10; mantiene visibles 1–5 y marca el activo | Clic: cambiar al escritorio elegido. |
| `custom/workspace-separator` | Separador visual entre escritorios y CTF | Sin interacción. |
| `custom/ctf` | IP de la víctima, VPN y WLAN con colores e iconos distintos | Clic izquierdo: copiar la víctima. Clic derecho: limpiar la víctima. |

### Módulos del centro

| Módulo | Qué muestra | Controles |
| --- | --- | --- |
| `clock` | Día de la semana y hora; tiene un formato alternativo con fecha y número de semana | Clic derecho: selector de zona horaria de Omarchy. |
| `custom/pomodoro` | Fase actual, cuenta regresiva, estado y sesiones completadas | Clic izquierdo: iniciar/pausar. Central: saltar. Derecho: elegir sistema. Scroll: ±1 minuto. |
| `custom/weather` | Estado meteorológico proporcionado por Omarchy; se actualiza cada minuto | Clic: notificación con el detalle del clima. |
| `custom/update` | Icono cuando existe una actualización de Omarchy; comprueba cada 6 horas | Clic: abrir la actualización en una terminal flotante. |
| `custom/voxtype` | Estado de dictado: oculto, grabando o transcribiendo | Clic izquierdo: elegir modelo. Derecho: configuración. |
| `custom/screenrecording-indicator` | Indicador de grabación de pantalla | Clic: controlar la grabación mediante Omarchy. |
| `custom/idle-indicator` | Indica que la suspensión por inactividad fue modificada | Clic: activar o desactivar idle. |
| `custom/notification-silencing-indicator` | Indica que las notificaciones están silenciadas | Clic: activar o desactivar el silencio. |

### Módulos de la derecha

| Módulo | Qué muestra | Controles |
| --- | --- | --- |
| `custom/clipboard-history` | Acceso directo al historial del portapapeles de Walker | Clic izquierdo: abrir el mismo historial que `Super + Ctrl + V`. |
| `custom/services-monitor` | Puertos de desarrollo, servicios expuestos y listeners/sesiones probables de reverse shell | Clic izquierdo: abrir servicio web. Central: copiar endpoint. Derecho: resumen. |
| `group/tray-expander` | Flecha y bandeja del sistema dentro de un drawer animado | Posar el puntero sobre el grupo: revelar la bandeja. |
| `bluetooth` | Estado del controlador y conexiones | Clic: launcher Bluetooth de Omarchy. |
| `network` | Wi-Fi, Ethernet o desconectado; tooltip con SSID y frecuencia | Clic: launcher Wi-Fi. |
| `pulseaudio` | Nivel o estado del audio | Clic izquierdo: selector de audio. Derecho: mute. Scroll: volumen en pasos de 5 %. |
| `cpu` | Icono de CPU; actualiza cada 5 segundos | Clic izquierdo: abrir o enfocar `btop`. Derecho: abrir Alacritty. |
| `battery` | Estado de carga y alertas al 20 %/10 % | Clic izquierdo: menú de energía. Derecho: notificación con detalle. |

## Servicios y reverse shells

[`desktop/.config/waybar/scripts/services-monitor.sh`](desktop/.config/waybar/scripts/services-monitor.sh) consulta los sockets TCP cada dos segundos y permanece oculto cuando no encuentra nada relevante.

El módulo distingue estos estados:

| Color | Estado |
| --- | --- |
| Verde `#5fd75f` | Servicio de desarrollo escuchando solamente en loopback. |
| Naranjo `#ffaf5f` | Servicio enlazado a `0.0.0.0`, `::` u otra dirección accesible desde la red. |
| Rojo `#ff5f5f` | Listener o conexión probable de reverse shell. |

Detecta puertos habituales de Vite, Node, Python, bases de datos y herramientas web. Para reverse shells usa una heurística basada en procesos como `nc`, `ncat`, `socat` o `pwncat`, puertos frecuentes (`4444`, `1337`, `9001`, etc.) y conexiones TCP establecidas pertenecientes directamente a una shell. El tooltip siempre muestra proceso, bind y exposición; la etiqueta “probable” es importante porque no sustituye una inspección manual.

Controles:

- Clic izquierdo: elegir con Walker y abrir un servicio HTTP detectado.
- Clic central: elegir y copiar una URL o endpoint.
- Clic derecho: mostrar todos los servicios y sesiones en una notificación.

Uso desde terminal:

```bash
MONITOR="$HOME/.config/waybar/scripts/services-monitor.sh"

"$MONITOR" print   # salida JSON para Waybar
"$MONITOR" open    # abrir servicio HTTP
"$MONITOR" copy    # copiar endpoint
"$MONITOR" notify  # mostrar resumen
```

Se pueden reemplazar las listas predeterminadas mediante `SERVICES_DEV_PORTS`, `SERVICES_HTTP_PORTS` y `SERVICES_REVERSE_PORTS` en el entorno de Waybar.

Dependencias: `bash`, `ss`/iproute2, `jq`, `wl-copy`/wl-clipboard, `xdg-open`, `notify-send`/libnotify y Walker mediante `omarchy menu select`.

## Panel CTF

El módulo se implementa en [`desktop/.config/waybar/scripts/ctf-ip.sh`](desktop/.config/waybar/scripts/ctf-ip.sh) y sirve para tener a la vista las direcciones importantes de una máquina de laboratorio.

### Lectura y colores

| Segmento | Origen | Color |
| --- | --- | --- |
| Víctima | IP definida con `target` | Rojo `#ff5f5f` |
| VPN | Primera IPv4 encontrada en `tun0`, `tun1`, `tap0`, `tap1`, `wg0`, `wg1` o `ppp0` | Cian `#33ccff` |
| WLAN | Primera IPv4 encontrada en `wlan0` | Verde `#5fd75f` |
| Dato ausente | Interfaz o víctima no disponible | Gris `#777777` |

El tooltip enumera las tres direcciones y las interfaces examinadas. Si no existe ninguna dirección útil, el módulo se reduce a `CTF -`.

### Uso desde Zsh

[`terminal/.zshrc`](terminal/.zshrc) carga [`ctf-aliases.zsh`](desktop/.config/waybar/scripts/ctf-aliases.zsh), por lo que están disponibles estos comandos:

```bash
target 10.10.11.42  # validar y guardar la IPv4 de la víctima
myip                # imprimir VPN/WLAN y refrescar Waybar
ctfcopy             # copiar la víctima al portapapeles
ctfclear            # borrar la víctima
```

También se puede llamar al script directamente:

```bash
~/.config/waybar/scripts/ctf-ip.sh print
~/.config/waybar/scripts/ctf-ip.sh target 10.10.11.42
~/.config/waybar/scripts/ctf-ip.sh clear
```

La víctima queda en `~/.config/waybar/state/ctf/target`. Ese estado está excluido de Git. Las variables `CTF_VPN_IFACES`, `CTF_LAN_IFACES` y `CTF_STATE_DIR` permiten cambiar las interfaces o la ruta de estado cuando el proceso de Waybar las recibe.

Dependencias: `bash`, `jq`, `ip`/iproute2, `awk` y `wl-copy`/wl-clipboard.

## Pomodoro

El temporizador está implementado en [`desktop/.config/waybar/scripts/pomodoro.sh`](desktop/.config/waybar/scripts/pomodoro.sh). El sistema predeterminado es **Equilibrado: 40 minutos de enfoque y 10 de descanso**. Al terminar una fase envía una notificación y deja preparada —en pausa— la fase siguiente.

### Sistemas disponibles

| Nombre | Enfoque | Descanso corto | Descanso largo | Descanso largo cada… |
| --- | ---: | ---: | ---: | ---: |
| `balanced` — Equilibrado | 40 min | 10 min | 20 min | 4 sesiones |
| `classic` — Clásico | 25 min | 5 min | 15 min | 4 sesiones |
| `deep` — Enfoque profundo | 50 min | 10 min | 20 min | 4 sesiones |
| `ultradian` — Ultradiano | 90 min | 20 min | 30 min | 2 sesiones |

Elegir un sistema nuevo reinicia la fase en enfoque, la deja pausada y pone en cero el contador de sesiones.

### Controles

| Acción | Resultado |
| --- | --- |
| Clic izquierdo | Iniciar o pausar la cuenta regresiva. |
| Clic central | Saltar entre enfoque y descanso corto. |
| Clic derecho | Abrir en Walker el selector de sistemas. |
| Scroll arriba/abajo | Sumar/restar un minuto; el rango permitido es 1 minuto–4 horas. |

Los colores indican la fase mientras está corriendo: rojo para enfoque, verde para descanso corto y cian para descanso largo. Una fase pausada usa el color normal con menor opacidad.

### Uso desde terminal

```bash
POMO="$HOME/.config/waybar/scripts/pomodoro.sh"

"$POMO" toggle             # iniciar o pausar
"$POMO" reset              # reiniciar la fase actual y dejarla pausada
"$POMO" skip               # saltar a la fase siguiente
"$POMO" menu               # abrir selector Walker/Omarchy
"$POMO" preset balanced    # 40/10
"$POMO" preset classic     # 25/5
"$POMO" preset deep        # 50/10
"$POMO" preset ultradian   # 90/20
"$POMO" add                # sumar un minuto
"$POMO" subtract           # restar un minuto
```

El estado se guarda atómicamente y con bloqueo en `${XDG_STATE_HOME:-$HOME/.local/state}/waybar/pomodoro/state.json`. Se puede cambiar la ubicación con `POMODORO_STATE_DIR` y el preset inicial con `POMODORO_PRESET`; después del primer uso, el preset elegido queda persistido.

Dependencias: `bash`, `jq`, `flock`/util-linux, `notify-send`/libnotify y el selector `omarchy menu select` basado en Walker.

## Señales de actualización de Waybar

Los módulos que reaccionan inmediatamente a eventos usan señales de tiempo real:

| Señal | Módulo |
| ---: | --- |
| `RTMIN+7` | Actualizaciones de Omarchy |
| `RTMIN+8` | Grabación de pantalla |
| `RTMIN+9` | Idle |
| `RTMIN+10` | Silencio de notificaciones |
| `RTMIN+11` | Panel CTF |
| `RTMIN+12` | Pomodoro |
| `RTMIN+13` | Servicios y reverse shells |

Para refrescar manualmente un módulo, por ejemplo CTF:

```bash
pkill -RTMIN+11 waybar
```

## Validación y diagnóstico

Validar la configuración y los scripts antes de reiniciar:

```bash
cd "$HOME/dotfiles"
jq empty desktop/.config/waybar/config.jsonc
bash -n desktop/.config/waybar/scripts/ctf-ip.sh
bash -n desktop/.config/waybar/scripts/pomodoro.sh
bash -n desktop/.config/waybar/scripts/services-monitor.sh
stow --simulate --verbose=2 --target="$HOME" desktop terminal
```

Reiniciar la barra:

```bash
omarchy restart waybar
```

Si un módulo personalizado no aparece, ejecútalo manualmente y comprueba que produzca JSON válido:

```bash
~/.config/waybar/scripts/ctf-ip.sh print | jq
~/.config/waybar/scripts/pomodoro.sh print | jq
```

Si el selector del Pomodoro no abre, verifica Walker y su servicio:

```bash
systemctl --user status walker.service
omarchy-restart-walker
```

## Añadir nuevos dotfiles

Replica dentro de un paquete la ruta que tendría el archivo desde `$HOME`. Por ejemplo, para agregar `~/.config/mako/config` al paquete `desktop`:

```bash
mkdir -p "$HOME/dotfiles/desktop/.config/mako"
mv "$HOME/.config/mako/config" "$HOME/dotfiles/desktop/.config/mako/config"
cd "$HOME/dotfiles"
stow --restow --target="$HOME" desktop
```

Después revisa `git status` y confirma que no estés versionando secretos, tokens ni archivos de estado.
