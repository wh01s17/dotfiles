#!/bin/bash
# Instala la parte de sistema (requiere root): sudo ./install.sh
set -eu
cd "$(dirname "$0")"

[ "$(findmnt -no FSTYPE /)" = btrfs ] || { echo "/ no es btrfs; nada que instalar" >&2; exit 1; }
uuid=$(findmnt -no UUID /)

install -Dm755 btrfs-balance-auto /usr/local/bin/btrfs-balance-auto
install -Dm644 btrfs-balance-auto.service /etc/systemd/system/btrfs-balance-auto.service
install -Dm644 btrfs-balance-auto.timer /etc/systemd/system/btrfs-balance-auto.timer

# Reclamo automático de chunks de datos por el kernel; la ruta depende del UUID de cada equipo
cat > /etc/tmpfiles.d/btrfs-reclaim.conf <<EOF
w /sys/fs/btrfs/$uuid/allocation/data/dynamic_reclaim - - - - 1
w /sys/fs/btrfs/$uuid/allocation/data/periodic_reclaim - - - - 1
EOF

# FREE_LIMIT solo actúa si NUMBER_LIMIT es un rango: borra hasta el mínimo cuando queda <20% libre
snapper -c root set-config NUMBER_LIMIT=2-5 NUMBER_LIMIT_IMPORTANT=2-5 FREE_LIMIT=0.2

systemctl daemon-reload
systemd-tmpfiles --create /etc/tmpfiles.d/btrfs-reclaim.conf
systemctl enable --now btrfs-balance-auto.timer

echo "Listo. Primer balance ahora (puede tardar unos minutos):"
systemctl start btrfs-balance-auto.service
journalctl -u btrfs-balance-auto.service -n 20 --no-pager
