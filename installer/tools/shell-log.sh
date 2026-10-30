#!/usr/bin/env bash
# Arranque del shell en bruto (sin el ruido repetido) y estado del tema.
#   tools/shell-log.sh [LÍNEAS]       (registro completo en ~/shell-log.txt)
set -uo pipefail

lines=${1:-40}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
log=$(find -L "$XDG_RUNTIME_DIR/quickshell/by-id" -mindepth 2 -maxdepth 2 -type f -name log.log -printf '%T@ %p\n' 2>/dev/null | sort -nr | cut -d' ' -f2- | head -1)
[[ -n $log ]] || { echo "No hay registro de Quickshell"; exit 1; }
cp "$log" "$HOME/shell-log.txt"

theme="$HOME/.local/state/wh01s17/current"
echo "== Tema: $(cat "$theme/theme.name" 2>/dev/null || echo 'SIN theme.name')"
echo "   $(find "$theme/theme" -mindepth 1 -maxdepth 1 -name '*.toml' -printf '1\n' 2>/dev/null | wc -l) archivos .toml en current/theme; shell.toml: $(test -s "$theme/theme/shell.toml" && echo sí || echo NO)"
echo "== Primeras $lines líneas del shell (sin repeticiones)"
grep -vE 'pluginBarApiFor|QQmlVMEMetaObject|Failed to open channel' "$log" |
  sed -E -e 's/^[0-9-]+ [0-9:.]+ +//' -e 's/0x[0-9a-f]+//g' -e 's#file://[^ ]*/(plugins|shell|Ui|Commons)/#\1/#g' -e 's#/home/[^/]+/#~/#g' |
  awk '!seen[$0]++' | head -n "$lines" | cut -c1-165
