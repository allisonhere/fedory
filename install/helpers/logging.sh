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

fedory_task_label() {
  local script=$1 relative section name word label=""
  relative=${script#"${FEDORY_INSTALL:-}"/}

  case $relative in
    config/base-packages.sh) echo "Install core desktop packages"; return ;;
    config/xdg-terminal-exec.sh) echo "Configure the default terminal"; return ;;
    config/theme-system.sh) echo "Apply the system theme"; return ;;
    config/enable-services.sh) echo "Enable desktop services"; return ;;
    config/firewall.sh) echo "Configure the firewall"; return ;;
    login/sddm.sh) echo "Configure the Fedory login screen"; return ;;
    post-install/dnf.sh) echo "Refresh package metadata"; return ;;
    post-install/udev.sh) echo "Reload device rules"; return ;;
    post-install/localdb.sh) echo "Refresh system databases"; return ;;
    user/config-seed.sh) echo "Seed your desktop configuration"; return ;;
    user/theme.sh) echo "Apply your desktop theme"; return ;;
    user/chromium.sh) echo "Configure the web browser"; return ;;
    user/git.sh) echo "Configure Git"; return ;;
    user/xcompose.sh) echo "Configure keyboard compose shortcuts"; return ;;
    user/mise-install.sh) echo "Install development runtimes"; return ;;
    user/mise-work.sh) echo "Prepare the projects directory"; return ;;
    user/default-keyring.sh) echo "Configure the login keyring"; return ;;
  esac

  section=${relative%%/*}
  name=${relative##*/}
  name=${name%.sh}
  name=${name//-/ }
  for word in $name; do
    label+="${word^} "
  done
  label=${label% }

  case $section in
    hardware) printf 'Hardware / %s\n' "$label" ;;
    user) printf 'User / %s\n' "$label" ;;
    config) printf 'System / %s\n' "$label" ;;
    *) printf '%s\n' "$label" ;;
  esac
}

fedory_progress_advance() {
  local current=$FEDORY_RUN_LOGGED_STEP

  if [[ -n ${FEDORY_PROGRESS_FILE:-} && -f $FEDORY_PROGRESS_FILE ]]; then
    read -r current <"$FEDORY_PROGRESS_FILE" || current=0
    [[ $current =~ ^[0-9]+$ ]] || current=0
    current=$((current + 1))
    if ! printf '%s\n' "$current" 2>/dev/null >"$FEDORY_PROGRESS_FILE"; then
      # Progress is presentation only. A stale or unexpectedly protected
      # counter must never interrupt package, hardware, or login setup.
      current=$FEDORY_RUN_LOGGED_STEP
    fi
  fi

  printf '%s\n' "$current"
}

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
  local display_label progress_current progress_label
  label="${label%.sh}"

  FEDORY_RUN_LOGGED_STEP=$((FEDORY_RUN_LOGGED_STEP + 1))
  display_label=$(fedory_task_label "$script")
  progress_current=$(fedory_progress_advance)
  if [[ -n ${FEDORY_PROGRESS_TOTAL:-} ]]; then
    progress_label=$(printf '[%02d/%02d] %s' \
      "$progress_current" "$FEDORY_PROGRESS_TOTAL" "$display_label")
  else
    progress_label=$(printf '[%02d] %s' "$progress_current" "$display_label")
  fi

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
  elif has_gum; then
    gum spin --spinner dot --spinner.foreground 63 \
      --title.foreground 252 --title "$progress_label" -- \
      bash -c '
        log_file=$1
        shift
        PS4="+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: " \
          "$@" </dev/null >>"$log_file" 2>&1
      ' bash "$FEDORY_INSTALL_LOG_FILE" \
      "${runner[@]}" -c 'source "$1"' bash "$script"
  else
    ui_info "$progress_label"
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null >>"$FEDORY_INSTALL_LOG_FILE" 2>&1
  fi

  exit_code=$?
  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    fedory_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script"
    ui_task_success "$progress_label"
  else
    fedory_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)"
    FEDORY_FAILED_LEAVES+=("$label")
    ui_task_failure "$progress_label"
    ui_warn "$display_label had a problem (exit $exit_code). Setup will continue; details are in ${FEDORY_INSTALL_LOG_FILE:-the install log}."
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
  ui_warn "Setup continued past them. Review ${FEDORY_INSTALL_LOG_FILE:-the install log}, fix what blocked them, and run the installer again."
  return 1
}
