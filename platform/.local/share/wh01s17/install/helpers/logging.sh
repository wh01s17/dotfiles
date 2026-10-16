wh01s17_log_to_stdout() {
  [[ ${WH01S17_LOG_TO_STDOUT:-} == "1" || -z ${WH01S17_INSTALL_LOG_FILE:-} ]]
}

wh01s17_log_line() {
  if wh01s17_log_to_stdout; then
    echo "$1"
  else
    echo "$1" >>"$WH01S17_INSTALL_LOG_FILE"
  fi
}

start_install_log() {
  if ! wh01s17_log_to_stdout; then
    mkdir -p "$(dirname "$WH01S17_INSTALL_LOG_FILE")"
    touch "$WH01S17_INSTALL_LOG_FILE"
    chmod 666 "$WH01S17_INSTALL_LOG_FILE" 2>/dev/null || true
  fi

  export WH01S17_START_TIME="${WH01S17_START_TIME:-$(date '+%Y-%m-%d %H:%M:%S')}"
  export WH01S17_START_EPOCH="${WH01S17_START_EPOCH:-$(date +%s)}"

  wh01s17_log_line "=== wh01s17 Setup Started: $WH01S17_START_TIME ==="
}

stop_install_log() {
  local end_time end_epoch duration mins secs
  end_time=$(date '+%Y-%m-%d %H:%M:%S')
  end_epoch=$(date +%s)

  wh01s17_log_line "=== wh01s17 Setup Completed: $end_time ==="

  if [[ -n ${WH01S17_START_EPOCH:-} ]]; then
    duration=$((end_epoch - WH01S17_START_EPOCH))
    mins=$((duration / 60))
    secs=$((duration % 60))
    wh01s17_log_line "wh01s17 setup: ${mins}m ${secs}s"
  fi
}

run_logged() {
  local script="$1"
  local exit_code errexit_was_set=0

  wh01s17_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  local runner=(bash -eE)
  if [[ ${WH01S17_INSTALL_DEBUG:-} == "1" ]]; then
    runner=(bash -x -eE)
  fi

  if wh01s17_log_to_stdout; then
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null 2>&1
  else
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null >>"$WH01S17_INSTALL_LOG_FILE" 2>&1
  fi

  exit_code=$?
  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    wh01s17_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script"
  else
    wh01s17_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)"
  fi

  return $exit_code
}
