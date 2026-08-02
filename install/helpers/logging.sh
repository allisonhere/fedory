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
    config/plymouth.sh) echo "Set up the boot splash"; return ;;
    config/grub.sh) echo "Brand the boot menu"; return ;;
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

# Which tasks get the extra third progress row, and what to title it.
# Long-running leaves that emit meaningful activity text deserve it; short
# ones would just add a line that flickers past. Returning empty means "no
# activity row for this task".
#
# fedory_render_progress and fedory_watch_progress must agree on this, because
# the row changes how many terminal lines each redraw has to move back over --
# disagreement leaves the cursor in the wrong place and the bars overwrite
# surrounding output. Hence one predicate rather than a condition repeated in
# both.
fedory_task_activity_label() {
  case $1 in
    "Install core desktop packages") echo "PACKAGE" ;;
    "Set up the boot splash") echo "STEP" ;;
    "Brand the boot menu") echo "STEP" ;;
  esac
}

fedory_task_notice() {
  local script=$1 relative
  relative=${script#"${FEDORY_INSTALL:-}"/}

  case $relative in
    config/base-packages.sh)
      echo "This is the longest install step and may take several minutes on a fresh system. Keep this terminal open."
      ;;
    config/plymouth.sh)
      echo "Rebuilding the initramfs for the boot splash. dracut is quiet while it works, so expect this step to sit at its last message for a minute."
      ;;
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

# Block-drawing bars need a UTF-8 locale to render as anything but mojibake.
# bootstrap.sh can run from a plain VT during recovery, so fall back to the
# original ASCII bars rather than assuming. FEDORY_PROGRESS_ASCII=1 forces the
# fallback for anyone who prefers it (or for a terminal that lies about UTF-8).
fedory_progress_unicode() {
  [[ ${FEDORY_PROGRESS_ASCII:-0} != 1 ]] || return 1
  local encoding=${LC_ALL:-${LC_CTYPE:-${LANG:-}}}
  [[ ${encoding,,} == *utf-8* || ${encoding,,} == *utf8* ]]
}

# Cool-to-warm ramp walked left to right across a filled bar: indigo at the
# start, magenta by the end, so a bar's colour alone reads as "how far along".
FEDORY_PROGRESS_RAMP=(61 62 63 99 135 171 207)
FEDORY_PROGRESS_TRACK=236

fedory_progress_bar() {
  local current=${1:-0} total=${2:-0} width=${3:-24}
  local filled empty bar

  (( total > 0 )) || total=1
  (( current < 0 )) && current=0
  (( current > total )) && current=$total
  (( width > 0 )) || width=1

  if ! fedory_progress_unicode; then
    filled=$((current * width / total))
    empty=$((width - filled))
    printf -v bar '%*s' "$filled" ''
    printf '%s' "${bar// /#}"
    printf -v bar '%*s' "$empty" ''
    printf '%s' "${bar// /-}"
    return
  fi

  # Track progress in eighths of a cell so the bar advances smoothly instead
  # of jumping a whole character at a time -- on a 24-cell bar that is 8x the
  # resolution, which is the difference between "moving" and "stuck".
  local partials=('▏' '▎' '▍' '▌' '▋' '▊' '▉')
  local esc=$'\033' out="" i idx
  local eighths=$((current * width * 8 / total))
  local full=$((eighths / 8)) part=$((eighths % 8))
  local ramp_len=${#FEDORY_PROGRESS_RAMP[@]}

  (( full > width )) && full=$width
  for (( i = 0; i < full; i++ )); do
    idx=$((i * ramp_len / width))
    out+="${esc}[38;5;${FEDORY_PROGRESS_RAMP[idx]}m█"
  done
  if (( full < width && part > 0 )); then
    idx=$((full * ramp_len / width))
    out+="${esc}[38;5;${FEDORY_PROGRESS_RAMP[idx]}m${partials[part - 1]}"
    full=$((full + 1))
  fi
  for (( i = full; i < width; i++ )); do
    out+="${esc}[38;5;${FEDORY_PROGRESS_TRACK}m░"
  done

  printf '%s%s[0m' "$out" "$esc"
}

fedory_activity_bar() {
  local tick=${1:-0} width=${2:-24} segment=5 position direction bar

  (( width > 0 )) || width=1
  (( segment > width )) && segment=$width
  if (( width == segment )); then
    position=0
  else
    direction=$((tick % (2 * (width - segment))))
    if (( direction > width - segment )); then
      position=$((2 * (width - segment) - direction))
    else
      position=$direction
    fi
  fi

  if ! fedory_progress_unicode; then
    printf -v bar '%*s' "$position" ''
    printf '%s' "${bar// /-}"
    printf -v bar '%*s' "$segment" ''
    printf '%s' "${bar// /#}"
    printf -v bar '%*s' "$((width - position - segment))" ''
    printf '%s' "${bar// /-}"
    return
  fi

  # A comet rather than a sliding block: a bright head with a trail that fades
  # out behind it, flipping ends when the sweep reverses. The head is what the
  # eye tracks, so it has to lead in the direction of travel -- a symmetric
  # blob gives no sense of motion at all on a slow step like dracut.
  local esc=$'\033' out="" i offset distance moving_right=1
  local glyphs=('█' '▓' '▒' '░')
  local trail=(207 171 135 99)

  (( direction > width - segment )) && moving_right=0

  for (( i = 0; i < width; i++ )); do
    if (( i < position || i >= position + segment )); then
      out+="${esc}[38;5;${FEDORY_PROGRESS_TRACK}m░"
      continue
    fi
    offset=$((i - position))
    if (( moving_right )); then
      distance=$((segment - 1 - offset))
    else
      distance=$offset
    fi
    (( distance > 3 )) && distance=3
    out+="${esc}[38;5;${trail[distance]}m${glyphs[distance]}"
  done

  printf '%s%s[0m' "$out" "$esc"
}

fedory_task_progress() {
  local task_log=$1 clean rest current="" total="" activity=""

  [[ -s $task_log ]] || return 0
  while IFS= read -r clean; do
    clean=${clean//$'\r'/}
    [[ -n ${clean//[[:space:]]/} ]] || continue

    if [[ $clean =~ \[[[:space:]]*([0-9]+)/([0-9]+)\] ]]; then
      current=${BASH_REMATCH[1]}
      total=${BASH_REMATCH[2]}
      rest=${clean#*]}
      rest=${rest#"${rest%%[![:space:]]*}"}
      rest=${rest%%100%*}
      rest=${rest%"${rest##*[![:space:]]}"}
      if [[ -n $rest ]]; then
        activity=${rest//|/ }
      fi
    elif [[ $clean =~ (^|[[:space:]])([0-9]+)/([0-9]+)([[:space:]]|$) ]]; then
      current=${BASH_REMATCH[2]}
      total=${BASH_REMATCH[3]}
    elif [[ $clean =~ ^[[:space:]]*(Installing|Downloading|Running[[:space:]]transaction|Preparing[[:space:]]transaction|Verifying)([[:space:]]|$) ]]; then
      activity=${clean#"${clean%%[![:space:]]*}"}
    fi
  done < <(tail -n 80 "$task_log" | tr '\r' '\n' \
    | sed $'s/\033\\[[0-9;?]*[[:alpha:]]//g')

  activity=${activity//$'\t'/ }
  activity=${activity//|/ }
  printf '%s|%s|%s\n' "$current" "$total" "$activity"
}

fedory_progress_ui_enabled() {
  [[ ${FEDORY_PROGRESS_UI:-auto} == "always" ]] || {
    [[ ${FEDORY_PROGRESS_UI:-auto} != "never" && -t 1 ]]
  }
}

fedory_render_progress() {
  local progress_current=$1 progress_total=$2 display_label=$3 task_log=$4
  local started_at=$5 tick=$6
  local width=${FEDORY_PROGRESS_BAR_WIDTH:-24}
  local columns label_width now elapsed task_current task_total snapshot
  local task_activity show_activity=0 activity_width fitted_activity activity_text
  local current_bar current_text overall_current overall_bar overall_text fitted_label
  local activity_prefix

  snapshot=$(fedory_task_progress "$task_log")
  IFS='|' read -r task_current task_total task_activity <<<"$snapshot"
  activity_prefix=$(fedory_task_activity_label "$display_label")
  [[ -n $activity_prefix ]] && show_activity=1
  now=$(date +%s)
  elapsed=$((now - started_at))

  if [[ ${FEDORY_PROGRESS_COLUMNS:-} =~ ^[0-9]+$ ]]; then
    columns=$FEDORY_PROGRESS_COLUMNS
  elif columns=$(tput cols 2>/dev/null) && [[ $columns =~ ^[0-9]+$ ]]; then
    :
  else
    columns=${COLUMNS:-80}
  fi
  [[ $columns =~ ^[0-9]+$ ]] || columns=80
  (( columns < width + 39 )) && width=$((columns - 39))
  (( width < 8 )) && width=8
  label_width=$((columns - width - 31))
  (( label_width < 8 )) && label_width=8
  if (( ${#display_label} > label_width )); then
    fitted_label="${display_label:0:label_width-3}..."
  else
    fitted_label=$display_label
  fi

  overall_current=$((progress_current > 0 ? progress_current - 1 : 0))
  overall_bar=$(fedory_progress_bar "$overall_current" "$progress_total" "$width")
  # The bars emit their own per-cell colour and end with a reset, so each line
  # re-asserts its own colour after the bar or the trailing counts render bare.
  overall_text=$(printf 'TOTAL    [%s\033[38;5;63m] %02d/%02d' \
    "$overall_bar" "$overall_current" "$progress_total")

  if [[ $task_current =~ ^[0-9]+$ && $task_total =~ ^[0-9]+$ ]] \
    && (( task_total > 0 && task_current >= task_total )); then
    current_bar=$(fedory_activity_bar "$tick" "$width")
    current_text=$(printf 'CURRENT  [%s\033[38;5;252m] finishing %02d:%02d  %s' \
      "$current_bar" "$((elapsed / 60))" "$((elapsed % 60))" "$fitted_label")
  elif [[ $task_current =~ ^[0-9]+$ && $task_total =~ ^[0-9]+$ ]] && (( task_total > 0 )); then
    current_bar=$(fedory_progress_bar "$task_current" "$task_total" "$width")
    current_text=$(printf 'CURRENT  [%s\033[38;5;252m] %s/%s  %s' \
      "$current_bar" "$task_current" "$task_total" "$fitted_label")
  else
    current_bar=$(fedory_activity_bar "$tick" "$width")
    current_text=$(printf 'CURRENT  [%s\033[38;5;252m] %02d:%02d  %s' \
      "$current_bar" "$((elapsed / 60))" "$((elapsed % 60))" "$fitted_label")
  fi

  if (( show_activity )); then
    if [[ -z $task_activity ]]; then
      case $activity_prefix in
        PACKAGE) task_activity="Resolving package transaction..." ;;
        *) task_activity="Working..." ;;
      esac
    fi
    activity_width=$((columns - 23))
    (( activity_width < 8 )) && activity_width=8
    if (( ${#task_activity} > activity_width )); then
      fitted_activity="${task_activity:0:activity_width-3}..."
    else
      fitted_activity=$task_activity
    fi
    # %-7s keeps the row aligned with the bars above it regardless of which
    # prefix a task uses; "PACKAGE" is the widest and sets the column.
    activity_text=$(printf '%-7s  %-*s  %02d:%02d' \
      "$activity_prefix" "$activity_width" "$fitted_activity" \
      "$((elapsed / 60))" "$((elapsed % 60))")
  fi

  if (( tick > 0 )); then
    if (( show_activity )); then
      printf '\r\033[2A'
    else
      printf '\r\033[1A'
    fi
  fi
  printf '\r\033[2K\033[38;5;63m%s\033[0m\n' "$overall_text"
  printf '\r\033[2K\033[38;5;252m%s\033[0m' "$current_text"
  if (( show_activity )); then
    printf '\n\r\033[2K\033[38;5;245m%s\033[0m' "$activity_text"
  fi
}

fedory_watch_progress() {
  local runner_pid=$1 progress_current=$2 progress_total=$3
  local display_label=$4 task_log=$5
  local interval=${FEDORY_PROGRESS_INTERVAL:-0.2} started_at tick=0

  started_at=$(date +%s)
  fedory_render_progress "$progress_current" "$progress_total" \
    "$display_label" "$task_log" "$started_at" "$tick"
  while kill -0 "$runner_pid" 2>/dev/null; do
    sleep "$interval"
    tick=$((tick + 1))
    fedory_render_progress "$progress_current" "$progress_total" \
      "$display_label" "$task_log" "$started_at" "$tick"
  done
  # Must match fedory_render_progress's activity-row decision exactly, or the
  # cursor ends up a line off and the bars smear into later output.
  if [[ -n $(fedory_task_activity_label "$display_label") ]]; then
    printf '\r\033[2K\033[1A\r\033[2K\033[1A\r\033[2K'
  else
    printf '\r\033[2K\033[1A\r\033[2K'
  fi
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
  local display_label progress_current progress_label task_log runner_pid task_notice
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
  task_notice=$(fedory_task_notice "$script")
  [[ -z $task_notice ]] || ui_warn "$task_notice"

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
  elif fedory_progress_ui_enabled; then
    task_log=$(mktemp "${FEDORY_PROGRESS_DIR:-${TMPDIR:-/tmp}}/task.XXXXXX")
    (
      set -o pipefail
      PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
        "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null 2>&1 \
        | tee -a "$FEDORY_INSTALL_LOG_FILE" "$task_log" >/dev/null
    ) &
    runner_pid=$!
    fedory_watch_progress "$runner_pid" "$progress_current" \
      "${FEDORY_PROGRESS_TOTAL:-$progress_current}" "$display_label" "$task_log"
    wait "$runner_pid"
    exit_code=$?
    rm -f "$task_log"
    (( errexit_was_set )) && set -e
  else
    ui_info "$progress_label"
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null >>"$FEDORY_INSTALL_LOG_FILE" 2>&1
  fi

  exit_code=${exit_code:-$?}
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
