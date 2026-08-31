#!/usr/bin/env bash
set -euo pipefail

ICON="󰄲"

detect_backend() {
  if command -v ufw &>/dev/null; then
    printf 'ufw\n'
  elif systemctl list-unit-files nftables.service &>/dev/null 2>&1; then
    printf 'nftables\n'
  elif systemctl list-unit-files iptables.service &>/dev/null 2>&1; then
    printf 'iptables\n'
  else
    printf 'none\n'
  fi
}

ufw_details() {
  local enabled_conf="no" active="inactive" policy="ACCEPT" rules=0 n=0 c

  if [[ -r /etc/ufw/ufw.conf ]]; then
    enabled_conf="$(awk -F= '/^ENABLED=/{gsub(/"/,"",$2); print tolower($2)}' /etc/ufw/ufw.conf)"
  fi

  active="$(systemctl is-active ufw.service 2>/dev/null || true)"
  [[ -n "$active" ]] || active="inactive"

  if [[ -r /etc/default/ufw ]]; then
    policy="$(awk -F= '/^DEFAULT_INPUT_POLICY=/{gsub(/"/,"",$2); print $2}' /etc/default/ufw)"
    [[ -n "$policy" ]] || policy="ACCEPT"
  fi

  if [[ -r /etc/ufw/user.rules ]]; then
    c="$(grep -c '^-A ufw-user-input ' /etc/ufw/user.rules 2>/dev/null || true)"
    n=$((n + ${c:-0}))
  fi
  if [[ -r /etc/ufw/user6.rules ]]; then
    c="$(grep -c '^-A ufw-user-input ' /etc/ufw/user6.rules 2>/dev/null || true)"
    n=$((n + ${c:-0}))
  fi
  rules="$n"

  printf '%s\n%s\n%s\n%s\n' "$enabled_conf" "$active" "$policy" "$rules"
}

json_status() {
  local backend class label subtitle rows_json actions_json
  local enabled_conf active policy rules

  backend="$(detect_backend)"

  case "$backend" in
    ufw)
      { read -r enabled_conf; read -r active; read -r policy; read -r rules; } < <(ufw_details)

      if [[ "$active" == "active" && "$enabled_conf" == "yes" && "$policy" == "DROP" ]]; then
        class="active"; label="ON"
        subtitle="Firewall activo, bloqueando entrante por defecto"
      elif [[ "$active" == "active" && "$enabled_conf" == "yes" ]]; then
        class="permissive"; label="ON*"
        subtitle="Activo, pero la política de entrada es $policy"
      else
        class="inactive"; label="OFF"
        subtitle="Firewall inactivo"
      fi

      rows_json="$(jq -cn \
        --arg backend "ufw" \
        --arg active "$active" \
        --arg policy "$policy" \
        --arg rules "$rules" \
        '[
          {icon: "󰩠", label: "Backend", detail: "Gestor de firewall", value: $backend},
          {icon: "󰄲", label: "Servicio", detail: "systemctl is-active ufw", value: $active},
          {icon: "󰖂", label: "Política INPUT", detail: "Tráfico entrante por defecto", value: $policy},
          {icon: "󰍡", label: "Reglas allow", detail: "Definidas en /etc/ufw", value: $rules}
        ]')"
      ;;
    nftables|iptables)
      active="$(systemctl is-active "${backend}.service" 2>/dev/null || true)"
      [[ -n "$active" ]] || active="inactive"

      if [[ "$active" == "active" ]]; then
        class="active"; label="ON"; subtitle="$backend activo"
      else
        class="inactive"; label="OFF"; subtitle="$backend inactivo"
      fi

      rows_json="$(jq -cn --arg backend "$backend" --arg active "$active" '[
        {icon: "󰩠", label: "Backend", detail: "Gestor de firewall", value: $backend},
        {icon: "󰄲", label: "Servicio", detail: "systemd", value: $active}
      ]')"
      ;;
    *)
      class="unknown"; label="N/A"
      subtitle="No se detectó ufw, nftables ni iptables"
      rows_json='[]'
      ;;
  esac

  actions_json="$(jq -cn \
    --arg notify_cmd '$HOME/.config/omarchy/bar/scripts/firewall-status.sh notify' \
    '[{icon: "󰍡", label: "Ver detalle", command: $notify_cmd}]')"

  jq -cn \
    --arg text "$ICON $label" \
    --arg class "$class" \
    --arg tooltip "$subtitle" \
    --arg subtitle "$subtitle" \
    --arg headline "$label" \
    --argjson rows "$rows_json" \
    --argjson actions "$actions_json" \
    '{
      text: $text,
      class: $class,
      tooltip: $tooltip,
      panel: {
        icon: "󰄲",
        title: "Firewall",
        subtitle: $subtitle,
        headline: $headline,
        sectionTitle: "ESTADO",
        actionsTitle: "ACCIONES",
        rows: $rows,
        actions: $actions
      }
    }'
}

notify_status() {
  local out subtitle
  out="$(json_status)"
  subtitle="$(jq -r '.panel.subtitle' <<< "$out")"
  notify-send -u low "Firewall" "$subtitle"
}

case "${1:-print}" in
  print) json_status ;;
  notify) notify_status ;;
  *)
    echo "Usage: $0 {print|notify}" >&2
    exit 2
    ;;
esac
