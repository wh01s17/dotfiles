#!/usr/bin/env bash
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${CTF_STATE_DIR:-$STATE_HOME/omarchy/bar/ctf}"
LEGACY_STATE_DIR="$HOME/.config/waybar/state/ctf"
TARGET_FILE="$STATE_DIR/target"

COLOR_TARGET="#ff5f5f"
COLOR_VPN="#33ccff"
COLOR_LAN="#5fd75f"
COLOR_MISSING="#777777"
COLOR_SEPARATOR="#666666"

if [[ ! -e "$STATE_DIR" && -d "$LEGACY_STATE_DIR" ]]; then
  mkdir -p "$(dirname "$STATE_DIR")"
  mv "$LEGACY_STATE_DIR" "$STATE_DIR" 2>/dev/null || true
fi
mkdir -p "$STATE_DIR"

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

lan_interfaces() {
  local detected

  if [[ -n "${CTF_LAN_IFACES:-}" ]]; then
    printf '%s\n' "$CTF_LAN_IFACES"
    return
  fi

  detected="$(
    ip -o -4 route show default 2>/dev/null |
      awk '{ for (field = 1; field <= NF; field++) if ($field == "dev") { print $(field + 1); break } }' |
      awk '!seen[$0]++' |
      paste -sd ' ' -
  )"

  printf '%s\n' "${detected:-wlan0 wlo1 wlp1s0}"
}

lan_ip() {
  local iface
  local ifaces

  ifaces="$(lan_interfaces)"

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

  printf "<font color='%s'>%s %s</font>" "$color" "$icon" "$value"
}

json_status() {
  local target vpn lan target_segment vpn_segment lan_segment separator text class tooltip subtitle headline
  local copy_enabled="false"

  target="$(target_ip || true)"
  vpn="$(vpn_ip || true)"
  lan="$(lan_ip || true)"

  target_segment="$(format_segment "$COLOR_TARGET" "󰓾" "$target")"
  vpn_segment="$(format_segment "$COLOR_VPN" "󰖂" "$vpn")"
  lan_segment="$(format_segment "$COLOR_LAN" "󰩠" "$lan")"
  separator="<font color='$COLOR_SEPARATOR'>|</font>"
  text="$target_segment $separator $vpn_segment $separator $lan_segment"

  if [[ -n "$target" && -n "$vpn" ]]; then
    class="active"
    subtitle="Objetivo y túnel VPN preparados"
  elif [[ -n "$target" && -n "$lan" ]]; then
    class="no-vpn"
    subtitle="Objetivo definido sin túnel VPN"
  elif [[ -n "$target" ]]; then
    class="missing-me"
    subtitle="Objetivo definido sin red local"
  elif [[ -n "$vpn" || -n "$lan" ]]; then
    class="missing-target"
    subtitle="Conectividad lista; falta el objetivo"
  else
    text="CTF -"
    class="inactive"
    subtitle="Sin conectividad ni objetivo"
  fi

  headline="${target:-—}"
  [[ -n "$target" ]] && copy_enabled="true"

  printf -v tooltip \
    'Victim: %s\nVPN: %s\nWLAN: %s\nVPN interfaces: %s\nLAN interfaces: %s' \
    "${target:-not set}" \
    "${vpn:-not found}" \
    "${lan:-not found}" \
    "${CTF_VPN_IFACES:-tun0 tun1 tap0 tap1 wg0 wg1 ppp0}" \
    "$(lan_interfaces)"

  jq -cn \
    --arg text "$text" \
    --arg class "$class" \
    --arg tooltip "$tooltip" \
    --arg subtitle "$subtitle" \
    --arg headline "$headline" \
    --arg target "${target:-No definido}" \
    --arg vpn "${vpn:-Desconectada}" \
    --arg lan "${lan:-No detectada}" \
    --arg target_color "$([[ -n "$target" ]] && printf '%s' "$COLOR_TARGET" || printf '%s' "$COLOR_MISSING")" \
    --arg vpn_color "$([[ -n "$vpn" ]] && printf '%s' "$COLOR_VPN" || printf '%s' "$COLOR_MISSING")" \
    --arg lan_color "$([[ -n "$lan" ]] && printf '%s' "$COLOR_LAN" || printf '%s' "$COLOR_MISSING")" \
    --arg copy_command '$HOME/.config/omarchy/bar/scripts/ctf-ip.sh copy-target' \
    --arg clear_command '$HOME/.config/omarchy/bar/scripts/ctf-ip.sh clear' \
    --argjson copy_enabled "$copy_enabled" \
    '{
      text: $text,
      class: $class,
      tooltip: $tooltip,
      panel: {
        icon: "󰓾",
        title: "Panel CTF",
        subtitle: $subtitle,
        headline: $headline,
        sectionTitle: "CONEXIONES",
        actionsTitle: "OBJETIVO",
        rows: [
          {icon: "󰓾", label: "Máquina víctima", detail: "Objetivo activo", value: $target, color: $target_color},
          {icon: "󰖂", label: "Túnel VPN", detail: "Interfaz de laboratorio", value: $vpn, color: $vpn_color},
          {icon: "󰩠", label: "Red local", detail: "Dirección de esta máquina", value: $lan, color: $lan_color}
        ],
        actions: [
          {icon: "󰆏", label: "Copiar IP", command: $copy_command, enabled: $copy_enabled},
          {icon: "󰆴", label: "Limpiar", command: $clear_command, enabled: $copy_enabled}
        ]
      }
    }'
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
    ;;
  myip|refresh)
    printf 'VPN: %s\nWLAN: %s\n' "$(vpn_ip || true)" "$(lan_ip || true)"
    ;;
  clear)
    rm -f "$TARGET_FILE"
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
