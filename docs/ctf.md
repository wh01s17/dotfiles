# Panel CTF

[`ctf-ip.sh`](../desktop/.config/omarchy/bar/scripts/ctf-ip.sh) muestra:

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
