#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${WEATHER_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/waybar/weather}"
CITY_FILE="$STATE_DIR/city"
LOCK_FILE="$STATE_DIR/lock"
SIGNAL=14
DEFAULT_CITY="${WEATHER_DEFAULT_CITY:-cartagena}"

weather_data=""
weather_cached="false"

CITY_KEYS=(
  arica iquique antofagasta calama copiapo la_serena coquimbo cartagena
  valparaiso vina_del_mar santiago rancagua talca chillan concepcion
  temuco valdivia osorno puerto_montt coyhaique punta_arenas
)

CITY_LABELS=(
  "Arica" "Iquique" "Antofagasta" "Calama" "Copiapó" "La Serena"
  "Coquimbo" "Cartagena, Valparaíso" "Valparaíso" "Viña del Mar"
  "Santiago" "Rancagua" "Talca" "Chillán" "Concepción" "Temuco"
  "Valdivia" "Osorno" "Puerto Montt" "Coyhaique" "Punta Arenas"
)

CITY_SEARCH_NAMES=(
  "Arica" "Iquique" "Antofagasta" "Calama" "Copiapó" "La Serena"
  "Coquimbo" "Cartagena" "Valparaíso" "Viña del Mar" "Santiago"
  "Rancagua" "Talca" "Chillán" "Concepción" "Temuco" "Valdivia"
  "Osorno" "Puerto Montt" "Coyhaique" "Punta Arenas"
)

valid_city() {
  local candidate="$1"
  local key

  for key in "${CITY_KEYS[@]}"; do
    [[ "$key" == "$candidate" ]] && return 0
  done
  return 1
}

apply_city() {
  local index

  for index in "${!CITY_KEYS[@]}"; do
    if [[ "${CITY_KEYS[$index]}" == "$city" ]]; then
      CITY_LABEL="${CITY_LABELS[$index]}"
      CITY_SEARCH_NAME="${CITY_SEARCH_NAMES[$index]}"
      CACHE_FILE="$STATE_DIR/$city.json"
      COORDINATES_FILE="$STATE_DIR/$city.coords"
      return 0
    fi
  done
  return 2
}

load_city() {
  local saved=""

  if [[ -s "$CITY_FILE" ]]; then
    IFS= read -r saved < "$CITY_FILE" || true
  fi

  if valid_city "$saved"; then
    city="$saved"
  elif valid_city "$DEFAULT_CITY"; then
    city="$DEFAULT_CITY"
  else
    city="cartagena"
  fi
  apply_city
}

refresh_waybar() {
  [[ "${WEATHER_DISABLE_SIGNAL:-false}" == "true" ]] || \
    pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
}

write_city() {
  local temporary

  temporary="$(mktemp "$STATE_DIR/city.XXXXXX")"
  printf '%s\n' "$city" > "$temporary"
  mv -f "$temporary" "$CITY_FILE"
}

set_city() {
  local selected="$1"

  valid_city "$selected" || return 2
  city="$selected"
  apply_city
  write_city
  refresh_waybar
}

toggle_city() {
  if [[ "$city" == "cartagena" ]]; then
    set_city valparaiso
  else
    set_city cartagena
  fi
}

city_menu() {
  local choice
  local index

  choice="$(
    omarchy menu select \
      "Ciudad del clima" \
      "${CITY_LABELS[@]}" || true
  )"

  for index in "${!CITY_LABELS[@]}"; do
    if [[ "${CITY_LABELS[$index]}" == "$choice" ]]; then
      set_city "${CITY_KEYS[$index]}"
      return
    fi
  done
}

valid_weather_json() {
  jq -e '
    (.current.weather_code // "") != "" and
    (.current.temperature_2m // "") != "" and
    (.current.apparent_temperature // "") != "" and
    (.current.relative_humidity_2m // "") != "" and
    (.current.wind_speed_10m // "") != "" and
    (.current.wind_direction_10m // "") != "" and
    (.current.surface_pressure // "") != "" and
    (.current.visibility // "") != "" and
    (.current.is_day // "") != "" and
    (.daily.time | length) >= 8 and
    (.daily.weather_code | length) >= 8 and
    (.daily.temperature_2m_max | length) >= 8 and
    (.daily.temperature_2m_min | length) >= 8 and
    (.daily.precipitation_probability_max | length) >= 8 and
    (.daily.sunrise | length) >= 1 and
    (.daily.sunset | length) >= 1
  ' >/dev/null 2>&1
}

valid_coordinates() {
  local latitude="$1"
  local longitude="$2"
  local timezone="$3"

  [[ "$latitude" =~ ^-?[0-9]+([.][0-9]+)?$ ]] &&
    [[ "$longitude" =~ ^-?[0-9]+([.][0-9]+)?$ ]] &&
    [[ -n "$timezone" ]]
}

load_coordinates() {
  local values="" response="" temporary

  if [[ -n "${WEATHER_FIXTURE_FILE:-}" ]]; then
    LATITUDE="0"
    LONGITUDE="0"
    WEATHER_TIMEZONE="America/Santiago"
    return 0
  fi

  if [[ -s "$COORDINATES_FILE" ]]; then
    IFS=$'\t' read -r LATITUDE LONGITUDE WEATHER_TIMEZONE < "$COORDINATES_FILE" || true
    if valid_coordinates "${LATITUDE:-}" "${LONGITUDE:-}" "${WEATHER_TIMEZONE:-}"; then
      return 0
    fi
  fi

  response="$(
    curl -fsS --max-time 5 --get \
      --data-urlencode "name=$CITY_SEARCH_NAME" \
      --data-urlencode "count=5" \
      --data-urlencode "language=es" \
      --data-urlencode "format=json" \
      --data-urlencode "countryCode=CL" \
      "https://geocoding-api.open-meteo.com/v1/search" 2>/dev/null || true
  )"
  values="$(
    jq -er '
      [(.results // [])[] | select(
        .country_code == "CL" and
        (.latitude | type == "number") and
        (.longitude | type == "number") and
        (.timezone | type == "string")
      )][0] | [.latitude, .longitude, .timezone] | @tsv
    ' <<< "$response" 2>/dev/null || true
  )"
  [[ -n "$values" ]] || return 1
  IFS=$'\t' read -r LATITUDE LONGITUDE WEATHER_TIMEZONE <<< "$values"
  valid_coordinates "$LATITUDE" "$LONGITUDE" "$WEATHER_TIMEZONE" || return 1

  temporary="$(mktemp "$STATE_DIR/$city.coords.XXXXXX")"
  printf '%s\t%s\t%s\n' "$LATITUDE" "$LONGITUDE" "$WEATHER_TIMEZONE" > "$temporary"
  mv -f "$temporary" "$COORDINATES_FILE"
}

fetch_weather() {
  if [[ -n "${WEATHER_FIXTURE_FILE:-}" ]]; then
    command cat "$WEATHER_FIXTURE_FILE"
  else
    curl -fsS --max-time 8 --get \
      --data-urlencode "latitude=$LATITUDE" \
      --data-urlencode "longitude=$LONGITUDE" \
      --data-urlencode "current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,visibility,is_day" \
      --data-urlencode "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max" \
      --data-urlencode "timezone=$WEATHER_TIMEZONE" \
      --data-urlencode "forecast_days=8" \
      "https://api.open-meteo.com/v1/forecast" 2>/dev/null
  fi
}

cache_weather() {
  local temporary

  temporary="$(mktemp "$STATE_DIR/$city.XXXXXX")"
  printf '%s\n' "$weather_data" > "$temporary"
  mv -f "$temporary" "$CACHE_FILE"
}

load_weather() {
  local response=""

  load_coordinates || return 1
  response="$(fetch_weather || true)"
  if [[ -n "$response" ]] && valid_weather_json <<< "$response"; then
    weather_data="$response"
    weather_cached="false"
    cache_weather
    return 0
  fi

  if [[ -s "$CACHE_FILE" ]] && valid_weather_json < "$CACHE_FILE"; then
    weather_data="$(<"$CACHE_FILE")"
    weather_cached="true"
    return 0
  fi

  return 1
}

condition_label() {
  case "$1" in
    0) printf '%s\n' "Despejado" ;;
    1) printf '%s\n' "Mayormente despejado" ;;
    2) printf '%s\n' "Parcialmente nublado" ;;
    3) printf '%s\n' "Nublado" ;;
    45|48) printf '%s\n' "Niebla" ;;
    51|53|55) printf '%s\n' "Llovizna" ;;
    56|57) printf '%s\n' "Llovizna helada" ;;
    61|63|65) printf '%s\n' "Lluvia" ;;
    66|67) printf '%s\n' "Lluvia helada" ;;
    71|73|75|77) printf '%s\n' "Nieve" ;;
    80|81|82) printf '%s\n' "Chubascos" ;;
    85|86) printf '%s\n' "Chubascos de nieve" ;;
    95|96|99) printf '%s\n' "Tormenta eléctrica" ;;
    *) printf '%s\n' "Condición variable" ;;
  esac
}

weather_icon() {
  local code="$1"
  local is_day="${2:-1}"

  case "$code" in
    0|1) [[ "$is_day" == "1" ]] && printf '%s\n' "" || printf '%s\n' "" ;;
    2) [[ "$is_day" == "1" ]] && printf '%s\n' "" || printf '%s\n' "" ;;
    3) printf '%s\n' "" ;;
    45|48) printf '%s\n' "" ;;
    51|53|55|80|81) [[ "$is_day" == "1" ]] && printf '%s\n' "" || printf '%s\n' "" ;;
    56|57|66|67) printf '%s\n' "" ;;
    61|63|65|82) printf '%s\n' "" ;;
    71|73|75|77|85|86) [[ "$is_day" == "1" ]] && printf '%s\n' "" || printf '%s\n' "" ;;
    95|96|99) printf '%s\n' "" ;;
    *) printf '%s\n' "" ;;
  esac
}

format_time() {
  date -d "$1" +%H:%M 2>/dev/null || printf '%s\n' "$1"
}

day_label() {
  case "$(date -d "$1" +%u 2>/dev/null || echo 0)" in
    1) printf '%s\n' "Lun" ;;
    2) printf '%s\n' "Mar" ;;
    3) printf '%s\n' "Mié" ;;
    4) printf '%s\n' "Jue" ;;
    5) printf '%s\n' "Vie" ;;
    6) printf '%s\n' "Sáb" ;;
    7) printf '%s\n' "Dom" ;;
    *) printf '%s\n' "---" ;;
  esac
}

wind_direction_label() {
  local degrees="$1"
  local index=$(((degrees + 11) / 22 % 16))
  local directions=(N NNE NE ENE E ESE SE SSE S SSO SO OSO O ONO NO NNO)
  printf '%s\n' "${directions[$index]}"
}

build_forecast() {
  local date code max_temp min_temp rain day condition forecast_icon date_formatted
  forecast=""

  while IFS=$'\t' read -r date code max_temp min_temp rain; do
    day="$(day_label "$date")"
    date_formatted="$(date -d "$date" +%d/%m 2>/dev/null || printf '%s' "$date")"
    condition="$(condition_label "$code")"
    forecast_icon="$(weather_icon "$code" 1)"
    forecast+="${forecast:+$'\n'}$day $date_formatted  $forecast_icon  $condition · ${min_temp}–${max_temp}°C · lluvia ${rain}%"
  done < <(
    jq -r '[
      .daily.time[1:8],
      .daily.weather_code[1:8],
      (.daily.temperature_2m_max[1:8] | map(round)),
      (.daily.temperature_2m_min[1:8] | map(round)),
      .daily.precipitation_probability_max[1:8]
    ] | transpose[] | @tsv' <<< "$weather_data"
  )
}

prepare_status() {
  local values
  local code temp feels humidity wind_speed wind_degrees pressure visibility max_temp min_temp sunrise sunset is_day
  local condition wind_direction sunrise_formatted sunset_formatted cache_note=""

  load_weather || return 1
  values="$(
    jq -er '[
      .current.weather_code,
      (.current.temperature_2m | round),
      (.current.apparent_temperature | round),
      .current.relative_humidity_2m,
      (.current.wind_speed_10m | round),
      (.current.wind_direction_10m | round),
      (.current.surface_pressure | round),
      ((.current.visibility / 1000) | round),
      (.daily.temperature_2m_max[0] | round),
      (.daily.temperature_2m_min[0] | round),
      .daily.sunrise[0],
      .daily.sunset[0],
      .current.is_day
    ] | @tsv' <<< "$weather_data"
  )"
  IFS=$'\t' read -r code temp feels humidity wind_speed wind_degrees pressure visibility max_temp min_temp sunrise sunset is_day <<< "$values"

  icon="$(weather_icon "$code" "$is_day")"
  condition="$(condition_label "$code")"
  wind_direction="$(wind_direction_label "$wind_degrees")"
  sunrise_formatted="$(format_time "$sunrise")"
  sunset_formatted="$(format_time "$sunset")"
  build_forecast
  [[ "$weather_cached" == "false" ]] || cache_note=$'\n⚠ Datos en caché: Open-Meteo no respondió'

  printf -v tooltip \
    '%s, Chile\n%s · %s°C · Sensación %s°C\nMín %s°C · Máx %s°C\nHumedad %s%%\nViento %s · %s km/h\nPresión %s hPa · Visibilidad %s km\nAmanecer %s · Atardecer %s\n\nPronóstico 7 días:\n%s%s\n\nClic: cambiar ciudad\nClic central: notificación\nClic derecho: elegir ciudad' \
    "$CITY_LABEL" "$condition" "$temp" "$feels" "$min_temp" "$max_temp" \
    "$humidity" "$wind_direction" "$wind_speed" "$pressure" "$visibility" \
    "$sunrise_formatted" "$sunset_formatted" "$forecast" "$cache_note"
}

print_status() {
  if prepare_status; then
    if [[ "$weather_cached" == "true" ]]; then
      class="cached"
    else
      class="$city"
    fi
    jq -cn --arg text "$icon" --arg class "$class" --arg tooltip "$tooltip" \
      '{text: $text, class: $class, tooltip: $tooltip}'
  else
    jq -cn --arg tooltip "$CITY_LABEL: clima no disponible" \
      '{text: "", class: "unavailable", tooltip: $tooltip}'
  fi
}

notify_status() {
  if prepare_status; then
    notify-send -u low "Clima · $CITY_LABEL" "$tooltip"
  else
    notify-send -u low "Clima" "$CITY_LABEL: clima no disponible"
  fi
}

umask 077
mkdir -p "$STATE_DIR"
exec 9>"$LOCK_FILE"
flock 9
load_city

case "${1:-print}" in
  print) print_status ;;
  toggle) toggle_city ;;
  menu) city_menu ;;
  notify) notify_status ;;
  set) set_city "${2:-}" ;;
  *)
    echo "Usage: $0 {print|toggle|menu|notify|set <city-key>}" >&2
    exit 2
    ;;
esac
