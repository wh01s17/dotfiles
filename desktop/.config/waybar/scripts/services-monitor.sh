#!/usr/bin/env bash
set -euo pipefail

DEV_PORTS="${SERVICES_DEV_PORTS:-3000 3001 4000 4200 5000 5001 5173 5174 5432 6379 8000 8001 8080 8081 8888 9000 9090 9200 9229 27017 3306}"
HTTP_PORTS="${SERVICES_HTTP_PORTS:-3000 3001 4000 4200 5000 5001 5173 5174 8000 8001 8080 8081 8888 9000}"
REVERSE_PORTS="${SERVICES_REVERSE_PORTS:-1234 1337 4444 4445 5555 6666 9001 31337}"

declare -a services=()
declare -a exposed_services=()
declare -a reverse_listeners=()
declare -a reverse_sessions=()
declare -a open_targets=()
declare -a copy_targets=()
declare -A seen_services=()
declare -A seen_reverse=()
declare -A seen_open=()
declare -A seen_copy=()

in_list() {
  local needle="$1"
  local list="$2"
  local item

  for item in $list; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

endpoint_port() {
  printf '%s\n' "${1##*:}"
}

endpoint_host() {
  local host="${1%:*}"
  host="${host#[}"
  host="${host%]}"
  printf '%s\n' "$host"
}

process_name() {
  local details="${1:-}"

  if [[ "$details" =~ \"([^\"]+)\" ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '%s\n' "unknown"
  fi
}

is_loopback() {
  local host="$1"
  [[ "$host" == 127.* || "$host" == "::1" || "$host" == "localhost" ]]
}

is_wildcard() {
  local host="$1"
  [[ "$host" == "0.0.0.0" || "$host" == "::" || "$host" == "*" ]]
}

is_reverse_process() {
  local process="$1"
  [[ "$process" =~ ^(nc|nc\.openbsd|ncat|netcat|socat|rlwrap|pwncat|pwncat-cs|chisel)$ ]]
}

is_shell_process() {
  local process="$1"
  [[ "$process" =~ ^(bash|sh|dash|zsh|fish|nc|nc\.openbsd|ncat|netcat|socat|rlwrap|pwncat|pwncat-cs)$ ]]
}

is_dev_process() {
  local process="$1"
  [[ "$process" =~ ^(node|bun|deno|vite|next-server|python|python3|php|ruby|rails|java|uvicorn|gunicorn|caddy|nginx|httpd|docker-proxy|postgres|mysqld|redis-server|mongod)$ ]]
}

browser_host() {
  local host="$1"

  if is_wildcard "$host"; then
    printf '%s\n' "127.0.0.1"
  elif [[ "$host" == *:* ]]; then
    printf '[%s]\n' "$host"
  else
    printf '%s\n' "$host"
  fi
}

read_listeners() {
  if [[ -n "${SERVICES_LISTEN_FILE:-}" ]]; then
    command cat "$SERVICES_LISTEN_FILE"
  else
    ss -H -ltnp 2>/dev/null || true
  fi
}

read_connections() {
  if [[ -n "${SERVICES_ESTABLISHED_FILE:-}" ]]; then
    command cat "$SERVICES_ESTABLISHED_FILE"
  else
    ss -H -tnp state established 2>/dev/null || true
  fi
}

add_copy_target() {
  local target="$1"
  [[ -n "${seen_copy[$target]:-}" ]] && return
  seen_copy["$target"]=1
  copy_targets+=("$target")
}

add_open_target() {
  local target="$1"
  [[ -n "${seen_open[$target]:-}" ]] && return
  seen_open["$target"]=1
  open_targets+=("$target")
}

collect_listeners() {
  local state recvq sendq local_address peer details port host process key record url

  while read -r state recvq sendq local_address peer details; do
    [[ -n "${local_address:-}" ]] || continue
    port="$(endpoint_port "$local_address")"
    [[ "$port" =~ ^[0-9]+$ ]] || continue
    host="$(endpoint_host "$local_address")"
    process="$(process_name "${details:-}")"
    key="$host:$port"
    record="$port|$host|$process"

    if is_reverse_process "$process" || in_list "$port" "$REVERSE_PORTS"; then
      if [[ -z "${seen_reverse[$key]:-}" ]]; then
        seen_reverse["$key"]=1
        reverse_listeners+=("$record")
        add_copy_target "$host:$port"
      fi
      continue
    fi

    if ! in_list "$port" "$DEV_PORTS" && ! is_dev_process "$process"; then
      continue
    fi

    if [[ -z "${seen_services[$key]:-}" ]]; then
      seen_services["$key"]=1
      services+=("$record")
      if ! is_loopback "$host"; then
        exposed_services+=("$record")
      fi

      if in_list "$port" "$HTTP_PORTS"; then
        url="http://$(browser_host "$host"):$port"
        add_open_target "$url"
        add_copy_target "$url"
      else
        add_copy_target "$host:$port"
      fi
    fi
  done < <(read_listeners)
}

collect_connections() {
  local recvq sendq local_address peer details local_port peer_port process key record

  while read -r recvq sendq local_address peer details; do
    [[ -n "${peer:-}" ]] || continue
    local_port="$(endpoint_port "$local_address")"
    peer_port="$(endpoint_port "$peer")"
    process="$(process_name "${details:-}")"

    if ! is_reverse_process "$process" && ! in_list "$local_port" "$REVERSE_PORTS" && ! in_list "$peer_port" "$REVERSE_PORTS"; then
      if ! is_shell_process "$process" || in_list "$peer_port" "53 80 443"; then
        continue
      fi
    fi

    key="$local_address->$peer"
    [[ -n "${seen_reverse[$key]:-}" ]] && continue
    seen_reverse["$key"]=1
    record="$peer_port|$peer|$process|$local_address"
    reverse_sessions+=("$record")
    add_copy_target "$peer"
  done < <(read_connections)
}

collect() {
  collect_listeners
  collect_connections
}

ports_preview() {
  local array_name="$1"
  local -n records="$array_name"
  local -a ports=()
  local record port existing joined=""
  local count=0

  for record in "${records[@]}"; do
    port="${record%%|*}"
    existing=" false "
    [[ " ${ports[*]:-} " == *" $port "* ]] && existing=" true "
    [[ "$existing" == " true " ]] && continue
    ports+=("$port")
    ((count += 1))
    if ((count <= 3)); then
      joined+="${joined:+,}$port"
    fi
  done

  if ((${#ports[@]} > 3)); then
    joined+="+$((${#ports[@]} - 3))"
  fi
  printf '%s\n' "$joined"
}

build_tooltip() {
  local tooltip=""
  local record port host process local_address exposure

  if ((${#services[@]})); then
    tooltip+="Servicios locales:"
    tooltip+=$'\n'
    for record in "${services[@]}"; do
      IFS='|' read -r port host process <<< "$record"
      if is_loopback "$host"; then
        exposure="solo localhost"
      else
        exposure="EXPUESTO en $host"
      fi
      tooltip+="• $process · $host:$port · $exposure"
      tooltip+=$'\n'
    done
  fi

  if ((${#reverse_listeners[@]})); then
    [[ -z "$tooltip" ]] || tooltip+=$'\n'
    tooltip+="Listeners de reverse shell (heurística):"
    tooltip+=$'\n'
    for record in "${reverse_listeners[@]}"; do
      IFS='|' read -r port host process <<< "$record"
      tooltip+="• $process · $host:$port"
      tooltip+=$'\n'
    done
  fi

  if ((${#reverse_sessions[@]})); then
    [[ -z "$tooltip" ]] || tooltip+=$'\n'
    tooltip+="Sesiones probables:"
    tooltip+=$'\n'
    for record in "${reverse_sessions[@]}"; do
      IFS='|' read -r port host process local_address <<< "$record"
      tooltip+="• $process · $local_address → $host"
      tooltip+=$'\n'
    done
  fi

  if [[ -z "$tooltip" ]]; then
    tooltip="Sin servicios de desarrollo ni reverse shells detectados"
  else
    tooltip="${tooltip%$'\n'}"
    tooltip+=$'\n\nClic: abrir servicio web\nClic central: copiar endpoint\nClic derecho: ver resumen'
  fi

  printf '%s\n' "$tooltip"
}

print_status() {
  local text="" class="inactive" tooltip service_ports reverse_ports

  collect
  service_ports="$(ports_preview services)"
  reverse_ports="$(ports_preview reverse_listeners)"

  if [[ -n "$service_ports" ]]; then
    text="󰒍 $service_ports"
    class="active"
  fi

  if [[ -n "$reverse_ports" || ${#reverse_sessions[@]} -gt 0 ]]; then
    text+="${text:+ | }󰆍 ${reverse_ports:-×${#reverse_sessions[@]}}"
    class="reverse"
  elif ((${#exposed_services[@]})); then
    class="exposed"
  fi

  tooltip="$(build_tooltip)"
  jq -cn --arg text "$text" --arg class "$class" --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}'
}

choose() {
  local title="$1"
  local array_name="$2"
  local -n options="$array_name"

  if ((${#options[@]} == 0)); then
    return 1
  elif ((${#options[@]} == 1)); then
    printf '%s\n' "${options[0]}"
  else
    omarchy menu select "$title" "${options[@]}" || true
  fi
}

open_service() {
  local target
  collect
  target="$(choose "Abrir servicio local" open_targets || true)"
  [[ -n "$target" ]] || {
    notify-send -u low "Waybar" "No hay servicios HTTP detectados"
    return
  }
  xdg-open "$target" >/dev/null 2>&1 &
}

copy_endpoint() {
  local target
  collect
  target="$(choose "Copiar endpoint" copy_targets || true)"
  [[ -n "$target" ]] || {
    notify-send -u low "Waybar" "No hay endpoints detectados"
    return
  }
  printf '%s' "$target" | wl-copy
  notify-send -u low "Endpoint copiado" "$target"
}

notify_status() {
  local tooltip
  collect
  tooltip="$(build_tooltip)"
  notify-send -u low "Servicios y reverse shells" "$tooltip"
}

case "${1:-print}" in
  print) print_status ;;
  open) open_service ;;
  copy) copy_endpoint ;;
  notify) notify_status ;;
  *)
    echo "Usage: $0 {print|open|copy|notify}" >&2
    exit 2
    ;;
esac
