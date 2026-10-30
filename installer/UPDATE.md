# Actualizar el escritorio wh01s17

El código y el instalador viven juntos en `~/dotfiles`:

```bash
cd ~/dotfiles
git pull --ff-only
```

Con `dotfiles-sync.timer` activo se actualizan los enlaces automáticamente.
Para forzar la aplicación y verificar:

```bash
dotfiles-sync --force
./test.sh
```

Los cambios de paquetes o configuración del sistema requieren ejecutar las
etapas correspondientes de `installer/install.sh`; el sincronizador sólo
aplica enlaces de usuario. Revisa `./installer/install.sh --help`.

## Equipos instalados con el esquema de disco anterior

Las instalaciones hechas antes de que `INSTALL.md` creara los subvolúmenes `@`
tienen la raíz en el nivel superior del btrfs: los snapshots incluyen `/home`
y «Restaurar» de Limine no funciona. `install.sh` y `tools/check-system.sh`
lo avisan. El equipo sigue funcionando y puede arrancar un snapshot; para
corregir el esquema hay que reinstalar siguiendo `INSTALL.md` §2.

No cambies `RESTORE_METHOD` a `rsync` en ese esquema: `/home` no es un
subvolumen aparte, y restaurar podría devolverlo al estado del snapshot.

Mientras tanto, limita la caché de pacman, que también queda en los snapshots:

```bash
sudo systemctl enable --now paccache.timer
```

## Equipos con `@` pero sin `@containerd`

Docker 29 guarda las capas de las imágenes en `/var/lib/containerd`, no en
`/var/lib/docker`. Si ese directorio no tiene su propio subvolumen, queda
dentro de `@`: los snapshots lo incluyen y `docker image prune` no libera
espacio. `tools/check-system.sh` lo avisa. Para moverlo a `@containerd`:

```bash
sudo systemctl stop docker.socket docker.service containerd.service
top=$(mktemp -d)
sudo mount -o subvol=/ "$(findmnt -no SOURCE / | sed 's/\[.*//')" "$top"
sudo btrfs subvolume create "$top/@containerd"
sudo cp -a --reflink=always /var/lib/containerd/. "$top/@containerd/"
sudo umount "$top"
sudo rm -rf /var/lib/containerd && sudo mkdir /var/lib/containerd
grep -E '[[:space:]]/var/lib/docker[[:space:]]' /etc/fstab |
  sed 's#/var/lib/docker#/var/lib/containerd#; s#@docker#@containerd#' |
  sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount /var/lib/containerd
sudo systemctl start docker.socket docker.service
```

El espacio de las capas antiguas vuelve cuando snapper borra los snapshots que
las contienen (conserva cinco).
