#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${CTF_STATE_DIR:-$HOME/.config/waybar/state/ctf}"
TARGET_FILE="$STATE_DIR/target"
SIGNAL=11

COLOR_TARGET="#ff5f5f"
COLOR_VPN="#33ccff"
COLOR_LAN="#5fd75f"
COLOR_MISSING="#777777"
COLOR_SEPARATOR="#666666"

mkdir -p "$STATE_DIR"

refresh_waybar() {
  pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
}

valid_ipv4() {
  local ip="${1:-}"

  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

  local octet
  local -a octets
  IFS=. read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    ((10#$octet >= 0 && 10#$octet <= 255)) || return 1
  done
}

vpn_ip() {
  local iface
  local ifaces="${CTF_VPN_IFACES:-tun0 tun1 tap0 tap1 wg0 wg1 ppp0}"

  for iface in $ifaces; do
    ip -o -4 addr show dev "$iface" scope global 2>/dev/null |
      awk 'NR == 1 { split($4, a, "/"); print a[1]; exit }'
  done | awk 'NF { print; exit }'
}

lan_ip() {
  local iface
  local ifaces="${CTF_LAN_IFACES:-wlan0}"

  for iface in $ifaces; do
    ip -o -4 addr show dev "$iface" scope global 2>/dev/null |
      awk 'NR == 1 { split($4, a, "/"); print a[1]; exit }'
  done | awk 'NF { print; exit }'
}

target_ip() {
  local target

  [[ -s "$TARGET_FILE" ]] || return 1
  IFS= read -r target < "$TARGET_FILE" || return 1
  valid_ipv4 "$target" || return 1
  printf '%s\n' "$target"
}

format_segment() {
  local color="$1"
  local icon="$2"
  local value="$3"

  if [[ -z "$value" ]]; then
    color="$COLOR_MISSING"
    value="-"
  fi

  printf "<span foreground='%s'>%s %s</span>" "$color" "$icon" "$value"
}

json_status() {
  local target vpn lan target_segment vpn_segment lan_segment separator text class tooltip

  target="$(target_ip || true)"
  vpn="$(vpn_ip || true)"
  lan="$(lan_ip || true)"

  target_segment="$(format_segment "$COLOR_TARGET" "󰓾" "$target")"
  vpn_segment="$(format_segment "$COLOR_VPN" "󰖂" "$vpn")"
  lan_segment="$(format_segment "$COLOR_LAN" "󰩠" "$lan")"
  separator="<span foreground='$COLOR_SEPARATOR'>|</span>"
  text="$target_segment $separator $vpn_segment $separator $lan_segment"

  if [[ -n "$target" && -n "$vpn" ]]; then
    class="active"
  elif [[ -n "$target" && -n "$lan" ]]; then
    class="no-vpn"
  elif [[ -n "$target" ]]; then
    class="missing-me"
  elif [[ -n "$vpn" || -n "$lan" ]]; then
    class="missing-target"
  else
    text="CTF -"
    class="inactive"
  fi

  printf -v tooltip \
    'Victim: %s\nVPN: %s\nWLAN: %s\nVPN interfaces: %s\nLAN interfaces: %s' \
    "${target:-not set}" \
    "${vpn:-not found}" \
    "${lan:-not found}" \
    "${CTF_VPN_IFACES:-tun0 tun1 tap0 tap1 wg0 wg1 ppp0}" \
    "${CTF_LAN_IFACES:-wlan0}"

  jq -cn \
    --arg text "$text" \
    --arg class "$class" \
    --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}'
}

case "${1:-print}" in
  print)
    json_status
    ;;
  target|set-target)
    ip_address="${2:-}"
    if ! valid_ipv4 "$ip_address"; then
      echo "Usage: $0 target <ipv4>" >&2
      exit 2
    fi
    printf '%s\n' "$ip_address" > "$TARGET_FILE"
    refresh_waybar
    ;;
  myip|refresh)
    printf 'VPN: %s\nWLAN: %s\n' "$(vpn_ip || true)" "$(lan_ip || true)"
    refresh_waybar
    ;;
  clear)
    rm -f "$TARGET_FILE"
    refresh_waybar
    ;;
  copy-target)
    target="$(target_ip || true)"
    [[ -n "$target" ]] || exit 1
    printf '%s' "$target" | wl-copy
    ;;
  *)
    echo "Usage: $0 {print|target <ipv4>|myip|refresh|clear|copy-target}" >&2
    exit 2
    ;;
esac
