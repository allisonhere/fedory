source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

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

FEDORY_RUN_LOGGED_STEP=${FEDORY_RUN_LOGGED_STEP:-0}
FEDORY_FAILED_LEAVES=()

# Always visible on the real terminal, independent of whether the leaf's own
# output (dnf/flatpak progress, etc.) is streaming live or being captured
# into $FEDORY_INSTALL_LOG_FILE below -- a bootstrap run can have 20+ of
# these leaves, several of which run long dnf/flatpak transactions with no
# other indication of overall progress, so this is what tells the user
# something is still moving forward and roughly what's happening right now.
#
# Deliberately always returns 0: a real bootstrap run showed one leaf
# failing (a handful of base packages unavailable on that specific Fedora
# version) aborted every leaf after it -- hardware setup, login setup,
# post-install, and the entire per-user finalization pass never ran at all,
# over problems in a small fraction of ~115 packages that dnf itself had
# already worked around for everything else via --skip-broken. A failed
# leaf is recorded and reported (see report_failed_leaves, called once
# every leaf has had a chance to run) rather than treated as fatal on the
# spot -- callers that genuinely cannot proceed without a leaf succeeding
# should check for that themselves rather than relying on run_logged to
# abort everything downstream.
run_logged() {
  local script="$1"
  local exit_code errexit_was_set=0
  local label="${script#"${FEDORY_INSTALL:-}"/}"
  label="${label%.sh}"

  FEDORY_RUN_LOGGED_STEP=$((FEDORY_RUN_LOGGED_STEP + 1))
  ui_info "-> [$FEDORY_RUN_LOGGED_STEP] $label"

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
    FEDORY_FAILED_LEAVES+=("$label")
    ui_warn "$label had a problem (exit $exit_code) -- continuing with the rest of setup. Details above, or in \$FEDORY_INSTALL_LOG_FILE."
  fi

  return 0
}

# Call once after every leaf in a phase (config/all.sh, hardware, login,
# post-install, user) has had a chance to run. Prints a summary and returns
# nonzero if anything failed, so the caller (fedory-setup-system,
# fedory-finalize-user) can still signal overall failure to bootstrap.sh --
# but only after everything that *could* run already has.
report_failed_leaves() {
  (( ${#FEDORY_FAILED_LEAVES[@]} > 0 )) || return 0
  ui_warn "${#FEDORY_FAILED_LEAVES[@]} step(s) had problems and were left unfinished: ${FEDORY_FAILED_LEAVES[*]}"
  ui_warn "Setup continued past them. Review the messages above (or \$FEDORY_INSTALL_LOG_FILE), fix what's blocking them, and retry -- e.g. 'fedory pkg add hyprland' once its COPR issue is resolved -- rather than re-running the whole bootstrap."
  return 1
}
