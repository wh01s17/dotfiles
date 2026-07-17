#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${POMODORO_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/waybar/pomodoro}"
STATE_FILE="$STATE_DIR/state.json"
LOCK_FILE="$STATE_DIR/lock"
SIGNAL=12

DEFAULT_PRESET="${POMODORO_PRESET:-balanced}"

valid_preset() {
  case "$1" in
    balanced|classic|deep|ultradian) return 0 ;;
    *) return 1 ;;
  esac
}

apply_preset() {
  case "$preset" in
    balanced)
      PRESET_LABEL="Equilibrado · 40/10"
      WORK_SECONDS=2400
      SHORT_BREAK_SECONDS=600
      LONG_BREAK_SECONDS=1200
      LONG_BREAK_EVERY=4
      ;;
    classic)
      PRESET_LABEL="Clásico · 25/5"
      WORK_SECONDS=1500
      SHORT_BREAK_SECONDS=300
      LONG_BREAK_SECONDS=900
      LONG_BREAK_EVERY=4
      ;;
    deep)
      PRESET_LABEL="Enfoque profundo · 50/10"
      WORK_SECONDS=3000
      SHORT_BREAK_SECONDS=600
      LONG_BREAK_SECONDS=1200
      LONG_BREAK_EVERY=4
      ;;
    ultradian)
      PRESET_LABEL="Ultradiano · 90/20"
      WORK_SECONDS=5400
      SHORT_BREAK_SECONDS=1200
      LONG_BREAK_SECONDS=1800
      LONG_BREAK_EVERY=2
      ;;
  esac
}

valid_preset "$DEFAULT_PRESET" || DEFAULT_PRESET="balanced"
preset="$DEFAULT_PRESET"
apply_preset

phase="work"
running="false"
end_at=0
remaining="$WORK_SECONDS"
sessions=0

umask 077
mkdir -p "$STATE_DIR"
exec 9>"$LOCK_FILE"
flock 9

refresh_waybar() {
  pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
}

sync_do_not_disturb() {
  if [[ "$phase" == "work" && "$running" == "true" ]]; then
    makoctl mode -a do-not-disturb >/dev/null 2>&1 || true
  else
    makoctl mode -r do-not-disturb >/dev/null 2>&1 || true
  fi
}

write_state() {
  local temporary

  temporary="$(mktemp "$STATE_DIR/state.XXXXXX")"
  jq -cn \
    --arg preset "$preset" \
    --arg phase "$phase" \
    --argjson running "$running" \
    --argjson end_at "$end_at" \
    --argjson remaining "$remaining" \
    --argjson sessions "$sessions" \
    '{preset: $preset, phase: $phase, running: $running, end_at: $end_at, remaining: $remaining, sessions: $sessions}' \
    > "$temporary"
  mv -f "$temporary" "$STATE_FILE"
}

load_state() {
  local values=""

  if [[ -s "$STATE_FILE" ]]; then
    values="$(jq -er '
      select(
        type == "object" and
        ((.preset // "__missing__") == "__missing__" or .preset == "balanced" or .preset == "classic" or .preset == "deep" or .preset == "ultradian") and
        (.phase == "work" or .phase == "short_break" or .phase == "long_break") and
        (.running | type == "boolean") and
        (.end_at | type == "number") and .end_at >= 0 and
        (.remaining | type == "number") and .remaining >= 0 and
        (.sessions | type == "number") and .sessions >= 0
      ) |
      [(.preset // "__missing__"), .phase, .running, (.end_at | floor), (.remaining | floor), (.sessions | floor)] |
      @tsv
    ' "$STATE_FILE" 2>/dev/null || true)"
  fi

  if [[ -n "$values" ]]; then
    IFS=$'\t' read -r preset phase running end_at remaining sessions <<< "$values"
    if [[ "$preset" == "__missing__" ]]; then
      preset="$DEFAULT_PRESET"
      apply_preset
      phase="work"
      running="false"
      end_at=0
      remaining="$WORK_SECONDS"
      sessions=0
      write_state
      return
    fi
    apply_preset
    return
  fi

  preset="$DEFAULT_PRESET"
  apply_preset
  phase="work"
  running="false"
  end_at=0
  remaining="$WORK_SECONDS"
  sessions=0
  write_state
}

remaining_now() {
  local now="$1"
  local value

  if [[ "$running" == "true" ]]; then
    value=$((end_at - now))
    ((value > 0)) || value=0
  else
    value="$remaining"
  fi

  printf '%s\n' "$value"
}

notify_phase_finished() {
  if [[ "$phase" == "work" ]]; then
    notify-send -a Waybar -u normal "Pomodoro completado" "Hora de descansar" >/dev/null 2>&1 || true
  else
    notify-send -a Waybar -u normal "Descanso completado" "Hora de volver al enfoque" >/dev/null 2>&1 || true
  fi
}

finish_phase() {
  if [[ "$phase" == "work" ]]; then
    makoctl mode -r do-not-disturb >/dev/null 2>&1 || true
  fi

  notify_phase_finished

  if [[ "$phase" == "work" ]]; then
    sessions=$((sessions + 1))
    if ((sessions % LONG_BREAK_EVERY == 0)); then
      phase="long_break"
      remaining="$LONG_BREAK_SECONDS"
    else
      phase="short_break"
      remaining="$SHORT_BREAK_SECONDS"
    fi
  else
    phase="work"
    remaining="$WORK_SECONDS"
  fi

  running="false"
  end_at=0
  write_state
}

normalize_state() {
  local now="$1"

  if [[ "$running" == "true" ]] && ((now >= end_at)); then
    finish_phase
  fi
}

toggle_timer() {
  local now current

  now="$(date +%s)"
  load_state
  normalize_state "$now"
  current="$(remaining_now "$now")"

  if [[ "$running" == "true" ]]; then
    running="false"
    end_at=0
    remaining="$current"
  else
    running="true"
    end_at=$((now + current))
    remaining="$current"
  fi

  sync_do_not_disturb
  write_state
  refresh_waybar
}

reset_timer() {
  local now

  now="$(date +%s)"
  load_state
  normalize_state "$now"

  case "$phase" in
    work) remaining="$WORK_SECONDS" ;;
    short_break) remaining="$SHORT_BREAK_SECONDS" ;;
    long_break) remaining="$LONG_BREAK_SECONDS" ;;
  esac

  running="false"
  end_at=0
  sync_do_not_disturb
  write_state
  refresh_waybar
}

skip_phase() {
  local now

  now="$(date +%s)"
  load_state
  normalize_state "$now"

  if [[ "$phase" == "work" ]]; then
    phase="short_break"
    remaining="$SHORT_BREAK_SECONDS"
  else
    phase="work"
    remaining="$WORK_SECONDS"
  fi

  running="false"
  end_at=0
  sync_do_not_disturb
  write_state
  refresh_waybar
}

set_preset() {
  local selected="$1"

  valid_preset "$selected" || return 2
  preset="$selected"
  apply_preset
  phase="work"
  running="false"
  end_at=0
  remaining="$WORK_SECONDS"
  sessions=0
  sync_do_not_disturb
  write_state
  refresh_waybar
}

preset_menu() {
  local choice

  choice="$(
    omarchy menu select \
      "Sistema Pomodoro" \
      "Equilibrado · 40/10" \
      "Clásico · 25/5" \
      "Enfoque profundo · 50/10" \
      "Ultradiano · 90/20" || true
  )"

  case "$choice" in
    "Equilibrado · 40/10") set_preset balanced ;;
    "Clásico · 25/5") set_preset classic ;;
    "Enfoque profundo · 50/10") set_preset deep ;;
    "Ultradiano · 90/20") set_preset ultradian ;;
  esac
}

adjust_timer() {
  local delta="$1"
  local now current

  now="$(date +%s)"
  load_state
  normalize_state "$now"
  current="$(remaining_now "$now")"
  current=$((current + delta))
  ((current >= 60)) || current=60
  ((current <= 14400)) || current=14400
  remaining="$current"

  if [[ "$running" == "true" ]]; then
    end_at=$((now + current))
  else
    end_at=0
  fi

  write_state
  refresh_waybar
}

print_status() {
  local now current minutes seconds formatted icon label status class text tooltip

  now="$(date +%s)"
  load_state
  normalize_state "$now"
  current="$(remaining_now "$now")"
  minutes=$((current / 60))
  seconds=$((current % 60))
  printf -v formatted '%02d:%02d' "$minutes" "$seconds"

  case "$phase" in
    work)
      icon="󰔟"
      label="Enfoque"
      ;;
    short_break)
      icon="󰒲"
      label="Descanso corto"
      ;;
    long_break)
      icon="󰤄"
      label="Descanso largo"
      ;;
  esac

  if [[ "$running" == "true" ]]; then
    status="running"
    text="$icon $formatted"
  else
    status="paused"
    text="$icon $formatted 󰏤"
  fi

  class="${phase//_/-}-$status"
  printf -v tooltip \
    'Sistema: %s\n%s: %s\nPomodoros completados: %s\n\nClic izquierdo: iniciar/pausar\nClic central: saltar fase\nClic derecho: elegir sistema\nScroll: ajustar ±1 minuto' \
    "$PRESET_LABEL" "$label" "$formatted" "$sessions"

  jq -cn \
    --arg text "$text" \
    --arg class "$class" \
    --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}'
}

case "${1:-print}" in
  print) print_status ;;
  toggle) toggle_timer ;;
  reset) reset_timer ;;
  skip) skip_phase ;;
  menu) preset_menu ;;
  preset) set_preset "${2:-}" ;;
  add) adjust_timer 60 ;;
  subtract) adjust_timer -60 ;;
  *)
    echo "Usage: $0 {print|toggle|reset|skip|menu|preset <name>|add|subtract}" >&2
    exit 2
    ;;
esac
