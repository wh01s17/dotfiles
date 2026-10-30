#!/usr/bin/env bash
# Static checks for this repository: ./test.sh
#
# With CI set, a missing tool for a portable check is a failure. Checks that
# need the live session (Hyprland, Omarchy's QML modules, the user's systemd
# units) run only outside CI and only when their tool is installed.
# check_* functions are called through run: SC2329 on ShellCheck 0.10+, SC2317
# on older releases such as the one in CI.
# shellcheck disable=SC2317,SC2329
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

# platform/ is a frozen copy of Omarchy (MIT): checked separately below, not
# held to this repo's ShellCheck and style rules.
files=()
while IFS= read -r -d '' f; do
  [[ -f $f && $f != platform/* ]] && files+=("$f")
done < <(git ls-files --cached --others --exclude-standard --deduplicate -z)
json=() lua=() js=() py=() zshfiles=() bash_scripts=()
for f in "${files[@]}"; do
  case "$f" in
    *.json|*.jsonc) json+=("$f") ;;
    *.lua) lua+=("$f") ;;
    *.js) js+=("$f") ;;
    *.py) py+=("$f") ;;
    *.zsh|*/.zshrc) zshfiles+=("$f") ;;
    *.sh) bash_scripts+=("$f") ;;
    *)
      if head -n 1 "$f" | grep -qE '^#!.*\bbash\b'; then
        bash_scripts+=("$f")
      elif head -n 1 "$f" | grep -qE '^#!.*\bpython3?\b'; then
        py+=("$f")
      fi ;;
  esac
done

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

check_stow() {
  stow --simulate --target="$HOME" platform desktop terminal maintenance &&
    stow --simulate --no-folding --target="$HOME" apps
}
need stow && run "stow (simulación)" check_stow
need jq && run "JSON (${#json[@]})" check_json "${json[@]}"
luac=$(command -v luac || command -v luac5.4 || true)
if [[ -n $luac ]]; then
  run "Lua (${#lua[@]})" "$luac" -p "${lua[@]}"
else
  need luac
fi
need node && run "JavaScript (${#js[@]})" check_js "${js[@]}"
need node && run "External display selection" node tests/monitor-external.js
lua_runtime=$(command -v lua || command -v lua5.4 || true)
if [[ -n $lua_runtime ]]; then
  run "External display layout" "$lua_runtime" tests/monitor-external.lua
else
  need lua
fi
need python3 && run "Python (${#py[@]})" check_python "${py[@]}"
need python3 && run "Enlaces y sincronizador" python3 -B tests/dotfiles-sync.py
need python3 && run "Instalador y backports" env TEST_DOTFILES="$PWD" python3 -B -m unittest discover -s installer/tests -v
run "Bash -n (${#bash_scripts[@]})" check_bash "${bash_scripts[@]}"
need zsh && run "Zsh -n (${#zshfiles[@]})" check_zsh "${zshfiles[@]}"
if need zsh && need git && need python3; then
  run "Git update all (repositorios locales)" python3 tests/git-update-all.py
fi
need shellcheck && run "ShellCheck (${#bash_scripts[@]})" shellcheck "${bash_scripts[@]}"

check_platform() {
  local root=platform/.local/share/wh01s17 file
  local -a platform_lua=() platform_bash=()
  mapfile -t platform_lua < <(find "$root/default/hypr" "$root/config/hypr" -name '*.lua')
  while IFS= read -r -d '' file; do
    head -n 1 "$file" | grep -qE '^#!.*\bbash\b' && platform_bash+=("$file")
  done < <(find "$root/bin" -type f -print0)
  [[ -z $luac ]] || "$luac" -p "${platform_lua[@]}" || return
  check_bash "${platform_bash[@]}" || return
  # Runtime must use its user-owned installation and no upstream package repository.
  grep -q 'local/share/wh01s17' "$root/default/bash/env-bootstrap" || return
  ! grep -q 'pacman.conf$' "$root/install/post-install/pacman.sh"
}
if [[ -d platform ]]; then
  run "platform (runtime wh01s17)" check_platform
fi

if local_only Hyprland; then
  run "Hyprland" Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua"
fi
if local_only qmllint; then
  # Only files qmllint can resolve: on most widgets (and on Omarchy's own
  # originals) it exits 255 without printing a diagnostic.
  run "QML" qmllint -I "${WH01S17_PATH:-$PWD/platform/.local/share/wh01s17}/shell" \
    desktop/.config/wh01s17/bar/modules/StatusModule.qml \
    desktop/.config/wh01s17/plugins/wh01s17.clock/Panel.qml \
    desktop/.config/wh01s17/plugins/wh01s17.monitor/Panel.qml \
    desktop/.config/wh01s17/plugins/wh01s17.metronome/MetronomeCore.qml
fi
if local_only systemd-analyze; then
  units=()
  for file in "${files[@]}"; do
    [[ $file == maintenance/.config/systemd/user/* ]] && units+=("$file")
  done
  run "systemd (${#units[@]})" systemd-analyze verify --user "${units[@]}"
fi

exit "$failed"
