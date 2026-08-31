#!/usr/bin/env bash
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${GIT_BRANCH_STATE_DIR:-$STATE_HOME/omarchy/bar/git-branch}"
CWD_FILE="$STATE_DIR/cwd"
ICON="󰘬"

mkdir -p "$STATE_DIR"

current_dir() {
  local dir
  [[ -r "$CWD_FILE" ]] || return 1
  IFS= read -r dir < "$CWD_FILE" || return 1
  [[ -n "$dir" && -d "$dir" ]] || return 1
  printf '%s\n' "$dir"
}

empty_status() {
  jq -cn '{text: "", class: "inactive"}'
}

json_status() {
  local dir branch status dirty conflict class marker subtitle rows_json
  local ahead behind ahead_behind changed_count

  dir="$(current_dir || true)"
  [[ -n "$dir" ]] || { empty_status; return; }
  git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null || { empty_status; return; }

  dir="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$dir")"
  branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  [[ -n "$branch" ]] || branch="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || printf '?\n')"

  status="$(git -C "$dir" status --porcelain 2>/dev/null || true)"
  changed_count="$(grep -c . <<< "$status" || true)"
  [[ -n "$status" ]] || changed_count=0
  dirty="false"
  [[ "$changed_count" -gt 0 ]] && dirty="true"

  conflict="false"
  grep -qE '^(UU|AA|DD) ' <<< "$status" && conflict="true"

  ahead_behind="$(git -C "$dir" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null || printf '0\t0\n')"
  behind="$(awk '{print $1+0}' <<< "$ahead_behind")"
  ahead="$(awk '{print $2+0}' <<< "$ahead_behind")"

  if [[ "$conflict" == "true" ]]; then
    class="conflict"; marker=" !"
    subtitle="Conflictos de merge sin resolver"
  elif [[ "$dirty" == "true" ]]; then
    class="dirty"; marker=" *"
    subtitle="$changed_count archivo(s) con cambios sin commitear"
  else
    class="clean"; marker=""
    subtitle="Árbol de trabajo limpio"
  fi

  if (( ahead > 0 || behind > 0 )); then
    subtitle="$subtitle · ↑$ahead ↓$behind respecto al remoto"
  fi

  rows_json="$(jq -cn \
    --arg repo "$(basename "$dir")" \
    --arg branch "$branch" \
    --arg changed "$changed_count" \
    --arg ahead_behind "↑$ahead ↓$behind" \
    '[
      {icon: "󰉋", label: "Repositorio", detail: "Directorio activo", value: $repo},
      {icon: "󰘬", label: "Rama", detail: "HEAD actual", value: $branch},
      {icon: "󰄲", label: "Cambios", detail: "Sin commitear", value: $changed},
      {icon: "󰩠", label: "Remoto", detail: "Ahead / behind", value: $ahead_behind}
    ]')"

  jq -cn \
    --arg text "$ICON $branch$marker" \
    --arg class "$class" \
    --arg tooltip "$subtitle" \
    --arg subtitle "$subtitle" \
    --arg headline "$branch" \
    --argjson rows "$rows_json" \
    --arg copy_cmd '$HOME/.config/omarchy/bar/scripts/git-branch.sh copy' \
    '{
      text: $text,
      class: $class,
      tooltip: $tooltip,
      panel: {
        icon: "󰘬",
        title: "Git",
        subtitle: $subtitle,
        headline: $headline,
        sectionTitle: "ESTADO",
        actionsTitle: "ACCIONES",
        rows: $rows,
        actions: [{icon: "󰆏", label: "Copiar rama", command: $copy_cmd}]
      }
    }'
}

copy_branch() {
  local dir branch
  dir="$(current_dir || true)"
  [[ -n "$dir" ]] || return 0
  branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null || true)"
  [[ -n "$branch" ]] || return 0
  printf '%s' "$branch" | wl-copy
  notify-send -u low "Rama copiada" "$branch"
}

case "${1:-print}" in
  print) json_status ;;
  copy) copy_branch ;;
  *)
    echo "Usage: $0 {print|copy}" >&2
    exit 2
    ;;
esac
