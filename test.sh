#!/usr/bin/env bash
# Static checks for this repository: ./test.sh
#
# With CI set, a missing tool for a portable check is a failure. Checks that
# need the live session (Hyprland, Omarchy's QML modules, the user's systemd
# units) run only outside CI and only when their tool is installed.
# shellcheck disable=SC2329 # check_* functions are called through run
set -uo pipefail
cd "$(dirname "$0")" || exit

failed=0
log=$(mktemp)
trap 'rm -f "$log"' EXIT

run() { # run NAME COMMAND...
  local name=$1
  shift
  if "$@" >"$log" 2>&1; then
    printf 'ok    %s\n' "$name"
  else
    printf 'FAIL  %s\n' "$name"
    sed 's/^/      /' "$log"
    failed=1
  fi
}

need() { # need TOOL: succeeds when TOOL is installed
  command -v "$1" >/dev/null && return 0
  if [[ -n ${CI-} ]]; then
    printf 'FAIL  %s no está instalado\n' "$1"
    failed=1
  else
    printf 'skip  %s no está instalado\n' "$1"
  fi
  return 1
}

local_only() { # local_only TOOL: succeeds outside CI when TOOL is installed
  [[ -z ${CI-} ]] && command -v "$1" >/dev/null
}

mapfile -t json < <(git ls-files '*.json' '*.jsonc')
mapfile -t lua < <(git ls-files '*.lua')
mapfile -t js < <(git ls-files '*.js')
mapfile -t py < <(git ls-files '*.py')
mapfile -t zshfiles < <(git ls-files '*.zsh' '.zshrc' '*/.zshrc')
bash_scripts=()
while IFS= read -r f; do
  [[ $f == *.sh ]] || head -n 1 "$f" | grep -qE '^#!.*\bbash\b' && bash_scripts+=("$f")
done < <(git ls-files)

check_json() { for f in "$@"; do jq empty "$f" || return; done; }
check_bash() { for f in "$@"; do bash -n "$f" || return; done; }
check_zsh() { for f in "$@"; do zsh -n "$f" || return; done; }
check_python() { python3 -c 'import ast, sys
for f in sys.argv[1:]:
    ast.parse(open(f, encoding="utf-8").read(), f)' "$@"; }
check_js() {
  # Qt's `.pragma library` is not JavaScript; strip it before handing the file to node.
  for f in "$@"; do
    if head -n 1 "$f" | grep -qx '\.pragma library'; then
      tail -n +2 "$f" | node --check || return
    else
      node --check "$f" || return
    fi
  done
}

need stow && run "stow (simulación)" stow --simulate --target="$HOME" desktop terminal maintenance
need jq && run "JSON (${#json[@]})" check_json "${json[@]}"
luac=$(command -v luac || command -v luac5.4 || true)
if [[ -n $luac ]]; then
  run "Lua (${#lua[@]})" "$luac" -p "${lua[@]}"
else
  need luac
fi
need node && run "JavaScript (${#js[@]})" check_js "${js[@]}"
need python3 && run "Python (${#py[@]})" check_python "${py[@]}"
run "Bash -n (${#bash_scripts[@]})" check_bash "${bash_scripts[@]}"
need zsh && run "Zsh -n (${#zshfiles[@]})" check_zsh "${zshfiles[@]}"
need shellcheck && run "ShellCheck (${#bash_scripts[@]})" shellcheck "${bash_scripts[@]}"

if local_only Hyprland; then
  run "Hyprland" Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua"
fi
if local_only qmllint; then
  # Only files qmllint can resolve: on most widgets (and on Omarchy's own
  # originals) it exits 255 without printing a diagnostic.
  run "QML" qmllint -I /usr/share/omarchy/shell \
    desktop/.config/omarchy/bar/modules/StatusModule.qml \
    desktop/.config/omarchy/plugins/wh01s17.clock/Panel.qml \
    desktop/.config/omarchy/plugins/wh01s17.monitor/Panel.qml \
    desktop/.config/omarchy/plugins/wh01s17.metronome/MetronomeCore.qml
fi
if local_only systemd-analyze; then
  mapfile -t units < <(git ls-files 'maintenance/.config/systemd/user/*')
  run "systemd (${#units[@]})" systemd-analyze verify --user "${units[@]}"
fi

exit "$failed"
