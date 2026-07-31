fedory_log_to_stdout() {
  [[ ${FEDORY_LOG_TO_STDOUT:-} == "1" || -z ${FEDORY_INSTALL_LOG_FILE:-} ]]
}

fedory_log_line() {
  if fedory_log_to_stdout; then
    echo "$1"
  else
    echo "$1" >>"$FEDORY_INSTALL_LOG_FILE"
  fi
}

start_install_log() {
  if ! fedory_log_to_stdout; then
    mkdir -p "$(dirname "$FEDORY_INSTALL_LOG_FILE")"
    touch "$FEDORY_INSTALL_LOG_FILE"
    chmod 666 "$FEDORY_INSTALL_LOG_FILE" 2>/dev/null || true
  fi

  export FEDORY_START_TIME="${FEDORY_START_TIME:-$(date '+%Y-%m-%d %H:%M:%S')}"
  export FEDORY_START_EPOCH="${FEDORY_START_EPOCH:-$(date +%s)}"

  fedory_log_line "=== Fedory Setup Started: $FEDORY_START_TIME ==="
}

stop_install_log() {
  local end_time end_epoch duration mins secs
  end_time=$(date '+%Y-%m-%d %H:%M:%S')
  end_epoch=$(date +%s)

  fedory_log_line "=== Fedory Setup Completed: $end_time ==="

  if [[ -n ${FEDORY_START_EPOCH:-} ]]; then
    duration=$((end_epoch - FEDORY_START_EPOCH))
    mins=$((duration / 60))
    secs=$((duration % 60))
    fedory_log_line "Fedory setup: ${mins}m ${secs}s"
  fi
}

run_logged() {
  local script="$1"
  local exit_code errexit_was_set=0

  fedory_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  local runner=(bash -eE)
  if [[ ${FEDORY_INSTALL_DEBUG:-} == "1" ]]; then
    runner=(bash -x -eE)
  fi

  if fedory_log_to_stdout; then
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null 2>&1
  else
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null >>"$FEDORY_INSTALL_LOG_FILE" 2>&1
  fi

  exit_code=$?
  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    fedory_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script"
  else
    fedory_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)"
  fi

  return $exit_code
}
