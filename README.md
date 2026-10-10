# Dotfiles para Omarchy Quattro

Configuración personal para **Omarchy 4 (Quattro)**, **Hyprland 0.56+**, **Omarchy Shell/Quickshell**, **Kitty** y **Zsh**, administrada con [GNU Stow](https://www.gnu.org/software/stow/).

Stow trata cada directorio de primer nivel como un paquete y crea enlaces simbólicos dentro de `$HOME`. La fuente real continúa versionada en este repositorio.

## Índice

1. [Estructura](#estructura)
2. [Requisitos](#requisitos)
3. [Instalación desde cero](#instalación-desde-cero)
4. [Instalación en un sistema existente](#instalación-en-un-sistema-existente)
5. [Hyprland en Lua](#hyprland-en-lua)
   - [Perfiles por equipo](#perfiles-por-equipo)
   - [Entrada y atajos personales](#entrada-y-atajos-personales)
   - [Blur y transparencia](#blur-y-transparencia)
   - [Luz nocturna y pantalla compartida](#luz-nocturna-y-pantalla-compartida)
6. [Omarchy Shell](#omarchy-shell)
   - [Distribución](#distribución)
   - [Módulos propios y clones](#módulos-propios-y-clones)
   - [Metrónomo](#metrónomo)
   - [Git, firewall, unidades y actividad](#git-firewall-unidades-y-actividad)
   - [Idle, salvapantallas y bloqueo](#idle-salvapantallas-y-bloqueo)
   - [Reloj y calendario](#reloj-y-calendario)
   - [Componente de estado](#componente-de-estado)
7. [Panel CTF](#panel-ctf)
8. [Pomodoro](#pomodoro)
9. [Clima](#clima)
10. [Servicios y reverse shells](#servicios-y-reverse-shells)
11. [Accesos auxiliares de la barra](#accesos-auxiliares-de-la-barra)
12. [Tema `wh01s17`](#tema-wh01s17)
13. [Fastfetch](#fastfetch)
14. [Kitty](#kitty)
15. [Zsh y utilidades de terminal](#zsh-y-utilidades-de-terminal)
16. [Mantenimiento del disco](#mantenimiento-del-disco)
17. [Mapa de implementación](#mapa-de-implementación)
18. [Pruebas](#pruebas)
19. [Actualizar o retirar](#actualizar-o-retirar)

## Estructura

```text
dotfiles/
├── desktop/
│   └── .config/
│       ├── fastfetch/                  # Informe, wordmark ANSI y Gengar con los colores del tema
│       ├── hypr/                       # Configuración Lua de Hyprland
│       │   └── profiles/              # Monitores por equipo
│       └── omarchy/
│           ├── shell.json              # Barra, widgets e idle de Omarchy Shell
│           ├── bar/
│           │   ├── modules/            # Componente QML reutilizable
│           │   └── scripts/            # CTF, Pomodoro y servicios
│           ├── branding/               # Marca ASCII para el salvapantallas
│           ├── plugins/
│           │   ├── wh01s17.audio/      # Mezclador, entradas y salidas de audio
│           │   ├── wh01s17.bar/        # Barra con hover por monitor
│           │   ├── wh01s17.bluetooth/  # Dispositivos Bluetooth y salida de audio
│           │   ├── wh01s17.clock/      # Reloj y calendario propios
│           │   ├── wh01s17.indicators/ # Indicadores que respetan el hover por monitor
│           │   ├── wh01s17.metronome/  # Metrónomo con motor de audio local
│           │   ├── wh01s17.monitor/    # Escala independiente por monitor
│           │   ├── wh01s17.network/    # Wi-Fi, DNS, QR y diagnóstico de red
│           │   └── wh01s17.power/      # Batería, perfiles y estadísticas
│           └── themes/
│               └── wh01s17/            # Tema, wallpapers, maestros SVG y generador pixel art
├── terminal/
│   ├── .config/kitty/
│   │   ├── kitty.conf             # Base común y tema dinámico
│   │   └── profiles/              # Tamaño de fuente por equipo
│   ├── .config/oh-my-posh/
│   │   ├── active.omp.json        # Enlace al tema elegido
│   │   ├── pure.omp.json          # Tema Pure personalizado
│   │   └── theme-picker.zsh       # Selector interactivo de temas
│   └── .zshrc
├── maintenance/
│   ├── .config/systemd/user/      # Timers de usuario: aviso de espacio, Codex y mise
│   └── .local/bin/btrfs-space-check
├── system/btrfs/                  # Balance semanal y snapper; se instala con sudo, no con Stow
└── README.md
```

Los paquetes Stow son:

| Paquete | Destino | Contenido |
| --- | --- | --- |
| `desktop` | `~/.config/` | Fastfetch, Hyprland y Omarchy Shell |
| `terminal` | `$HOME` y `~/.config/` | Zsh, Oh My Posh y Kitty |
| `maintenance` | `~/.config/systemd/user/` y `~/.local/bin/` | Timers de limpieza y aviso de espacio en disco |

`system/` no es un paquete Stow: sus archivos van a `/etc` y `/usr/local` y se
copian con su propio instalador (ver [Mantenimiento del disco](#mantenimiento-del-disco)).

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

- Oh My Zsh, Oh My Posh y los plugins `zsh-syntax-highlighting`,
  `zsh-autosuggestions` y `zsh-sudo`;
- `fzf` para el selector interactivo de temas de Oh My Posh;
- `eza`, `bat`, `zoxide`, `xclip`, `host` y `whois` para los aliases y
  funciones de `~/.zshrc`;
- NVM y un Node predeterminado, porque la inicialización ejecuta
  `nvm use default`;
- MesloLGS Nerd Font Mono para Kitty y los glifos de la barra;
- Fastfetch para el informe visual del sistema.

En Omarchy, instala Oh My Posh desde AUR con `omarchy pkg aur add oh-my-posh-bin`.

Solaar y WayScriber son opcionales, pero sus entradas de autostart y atajos
sólo funcionarán cuando estén instalados. `subfinder`, `amass`, LM Studio,
OpenCode, John the Ripper y el entorno local de Perl también son opcionales y
sólo afectan las funciones o rutas de Zsh que los nombran.

Para regenerar los wallpapers SVG se necesita `rsvg-convert` (`librsvg`); los
wallpapers pixel art necesitan `python3` e ImageMagick (`magick`). ImageMagick
también recolorea el Gengar de Fastfetch con la paleta del tema activo; sin él
se muestra el PNG original. Para ejecutar `qmllint` durante el desarrollo se
necesita Qt Declarative.

El metrónomo necesita `python3` y un reproductor PCM: usa `pw-cat` cuando
está disponible y `aplay` como alternativa. El módulo de unidades montadas
usa `udisksctl` para expulsar dispositivos; el acceso rápido de actividad abre
`btop`. Los indicadores de firewall muestran `ufw`, `nftables` o `iptables`
cuando alguno está configurado, pero no instalan ni modifican reglas.

Waybar, Walker, Mako, hypridle e hyprlock no son necesarios: Quattro reemplaza esos componentes con Omarchy Shell/Quickshell.

## Instalación desde cero

Estos pasos parten de un equipo recién instalado con Omarchy Quattro, sin
configuración previa. Ejecútalos en orden desde la terminal de la sesión
gráfica (`Super+Enter`).

### 1. Actualizar el sistema

```bash
omarchy update
```

Reinicia si la actualización lo solicita.

### 2. Instalar dependencias

```bash
sudo pacman -S --needed \
  git stow curl jq iproute2 wl-clipboard libnotify util-linux xdg-utils \
  zsh fzf eza bat zoxide xclip bind whois nvm ttf-meslo-nerd \
  fastfetch imagemagick python btop udisks2
omarchy pkg aur add oh-my-posh-bin
```

Las herramientas opcionales (Solaar, WayScriber, `subfinder`, `amass`, etc.)
se describen en [Requisitos](#requisitos) y pueden instalarse más adelante.

### 3. Usar Kitty como terminal

```bash
omarchy install terminal kitty
```

El comando instala Kitty y lo deja como terminal predeterminada de Omarchy.

### 4. Clonar el repositorio

```bash
git clone https://github.com/wh01s17/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
```

### 5. Elegir el perfil del equipo

Si el equipo es uno de los perfiles versionados, créale sus selectores locales
(ver [Perfiles por equipo](#perfiles-por-equipo)):

```bash
printf 'return "hp-gray"\n' > desktop/.config/hypr/machine-profile.lua
printf 'include profiles/hp-gray.conf\n' > terminal/.config/kitty/machine-profile.conf
```

En otro equipo, omite este paso: Hyprland usará la resolución preferida de
cada monitor y Kitty sus valores predeterminados.

### 6. Respaldar la configuración predeterminada

Una instalación limpia ya trae archivos reales que Stow no reemplaza, como
`~/.config/hypr/`, `~/.config/kitty/kitty.conf` y
`~/.config/omarchy/shell.json`. El directorio de Hyprland se aparta completo
para que Stow lo enlace entero; el resto de los conflictos se renombra con el
sufijo `.before-dotfiles`:

```bash
cd "$HOME/dotfiles"
[ -d "$HOME/.config/hypr" ] && [ ! -L "$HOME/.config/hypr" ] &&
  mv -n "$HOME/.config/hypr" "$HOME/.config/hypr.before-dotfiles"

stow --simulate --target="$HOME" desktop terminal maintenance 2>&1 \
  | sed -nE 's/^  \* cannot stow .* over existing target (.+) since neither a link nor a directory.*/\1/p' \
  | while IFS= read -r conflict; do
      mv -n -- "$HOME/$conflict" "$HOME/$conflict.before-dotfiles"
    done

stow --simulate --target="$HOME" desktop terminal maintenance
```

La última simulación debe terminar sin el aviso `would cause conflicts`.
`mv -n` nunca sobrescribe una copia `.before-dotfiles` existente. La variable
se llama `conflict` y no `path` porque en Zsh `path` está ligada a `PATH`.

### 7. Crear los enlaces

```bash
stow --target="$HOME" desktop terminal maintenance
```

### 8. Configurar Zsh

Cambia la shell de inicio e instala Oh My Zsh conservando el `.zshrc` ya
enlazado:

```bash
chsh -s /usr/bin/zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
  "" --unattended --keep-zshrc
```

Instala los plugins que carga `.zshrc`. `zsh-sudo` reutiliza el plugin `sudo`
de Oh My Zsh con el nombre que espera la configuración:

```bash
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
git clone https://github.com/zsh-users/zsh-autosuggestions.git \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
mkdir -p "$ZSH_CUSTOM/plugins/zsh-sudo"
ln -s "$HOME/.oh-my-zsh/plugins/sudo/sudo.plugin.zsh" \
  "$ZSH_CUSTOM/plugins/zsh-sudo/zsh-sudo.plugin.zsh"
```

### 9. Instalar Node con NVM

`.zshrc` usa `~/.config/nvm` y ejecuta `nvm use default` al iniciar, por lo
que necesita un Node predeterminado:

```bash
export NVM_DIR="$HOME/.config/nvm"
source /usr/share/nvm/init-nvm.sh
nvm install --lts
nvm alias default 'lts/*'
```

### 10. Instalar el plugin de bloqueo

`shell.json` reemplaza el lock nativo por Lock Explorer. Clónalo sin volver a
habilitarlo, porque `shell.json` ya lo declara:

```bash
omarchy plugin add https://github.com/SirJul1337/omarchy-lock-explorer.git --yes
```

### 11. Aplicar el tema y recargar

```bash
omarchy theme set wh01s17
hyprctl reload
hyprctl configerrors
omarchy restart shell
```

Cierra la sesión y vuelve a entrar para que Zsh pase a ser la shell de inicio.
En la nueva terminal, `fastfetch` debe mostrar el Gengar con los colores del
tema y el prompt de Oh My Posh.

### 12. Revisar y ajustar

- Comprueba los enlaces con los `readlink` del
  [paso 3 de la instalación en un sistema existente](#3-crear-los-enlaces) y
  ejecuta las [pruebas](#pruebas).
- Compara cada `.before-dotfiles` con su reemplazo y elimina las copias que
  ya no necesites.
- Revisa en `.zshrc` el alias `john` y las rutas de `PATH` propias de este
  usuario (ver [Zsh y utilidades de terminal](#zsh-y-utilidades-de-terminal)).
- Activa los timers de mantenimiento y, si `/` es btrfs, instala la parte de
  sistema (ver [Mantenimiento del disco](#mantenimiento-del-disco)).
- Guarda las credenciales opcionales, como la de `ipinfo`, en
  `~/.config/zsh/secrets.zsh`; `.zshrc` lo carga si existe y no se versiona.

## Instalación en un sistema existente

Usa estos pasos si el equipo ya tiene Zsh, Oh My Zsh y las demás dependencias
de [Requisitos](#requisitos), por ejemplo para reinstalar los enlaces o
sincronizar otro equipo ya configurado.

### 1. Clonar

```bash
git clone https://github.com/wh01s17/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
```

### 2. Simular y resolver conflictos

```bash
stow --simulate --verbose=2 --target="$HOME" desktop terminal maintenance
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
stow --restow --target="$HOME" desktop terminal maintenance
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
readlink -f "$HOME/.config/oh-my-posh/pure.omp.json"
readlink -f "$HOME/.config/oh-my-posh/active.omp.json"
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
| [`monitors.lua`](desktop/.config/hypr/monitors.lua) | Escala gestionada por Quattro y carga del perfil local de monitores |
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

El panel **Display** usa el clon local `wh01s17.monitor`. La acción de escala
delega en el comando original de Quattro, que registra la salida enfocada y su
nueva escala en `~/.local/state/omarchy/monitor-scaling.log`, y después recarga
Hyprland. [`monitor_scales.lua`](desktop/.config/hypr/monitor_scales.lua) toma
el último valor de cada conector y los perfiles lo aplican individualmente. De
este modo `DP-1` puede permanecer a 2× mientras `eDP-1` y `HDMI-A-1` siguen a
1×. En `hp-gray`, donde HDMI refleja la pantalla interna, ambas salidas usan
la escala guardada para `eDP-1`; así la recarga no devuelve el proyector a 1×.
El perfil `omen` también recalcula las posiciones lógicas usando la escala del
monitor que determina cada desplazamiento.

`GDK_SCALE` se mantiene en 1 para los perfiles mixtos porque es una variable
global; el escalado por salida queda a cargo de Hyprland. Los valores dinámicos
viven en el estado local de Omarchy y no ensucian el repositorio al usar el
panel.

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
| `Super+Ctrl+Shift+←` / `→` | Estrechar / ensanchar la ventana enfocada; admite repetición |
| `Super+Ctrl+Shift+↑` / `↓` | Bajar / subir la altura de la ventana enfocada; admite repetición |

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
| Izquierda | Menú Omarchy, escritorios, rama del repositorio activo y panel CTF |
| Centro | Indicadores, reloj con segundos, distribución de teclado, clima, Pomodoro y actualizaciones |
| Derecha | Bandeja, metrónomo, firewall, unidades montadas, portapapeles, agentes, servicios, Bluetooth, red, audio, monitores, CPU y energía |

El reloj `wh01s17.clock` es un clon persistente del widget oficial. Conserva
su calendario y controles, pero usa precisión de segundos para que el formato
`HH:mm:ss` se actualice continuamente en lugar de mostrar siempre `00`.

Los indicadores nativos agrupan dictado, grabación, recordatorios, luz nocturna, silencio de notificaciones y bloqueo de idle.

### Módulos propios y clones

Los clones conservan la integración de Omarchy con sus paneles originales,
pero permiten añadir comportamiento sin editar los archivos de la
distribución. Todos se declaran en `shell.json` y sus metadatos viven en el
`manifest.json` de cada directorio.

| Módulo | Base o función | Adición destacada |
| --- | --- | --- |
| `wh01s17.clock` | `omarchy.clock` | Segundos, semana ISO y progreso anual/vital persistente |
| `wh01s17.audio` | `omarchy.audio` | Salidas, entradas y mezclador por aplicación navegables |
| `wh01s17.bluetooth` | `omarchy.bluetooth` | Conexión, olvido de dispositivos, reescaneo manual (botón o `r`) y selección de salida Bluetooth |
| `wh01s17.network` | `omarchy.network` | Wi-Fi, reescaneo manual de redes, DNS, bandas, QR, prueba de velocidad y métricas de enlace |
| `wh01s17.monitor` | `omarchy.monitor` | Escala persistente por salida y tooltip con resolución/escala |
| `wh01s17.power` | `omarchy.power` | Batería, perfiles de energía y estadísticas del sistema |
| `wh01s17.metronome` | Propio | Click track con dial de tempo, tap tempo, subdivisiones y acento |
| `wh01s17.bar` | `omarchy.bar` | Estado de hover por monitor: revelar los indicadores en una pantalla no redistribuye las barras de las demás |
| `wh01s17.indicators` | `omarchy.indicators` | Lee ese estado por monitor desde `wh01s17.bar` y carga sus propios indicadores desde `indicators/` |

`wh01s17.bar` reemplaza la barra completa (`bar.id` en `shell.json`), así que
no recibe las mejoras posteriores de `Bar.qml` en Omarchy. Al actualizar
Omarchy, compara con `diff -u /usr/share/omarchy/shell/plugins/bar/Bar.qml
desktop/.config/omarchy/plugins/wh01s17.bar/Bar.qml`.

### Metrónomo

[`wh01s17.metronome`](desktop/.config/omarchy/plugins/wh01s17.metronome/) usa
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
hook [`git-branch-hook.zsh`](desktop/.config/omarchy/bar/scripts/git-branch-hook.zsh)
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
`${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/bar/`; se puede redirigir cada
uno con `GIT_BRANCH_STATE_DIR`, `MOUNTS_STATE_DIR` o `SYSTEM_USAGE_STATE_DIR`.

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

El lock nativo `omarchy.lock` está deshabilitado y lo reemplaza
`io.github.sirjul1337.lock-explorer` con diseño `neon`. La entrada
`cloneSourceRestores` en `shell.json` hace que Omarchy restaure su fuente
clonada al reconstruir los plugins; no se versiona una copia del plugin de
terceros en este repositorio.

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
configuración de confianza y se ejecutan mediante `bash -c`.

Se usa `bash -c` y no `bash -lc` a propósito: un shell de login sourcea
`/etc/profile` y `~/.profile` en cada invocación, lo que costaba unos 7 ms por
llamada sin aportar nada, ya que el `PATH` que hereda Quickshell ya resuelve
todos los comandos que la barra necesita.

Omarchy instancia la barra completa una vez por monitor, así que cada
`interval` se multiplica por el número de pantallas. Conviene elegir el
intervalo más alto que el módulo tolere, y que los scripts con estado
compartido serialicen sus escrituras (ver `system-usage.sh`).

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

El panel también muestra junto a cada valor la orden de configuración rápida:
`target <ip>` para la víctima, `CTF_VPN_IFACES=tun0` para el túnel y
`CTF_LAN_IFACES=wlan0` para la interfaz local.

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
- CPU: clic en `󰍛` abre btop y clic derecho abre Alacritty. Como la barra
  corre una copia por monitor, [`system-usage.sh`](desktop/.config/omarchy/bar/scripts/system-usage.sh)
  toma un `flock` y comparte el resultado en
  `${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/bar/system-usage`: la primera
  copia calcula el delta de CPU y disco, y las demás reutilizan esa respuesta
  durante `SYSTEM_USAGE_MIN_REFRESH_US` (1,5 s por omisión). Sin eso las copias
  se pisaban el archivo de muestras y dos de cada tres informaban 0 %.
- Agentes y actualizaciones siguen siendo widgets nativos. Red, audio,
  monitores, Bluetooth y energía usan los clones `wh01s17.*` descritos arriba;
  mantienen los paneles y acciones de Omarchy y añaden los controles propios.

## Tema `wh01s17`

[`themes/wh01s17`](desktop/.config/omarchy/themes/wh01s17/) implementa una
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
| [`colors.toml`](desktop/.config/omarchy/themes/wh01s17/colors.toml) | Paleta usada para generar configuraciones de aplicaciones |
| [`hyprland.lua`](desktop/.config/omarchy/themes/wh01s17/hyprland.lua) | Bordes verde/cian, radio de 6 px y sombras del tema |
| [`icons.theme`](desktop/.config/omarchy/themes/wh01s17/icons.theme) | Selecciona `Yaru-prussiangreen-dark` |
| [`shell.*.toml`](desktop/.config/omarchy/themes/wh01s17/) | Barra, controles, tipografía, menús, lock, notificaciones, popups, polkit, espaciado y tooltips |
| [`backgrounds/`](desktop/.config/omarchy/themes/wh01s17/backgrounds/) | Cinco wallpapers PNG 4K listos para usar |
| [`sources/`](desktop/.config/omarchy/themes/wh01s17/sources/) | Maestros SVG y generador de los wallpapers pixel art |
| [`brand/logo.svg`](desktop/.config/omarchy/themes/wh01s17/brand/logo.svg) | Geometría oficial de la marca |

El tema se carga con los valores predeterminados y después se aplican las
preferencias personales de `~/.config/hypr`. Por eso el radio de 3 px de
`looknfeel.lua` prevalece sobre los 6 px propuestos por el tema, mientras sus
colores de borde y sombras se conservan. Tras editar un archivo del tema,
vuelve a aplicarlo con `omarchy theme set wh01s17`.

[`themes/wh01s17/README.md`](desktop/.config/omarchy/themes/wh01s17/README.md)
documenta la paleta y
[`DESIGN.md`](desktop/.config/omarchy/themes/wh01s17/DESIGN.md) las reglas de
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

## Fastfetch

[`config.jsonc`](desktop/.config/fastfetch/config.jsonc) presenta tres bloques:

- hardware: equipo, CPU, GPU, pantallas, discos, RAM y swap;
- software: versión, rama y canal de Omarchy, kernel, escritorio, terminal,
  paquetes, tema y fuente;
- estado: antigüedad de la instalación, uptime y última actualización.

El logo [`gengar.png`](desktop/.config/fastfetch/gengar.png) se dibuja mediante
el protocolo gráfico directo de Kitty, a 40×20 celdas con proporción
conservada. El lanzador lo recolorea con la paleta del tema activo de Omarchy:
el sombreado toma `accent`, el cuerpo una mezcla oscura de `accent` (30 %) y
`background` (70 %), los ojos `red` y los dientes `bright_foreground` (o
`foreground`). Primero ajusta el PNG a sus cuatro colores de sprite y a una
transparencia binaria, para que los bordes suavizados no dejen restos del color
original. Cada paleta se genera una sola vez en
`${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch/`, así que cambiar de tema sólo
cuesta una ejecución de ImageMagick. Si falta `magick`, el tema no define
`accent` o se llama a `fastfetch` con opciones, se usa el PNG original. La imagen no contiene el wordmark: el lanzador
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
- tabs con separadores Powerline, títulos truncados y colores de la paleta del
  tema (`color2` para la activa, `color8`/`color7` para las inactivas);
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

[`terminal/.zshrc`](terminal/.zshrc) inicializa Oh My Zsh, Oh My Posh,
Zoxide y NVM; carga los plugins `git`, `zsh-syntax-highlighting`,
`zsh-autosuggestions` y `zsh-sudo`; define `nvim` como editor y agrega rutas
locales de Perl, Ruby, LM Studio, OpenCode y John the Ripper.

[`terminal/.config/oh-my-posh/pure.omp.json`](terminal/.config/oh-my-posh/pure.omp.json)
guarda una copia local del tema Pure. Usa los colores ANSI de Kitty, cuya paleta
cambia con el tema activo de Omarchy. Muestra la ruta y el estado Git en la
primera línea, y el símbolo de entrada en la segunda. El lado derecho muestra
la hora y, cuando corresponde, fallos de tuberías o señales, comandos de más
de tres segundos, trabajos en segundo plano, entornos de Python, versiones de
lenguajes en proyectos,
Terraform, Nix y tareas pendientes. Se oculta si no cabe junto al lado
izquierdo. El prompt anterior se reduce a `❯` después de ejecutar un comando.
Los colores siguen la paleta activa de Omarchy; no se recupera la paleta del
tema anterior.

Los indicadores de nube y otras herramientas especializadas del tema anterior
no tienen aquí un equivalente con la misma activación por comando.

`omp-theme` abre un selector con búsqueda y vista previa dentro de la terminal.
Obtiene la lista de temas del repositorio oficial de Oh My Posh y descarga el
tema elegido una sola vez a `terminal/.config/oh-my-posh/themes/`. La copia
oficial queda intacta. `functional-overlay.json` define las funciones comunes
y `compose-theme.py` combina esas reglas con el tema seleccionado, respetando
sus colores, iconos, separadores y bloques. En el modo original, cuando el tema
ya tiene un bloque derecho, la configuración activa usa `extends` para guardar
sólo los cambios.
Si falta ese bloque, el compositor genera la configuración efectiva a partir
del tema original y añade un bloque derecho de estilo sencillo. Sólo se
conserva la configuración efectiva del tema activo. `active.omp.json` es un
enlace que se cambia de forma atómica y cuyo destino contiene el nombre del
tema; `--current` lee ese enlace. La vista previa de `fzf` usa la composición
final, igual que la terminal nueva. El panel se abre debajo de la lista y
muestra el tema oficial a la izquierda y el mismo tema con el acento y los
colores de Omarchy a la derecha. Al elegir un tema oficial con `Enter`, se abre
un cuadro para escoger entre colores originales y colores de Omarchy con las
flechas y confirmar con `Enter`. `Esc` cancela sin cambiar el tema. `pure-local`
se aplica directamente porque ya usa los colores de Omarchy.

La capa común añade transient prompt `❯`,
ruta acortada a unos 80 caracteres e indicador de solo lectura, Git con
upstream, ahead/behind, stash, estados de archivos y operaciones activas,
estado de salida y señal, duración desde 3 segundos, trabajos en segundo
plano, direnv, entornos y versiones de lenguajes, Terraform, Nix y hora. Las
herramientas aparecen sólo en su contexto; Taskwarrior se incluye sólo si
`task` está instalado. Se usa renderizado en streaming cuando es compatible
con la disposición del tema. En temas de dos líneas, todo bloque derecho se
dibuja junto a la línea contextual, encima de la línea donde se escriben los
comandos; se desactiva streaming para que Oh My Posh lo renderice allí. Los
temas de una línea conservan su disposición original. Las versiones de los
runtimes tienen una caché de un minuto para reducir el coste del prompt derecho
sin retrasar la detección del proyecto. Los bloques derechos se ocultan cuando
no caben junto al contexto. Algunos segmentos ya presentes
pueden presentar estos datos con su propio formato. Oh My Posh no expone un
indicador de `git bisect` equivalente al anterior, y ciertos temas sin un
segmento apropiado requieren el bloque derecho sencillo.
Los hooks `preexec` y `precmd` de `.zshrc` separan el prompt después de cada
comando ejecutado, sin agregar espacio al abrir la terminal ni cambiar el
diseño de los temas.

`pure-local` conserva su diseño y los colores ANSI que siguen la paleta activa
de Kitty/Omarchy. Los temas oficiales conservan sus colores propios, incluidos
los hexadecimales en el modo normal. `omp-theme --omarchy NOMBRE` activa un
tema oficial con la paleta ANSI de Omarchy, y `omp-theme --omarchy` abre el
selector en ese modo. La variante de color se genera a partir del tema local
sin alterar su copia original. `omp-theme --mode` muestra `original` u `omarchy`;
`--current` sigue mostrando el nombre del tema base. Los colores ANSI siguen
los cambios posteriores de Omarchy. Los gradientes de Oh My Posh requieren
colores hexadecimales y toman una instantánea de la paleta al seleccionar el
tema. Ni el inicio normal de Zsh ni la lectura del tema activo
requieren Internet. El catálogo de temas se guarda en `catalog.names` durante
siete días y se puede actualizar manualmente con `omp-theme --refresh`;
si la red falla, `--list` muestra la última lista descargada y los temas
locales. Un tema elegido se descarga sólo si aún no está en caché. También
puedes usar `omp-theme --list`, `omp-theme --current`, `omp-theme NOMBRE` y
`omp-theme pure-local`. El selector activa la recarga del prompt; si la sesión
actual no cambia, ejecuta `exec zsh`.

Para sumar otra función a todos los temas, edita `functional-overlay.json`:
agrega una regla de segmento a `missing_segments` o ajusta las reglas de ruta,
Git y estado. Vuelve a seleccionar el tema para regenerar `active.omp.json`;
añade `--omarchy` si ese es el modo activo. Si la composición falla, ejecuta
`ln -sfn pure.omp.json "$HOME/.config/oh-my-posh/active.omp.json"` y después
`exec zsh`; el tema Pure local seguirá funcionando sin el selector.

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

Los umbrales del aviso se cambian con `WARN_FREE_GIB` y `WARN_UNALLOC_GIB`.

Stow sólo crea los enlaces; los timers se activan aparte:

```bash
systemctl --user daemon-reload
systemctl --user enable --now \
  btrfs-space-check.timer codex-staging-clean.timer mise-prune.timer
```

Tareas de sistema (`system/btrfs/`, requiere que `/` sea btrfs):

| Componente | Acción |
| --- | --- |
| `btrfs-balance-auto.timer` | Balance semanal sólo de datos (`-dusage` 0, 10, 25 y 50), con prioridad baja y únicamente conectado a la corriente |
| `/etc/tmpfiles.d/btrfs-reclaim.conf` | Activa `dynamic_reclaim` y `periodic_reclaim` del kernel en cada arranque; el instalador lo genera con el UUID de `/` |
| Snapper (`root`) | `NUMBER_LIMIT=2-5` y `FREE_LIMIT=0.2`: conserva cinco snapshots y baja a dos cuando queda menos del 20 % libre |

```bash
sudo "$HOME/dotfiles/system/btrfs/install.sh"
```

El instalador copia los archivos, por lo que hay que volver a ejecutarlo
después de editarlos. Termina lanzando un primer balance y mostrando su
registro.

`FREE_LIMIT` sólo actúa porque `NUMBER_LIMIT` es un rango. `SPACE_LIMIT` no se
usa porque requiere cuotas de btrfs. El balance omite los metadatos a propósito:
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
| [`.gitignore`](.gitignore) | Ignora backups de Omarchy, bytecode/cachés de Python y los dos selectores locales de equipo |
| [`monitor_scales.lua`](desktop/.config/hypr/monitor_scales.lua) | Recupera la última escala registrada por cada salida |
| `hypr/profiles/*.lua` | Reglas versionadas de monitores para `hp-gray` y `omen` |
| `kitty/profiles/*.conf` | Tamaños de fuente versionados para los mismos perfiles |
| [`fastfetch/wh01s17.sh`](desktop/.config/fastfetch/wh01s17.sh) | Wordmark textual 8-bit, Gengar con los colores del tema y delegación al binario real de Fastfetch |
| [`ctf-aliases.zsh`](desktop/.config/omarchy/bar/scripts/ctf-aliases.zsh) | Puente entre `.zshrc` y `ctf-ip.sh` |
| [`manifest.json`](desktop/.config/omarchy/plugins/wh01s17.clock/manifest.json) | Declara el reloj como plugin de barra clonado de `omarchy.clock` |
| `wh01s17.{audio,bluetooth,network,power}/` | Clones de los paneles oficiales con sus modelos y controles ampliados |
| [`wh01s17.metronome/`](desktop/.config/omarchy/plugins/wh01s17.metronome/) | Widget, núcleo compartido, dial, modelo y motor PCM del metrónomo |
| `bar/scripts/{firewall-status,git-branch,mounted-devices,system-usage}.sh` | Indicadores de seguridad, repositorio, medios extraíbles y actividad |
| `wh01s17.monitor/Panel.qml` | Clon de `omarchy.monitor` que recarga el perfil tras cambiar una escala |
| `wh01s17.clock/BarWidget.qml` | Etiqueta, precisión por segundo, clics e IPC del reloj |
| `wh01s17.clock/Model.js` | Fechas, semanas ISO, formatos y progreso anual/vital |
| `wh01s17.clock/Panel.qml` | Calendario, navegación y controles persistentes |
| `themes/wh01s17/shell.*.toml` | Fragmentos visuales que Omarchy combina al aplicar el tema |
| `themes/wh01s17/backgrounds/*.png` | Salidas 4K; `01`–`02` se regeneran desde `sources/*.svg` y `03`–`05` con `sources/pixel-art.py` |

## Pruebas

Validación estática:

```bash
stow --simulate --verbose=2 --target="$HOME" desktop terminal maintenance
luac -p "$HOME/.config/hypr/monitor_scales.lua" \
  "$HOME/.config/hypr/monitors.lua" \
  "$HOME/.config/hypr/profiles/"*.lua
Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua"
jq empty "$HOME/.config/omarchy/shell.json"
jq empty "$HOME/.config/omarchy/plugins/wh01s17.monitor/manifest.json"
jq empty "$HOME/.config/omarchy/plugins/wh01s17.metronome/manifest.json"
jq empty "$HOME/.config/fastfetch/config.jsonc"
qmllint -I /usr/share/omarchy/shell \
  "$HOME/.config/omarchy/bar/modules/StatusModule.qml" \
  "$HOME/.config/omarchy/plugins/wh01s17.clock/Panel.qml" \
  "$HOME/.config/omarchy/plugins/wh01s17.monitor/Panel.qml" \
  "$HOME/.config/omarchy/plugins/wh01s17.metronome/BarWidget.qml" \
  "$HOME/.config/omarchy/plugins/wh01s17.metronome/MetronomeCore.qml"
for model in \
  "$HOME/.config/omarchy/plugins/wh01s17.clock/Model.js" \
  "$HOME/.config/omarchy/plugins/wh01s17.monitor/Model.js" \
  "$HOME/.config/omarchy/plugins/wh01s17.metronome/Model.js"; do
  if head -n 1 "$model" | grep -qx '\.pragma library'; then
    tail -n +2 "$model" | node --check
  else
    node --check "$model"
  fi
done
python3 -m py_compile \
  "$HOME/.config/omarchy/plugins/wh01s17.metronome/metronome-engine.py" \
  "$HOME/.config/omarchy/themes/wh01s17/sources/pixel-art.py"
bash -n "$HOME/.config/fastfetch/wh01s17.sh"
for script in "$HOME/.config/omarchy/bar/scripts/"*.sh; do
  bash -n "$script"
done
zsh -n "$HOME/.zshrc"
zsh -n "$HOME/.config/omarchy/bar/scripts/ctf-aliases.zsh"
bash -n "$HOME/.local/bin/btrfs-space-check"
bash -n "$HOME/dotfiles/system/btrfs/install.sh"
bash -n "$HOME/dotfiles/system/btrfs/btrfs-balance-auto"
systemd-analyze verify --user \
  "$HOME/.config/systemd/user/"{btrfs-space-check,codex-staging-clean,mise-prune}.{service,timer}
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
stow --restow --target="$HOME" desktop terminal maintenance
omarchy restart shell
omarchy restart terminal
```

Para retirar únicamente los enlaces:

```bash
cd "$HOME/dotfiles"
stow --delete --target="$HOME" desktop terminal maintenance
```

Antes de retirar `maintenance`, desactiva sus timers con
`systemctl --user disable --now btrfs-space-check.timer codex-staging-clean.timer mise-prune.timer`.
La parte de sistema se retira con
`sudo systemctl disable --now btrfs-balance-auto.timer` y borrando los
archivos que copió `install.sh`.

`stow --delete` retira sólo los enlaces que administra; no elimina el
repositorio, los selectores locales, el estado de CTF/Pomodoro ni las copias
`.before-dotfiles` creadas al instalar.
