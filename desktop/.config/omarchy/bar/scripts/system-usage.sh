#!/usr/bin/env bash
set -euo pipefail

# Keep the decimal separator a dot regardless of the user's locale, so
# EPOCHREALTIME can be sliced into integer microseconds below.
export LC_NUMERIC=C

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${SYSTEM_USAGE_STATE_DIR:-$STATE_HOME/omarchy/bar/system-usage}"
STATE_FILE="$STATE_DIR/samples"
CACHE_FILE="$STATE_DIR/last.json"
LOCK_FILE="$STATE_DIR/lock"
ICON="󰍛"

# The bar runs one copy of this script per monitor, and they all fire at
# roughly the same instant. Without a shared cache the second and third
# copies see a previous sample only milliseconds old, fall under the
# elapsed-time guard, and report 0% CPU with 0 B/s disk -- so the widget
# flickered between real numbers and zeroes depending on which monitor
# wrote last. Whoever gets the lock first computes; the others reuse that
# answer, which also cuts the work to a third.
MIN_REFRESH_US="${SYSTEM_USAGE_MIN_REFRESH_US:-1500000}"

mkdir -p "$STATE_DIR"

# Whole disks only: partitions, loop, ram and zram devices would double-count
# the same traffic. /proc/diskstats counts in 512-byte sectors.
disk_sectors() {
  awk '
    {
      name = $3
      if (name ~ /^(loop|ram|zram|dm-|sr)/) next
      if (name ~ /[0-9]$/ && name ~ /^(sd|vd|hd)/) next
      if (name ~ /p[0-9]+$/ && name ~ /^(nvme|mmcblk)/) next
      read += $6
      write += $10
    }
    END { printf "%d %d\n", read + 0, write + 0 }
  ' /proc/diskstats
}

cpu_totals() {
  awk '/^cpu /{
    total = 0
    for (i = 2; i <= NF; i++) total += $i
    printf "%d %d\n", total, $5 + $6
  }' /proc/stat
}

human_bytes() {
  awk -v bytes="$1" 'BEGIN {
    split("B KB MB GB TB", unit, " ")
    i = 1
    while (bytes >= 1024 && i < 5) { bytes /= 1024; i++ }
    printf (bytes >= 100 || i == 1) ? "%.0f %s\n" : "%.1f %s\n", bytes, unit[i]
  }'
}

json_status() {
  local now_us cpu_total cpu_idle disk_read disk_write
  local prev_now prev_total prev_idle prev_read prev_write
  local cpu_percent read_rate write_rate elapsed
  local mem_total mem_available mem_used mem_percent
  local swap_total swap_free swap_used
  local class tooltip

  # Serialise the read-modify-write so the per-monitor copies cannot
  # interleave and corrupt each other's deltas.
  exec 9>"$LOCK_FILE"
  flock 9

  now_us="${EPOCHREALTIME/./}"

  prev_now=""; prev_total=0; prev_idle=0; prev_read=0; prev_write=0
  if [[ -r "$STATE_FILE" ]]; then
    read -r prev_now prev_total prev_idle prev_read prev_write < "$STATE_FILE" || true
  fi
  # Pre-cache versions stored seconds with a fractional part. Such a value is
  # not an integer, so discard it rather than letting (( )) choke on it.
  [[ "$prev_now" =~ ^[0-9]+$ ]] || prev_now=""

  # A sibling monitor already sampled a moment ago: reuse its answer rather
  # than computing a delta over a near-zero interval.
  if [[ -n "$prev_now" && -r "$CACHE_FILE" ]] && (( now_us - prev_now < MIN_REFRESH_US )); then
    command cat "$CACHE_FILE"
    return
  fi

  read -r cpu_total cpu_idle < <(cpu_totals)
  read -r disk_read disk_write < <(disk_sectors)

  printf '%s %s %s %s %s\n' "$now_us" "$cpu_total" "$cpu_idle" "$disk_read" "$disk_write" > "$STATE_FILE"

  cpu_percent=0; read_rate=0; write_rate=0
  if [[ -n "$prev_now" ]]; then
    elapsed="$(awk -v a="$now_us" -v b="$prev_now" 'BEGIN { d = (a - b) / 1000000; print (d > 0.05 && d < 600) ? d : 0 }')"
    if [[ "$elapsed" != "0" ]]; then
      cpu_percent="$(awk -v t="$cpu_total" -v pt="$prev_total" -v i="$cpu_idle" -v pi="$prev_idle" \
        'BEGIN { dt = t - pt; if (dt <= 0) { print 0; exit } p = 100 * (1 - (i - pi) / dt); print (p < 0) ? 0 : (p > 100 ? 100 : int(p + 0.5)) }')"
      read_rate="$(awk -v s="$disk_read" -v p="$prev_read" -v e="$elapsed" 'BEGIN { r = (s - p) * 512 / e; print (r > 0) ? int(r) : 0 }')"
      write_rate="$(awk -v s="$disk_write" -v p="$prev_write" -v e="$elapsed" 'BEGIN { r = (s - p) * 512 / e; print (r > 0) ? int(r) : 0 }')"
    fi
  fi

  mem_total="$(awk '/^MemTotal:/ {print $2 * 1024}' /proc/meminfo)"
  mem_available="$(awk '/^MemAvailable:/ {print $2 * 1024}' /proc/meminfo)"
  mem_used=$((mem_total - mem_available))
  mem_percent="$(awk -v u="$mem_used" -v t="$mem_total" 'BEGIN { print (t > 0) ? int(100 * u / t + 0.5) : 0 }')"
  swap_total="$(awk '/^SwapTotal:/ {print $2 * 1024}' /proc/meminfo)"
  swap_free="$(awk '/^SwapFree:/ {print $2 * 1024}' /proc/meminfo)"
  swap_used=$((swap_total - swap_free))

  if (( cpu_percent >= 85 || mem_percent >= 90 )); then
    class="critical"
  elif (( cpu_percent >= 60 || mem_percent >= 75 )); then
    class="busy"
  else
    class="idle"
  fi

  printf -v tooltip \
    'CPU · %s%%\nRAM usada · %s (%s%%)\nRAM libre · %s\nDisco · ↓ %s/s  ↑ %s/s' \
    "$cpu_percent" \
    "$(human_bytes "$mem_used")" "$mem_percent" \
    "$(human_bytes "$mem_available")" \
    "$(human_bytes "$read_rate")" "$(human_bytes "$write_rate")"

  if (( swap_total > 0 )); then
    tooltip+=$'\n'"Swap · $(human_bytes "$swap_used") de $(human_bytes "$swap_total")"
  fi

  jq -cn \
    --arg text "$ICON" \
    --arg class "$class" \
    --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}' > "$CACHE_FILE.$$"
  mv -f "$CACHE_FILE.$$" "$CACHE_FILE"
  command cat "$CACHE_FILE"
}

case "${1:-print}" in
  print) json_status ;;
  *)
    echo "Usage: $0 {print}" >&2
    exit 2
    ;;
esac
