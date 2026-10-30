# Instalador del escritorio wh01s17

Parte del repositorio [dotfiles](../README.md). Instala sobre Arch Linux los
paquetes, el escritorio, la configuración de hardware y los servicios.

```bash
cd ~/dotfiles
./installer/install.sh --dry-run
./installer/install.sh
```

- [Instalación del sistema base y escritorio](INSTALL.md)
- [Actualización](UPDATE.md)
- [Atajos](KEYBINDINGS.md)
- [Procedencia de la importación](ORIGIN.md)

`install.sh` toma el checkout que lo contiene como fuente. No clona ni
actualiza otro repositorio. `--only "stow services validate"` reaplica los
enlaces y servicios sin repetir la instalación del sistema.

Los cinco paquetes Stow se enlazan desde la raíz del repo. `apps` usa
`--no-folding` para preservar los directorios en los que escriben las apps.
Los perfiles locales del equipo no se versionan.

`tools/import-plugin.py` adapta plugins externos al importarlos.
Los paquetes propios se enlazan directamente, sin transformaciones.
El runtime está versionado en `platform`; los parches revisados y sus pruebas
se mantienen en `patches` y `tests`.

```bash
./test.sh  # desde la raíz del repo
```
