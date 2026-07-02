#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${CTF_STATE_DIR:-$HOME/.config/waybar/state/ctf}"
TARGET_FILE="$STATE_DIR/target"
SIGNAL=11

mkdir -p "$STATE_DIR"

refresh_waybar() {
  pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
}

valid_ipv4() {
  local ip="${1:-}"

  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

  local octet
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
  [[ -s "$TARGET_FILE" ]] && head -n 1 "$TARGET_FILE"
}

json_status() {
  local target vpn lan target_segment vpn_segment lan_segment text class tooltip

  target="$(target_ip || true)"
  vpn="$(vpn_ip || true)"
  lan="$(lan_ip || true)"

  target_segment="󰓾 ${target:--}"
  vpn_segment=""
  lan_segment="󰩠 ${lan:--}"

  if [[ -n "$vpn" ]]; then
    vpn_segment=" | 󰖂 $vpn"
  fi

  text="$target_segment$vpn_segment | $lan_segment"

  if [[ -n "$target" && -n "$vpn" && -n "$lan" ]]; then
    class="active"
  elif [[ -n "$target" && -n "$vpn" ]]; then
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

  tooltip="Target: ${target:-not set}\nVPN: ${vpn:-not found}\nWLAN: ${lan:-not found}\nVPN interfaces: ${CTF_VPN_IFACES:-tun0 tun1 tap0 tap1 wg0 wg1 ppp0}\nLAN interfaces: ${CTF_LAN_IFACES:-wlan0}"

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
