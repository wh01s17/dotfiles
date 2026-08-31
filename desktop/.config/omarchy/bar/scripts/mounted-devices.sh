#!/usr/bin/env bash
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${MOUNTS_STATE_DIR:-$STATE_HOME/omarchy/bar/mounts}"
SEEN_FILE="$STATE_DIR/seen"
ICON="󰋻"

mkdir -p "$STATE_DIR"

relevant_devices() {
  lsblk -J -o NAME,PATH,MOUNTPOINT,SIZE,FSTYPE,RM,TYPE,MODEL,LABEL 2>/dev/null |
    jq -c '[
      .. | objects
      | select(has("mountpoint"))
      | select(.mountpoint != null and .mountpoint != "" and .mountpoint != "[SWAP]")
      | select(.rm == true or .type == "loop")
      | {
          path,
          mountpoint,
          size,
          type,
          fstype: (.fstype // "?"),
          name: (.label // .model // (.mountpoint | split("/") | last) // .name)
        }
    ]'
}

json_status() {
  local devices count prev_paths new_paths is_new class text tooltip subtitle rows_json

  devices="$(relevant_devices)"
  count="$(jq 'length' <<< "$devices")"

  prev_paths=""
  [[ -r "$SEEN_FILE" ]] && prev_paths="$(cat "$SEEN_FILE")"
  new_paths="$(jq -r '.[].path' <<< "$devices")"

  is_new="false"
  if [[ -n "$new_paths" ]]; then
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      grep -qxF "$p" <<< "$prev_paths" || is_new="true"
    done <<< "$new_paths"
  fi
  printf '%s\n' "$new_paths" > "$SEEN_FILE"

  if (( count == 0 )); then
    text=""
    class="inactive"
    subtitle="Sin unidades extraíbles ni imágenes montadas"
  elif [[ "$is_new" == "true" ]]; then
    text="$ICON $count"
    class="new"
    subtitle="Nuevo dispositivo detectado"
  else
    text="$ICON $count"
    class="active"
    subtitle="$count dispositivo(s) montado(s)"
  fi

  rows_json="$(jq -c '[.[] | {
    icon: (if .type == "loop" then "󰄲" else "󰋻" end),
    label: .name,
    detail: (.fstype + " · " + .size),
    value: .mountpoint
  }]' <<< "$devices")"

  jq -cn \
    --arg text "$text" \
    --arg class "$class" \
    --arg tooltip "$subtitle" \
    --arg subtitle "$subtitle" \
    --arg headline "$count" \
    --argjson rows "$rows_json" \
    --arg open_cmd '$HOME/.config/omarchy/bar/scripts/mounted-devices.sh open' \
    --arg eject_cmd '$HOME/.config/omarchy/bar/scripts/mounted-devices.sh eject' \
    --argjson has_devices "$([[ "$count" -gt 0 ]] && printf 'true' || printf 'false')" \
    '{
      text: $text,
      class: $class,
      tooltip: $tooltip,
      panel: {
        icon: "󰋻",
        title: "Dispositivos montados",
        subtitle: $subtitle,
        headline: $headline,
        sectionTitle: "MONTADOS",
        actionsTitle: "ACCIONES",
        rows: $rows,
        actions: [
          {icon: "󰉋", label: "Abrir", command: $open_cmd, enabled: $has_devices, close: true},
          {icon: "󰩓", label: "Expulsar", command: $eject_cmd, enabled: $has_devices}
        ]
      }
    }'
}

choose_mountpoint() {
  local devices mountpoints choice
  devices="$(relevant_devices)"
  mapfile -t mountpoints < <(jq -r '.[].mountpoint' <<< "$devices")

  if (( ${#mountpoints[@]} == 0 )); then
    notify-send -u low "Omarchy" "No hay dispositivos montados"
    return 1
  elif (( ${#mountpoints[@]} == 1 )); then
    printf '%s\n' "${mountpoints[0]}"
  else
    omarchy menu select "Selecciona un dispositivo" "${mountpoints[@]}" || return 1
  fi
}

open_device() {
  local mountpoint
  mountpoint="$(choose_mountpoint || true)"
  [[ -n "$mountpoint" ]] || return 0
  xdg-open "$mountpoint" >/dev/null 2>&1 &
}

eject_device() {
  local mountpoint devices path
  mountpoint="$(choose_mountpoint || true)"
  [[ -n "$mountpoint" ]] || return 0

  devices="$(relevant_devices)"
  path="$(jq -r --arg mp "$mountpoint" '.[] | select(.mountpoint == $mp) | .path' <<< "$devices" | head -n1)"
  [[ -n "$path" ]] || return 0

  if udisksctl unmount -b "$path" &>/dev/null; then
    notify-send -u low "Dispositivo expulsado" "$mountpoint"
  else
    notify-send -u critical "No se pudo expulsar" "$mountpoint"
  fi
}

case "${1:-print}" in
  print) json_status ;;
  open) open_device ;;
  eject) eject_device ;;
  *)
    echo "Usage: $0 {print|open|eject}" >&2
    exit 2
    ;;
esac
