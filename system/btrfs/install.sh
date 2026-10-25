#!/bin/bash
# Instala la parte de sistema (requiere root): sudo ./install.sh
set -eu
cd "$(dirname "$0")"

[ "$(findmnt -no FSTYPE /)" = btrfs ] || { echo "/ no es btrfs; nada que instalar" >&2; exit 1; }
uuid=$(findmnt -no UUID /)

install -Dm755 btrfs-balance-auto /usr/local/bin/btrfs-balance-auto
install -Dm644 btrfs-balance-auto.service /etc/systemd/system/btrfs-balance-auto.service
install -Dm644 btrfs-balance-auto.timer /etc/systemd/system/btrfs-balance-auto.timer

systemctl daemon-reload
systemctl enable --now btrfs-balance-auto.timer

# Reclamo automático de chunks de datos por el kernel; la ruta depende del UUID de cada equipo.
# Sólo los ajustes que este kernel tiene: escribir uno inexistente hace fallar tmpfiles.
for knob in dynamic_reclaim periodic_reclaim; do
    if [ -e "/sys/fs/btrfs/$uuid/allocation/data/$knob" ]; then
        echo "w /sys/fs/btrfs/$uuid/allocation/data/$knob - - - - 1"
    fi
done > /etc/tmpfiles.d/btrfs-reclaim.conf
systemd-tmpfiles --create /etc/tmpfiles.d/btrfs-reclaim.conf

# Límite fijo: un rango (p. ej. 2-5) exige cuotas btrfs y sin ellas `snapper cleanup`
# falla con "quota not working (qgroup not set)", abortando wh01s17-update
if [ -f /etc/snapper/configs/root ]; then
    snapper -c root set-config NUMBER_LIMIT=5 NUMBER_LIMIT_IMPORTANT=5
fi

echo "Listo. Primer balance ahora (puede tardar unos minutos):"
systemctl start btrfs-balance-auto.service
journalctl -u btrfs-balance-auto.service -n 20 --no-pager
