# Actualizar el escritorio wh01s17

Ejecuta:

```bash
~/dotfiles/update.sh
```

El actualizador pausa el timer, hace `git pull --ff-only`, aplica los enlaces,
ejecuta las comprobaciones y activa `dotfiles-sync.timer`. Si todavía existe
`.arch-build`, redirige sus enlaces a los originales y la elimina al terminar
correctamente. Los perfiles locales y los archivos ajenos se conservan.

Para obtener el script por primera vez en un equipo con la configuración anterior:

```bash
git -C ~/dotfiles pull --ff-only && ~/dotfiles/update.sh --local
```

Si el `git pull` trae cambios del shell y hay una sesión de Hyprland, reinicia
el shell para cargarlos (Quickshell no recarga solo el QML, y el servicio de
bloqueo no se cambia en caliente). También retira `lock-explorer`, el plugin de
terceros que reemplazó `wh01s17.lock`, borrando sólo sus propias rutas.

`--local` aplica el checkout actual sin descargar cambios. Si falla el pull,
se detiene sin descartar ni guardar automáticamente los cambios locales.
El sincronizador regenera el tema activo y recarga Hyprland cuando cambian
sus fuentes. Para cambios de sesión que requieran reinicio, cierra sesión y
vuelve a entrar.

Los cambios de paquetes o configuración del sistema requieren ejecutar las
etapas correspondientes de `installer/install.sh`; el sincronizador sólo
aplica enlaces de usuario. Revisa `./installer/install.sh --help`.

## Limine no arranca solo

En equipos instalados antes de que la entrada del primer arranque se llamara
`/Primer arranque`, `limine-entry-tool` guardó los kernels dentro de
`/Arch Linux`, que quedó como un directorio con campos de arranque propios.
Limine no puede arrancar un directorio, así que al terminar el `timeout` el
menú se queda esperando. Para corregirlo (deja una copia
`limine.conf.bak-autoboot`):

```bash
sudo bash ~/dotfiles/installer/patches/limine-autoboot.sh
```

La etapa `system` del instalador lo aplica sola.

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
