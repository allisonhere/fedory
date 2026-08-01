#!/bin/bash
# Fedory bootstrap: curl-pipeable entry point for an existing Fedora
# Workstation install. Fedory-invented -- upstream Omarchy no longer has a
# repo-root equivalent post-4.0 ("Quattro"); see docs/scope.md for why.
#
#   curl -fsSL https://raw.githubusercontent.com/allisonhere/fedory/master/bootstrap.sh | bash
#
set -eEo pipefail

FEDORY_REPO="${FEDORY_REPO:-allisonhere/fedory}"
FEDORY_REPO_URL="${FEDORY_REPO_URL:-https://github.com/$FEDORY_REPO.git}"
FEDORY_REF="${FEDORY_REF:-master}"
FEDORY_PATH="${FEDORY_PATH:-$HOME/.local/share/fedory}"

STEP_TOTAL=6
STEP_CURRENT=0
STEP_START_EPOCH=$(date +%s)

# --- output helpers -----------------------------------------------------
# gum isn't installed yet in the first phase, so the initial screen and
# dependency spinner use ANSI when attached to a terminal. Everything after
# that uses gum and retains a readable plain-text fallback.

has_gum() { command -v gum >/dev/null 2>&1; }

ansi() {
  local code=$1
  shift
  if [[ -t 1 ]]; then
    printf '\033[%sm%s\033[0m\n' "$code" "$*"
  else
    printf '%s\n' "$*"
  fi
}

banner() {
  if has_gum; then
    gum style --margin "1 0 0 0" --foreground 63 --bold \
      '    ______ __________  ____  ______  __'
    gum style --foreground 63 --bold \
      '   / ____// ____/ __ \/ __ \/ __ \ \/ /'
    gum style --foreground 63 --bold \
      '  / /_   / __/ / / / / / / /_/ /\  /'
    gum style --foreground 63 --bold \
      ' / __/  / /___/ /_/ / /_/ / _, _/ / /'
    gum style --foreground 63 --bold \
      '/_/    /_____/_____/\____/_/ |_| /_/'
    gum style --margin "1 0" --faint \
      "            FEDORA. REFINED."
  else
    echo
    ansi '1;38;5;63' '    ______ __________  ____  ______  __'
    ansi '1;38;5;63' '   / ____// ____/ __ \/ __ \/ __ \ \/ /'
    ansi '1;38;5;63' '  / /_   / __/ / / / / / / /_/ /\  /'
    ansi '1;38;5;63' ' / __/  / /___/ /_/ / /_/ / _, _/ / /'
    ansi '1;38;5;63' '/_/    /_____/_____/\____/_/ |_| /_/'
    ansi '2' '            FEDORA. REFINED.'
    echo
  fi
}

phase() {
  STEP_CURRENT=$((STEP_CURRENT + 1))
  local title=$1 detail=${2:-}
  if has_gum; then
    echo
    gum style --foreground 245 --bold -- \
      "PHASE $(printf '%02d' "$STEP_CURRENT") / $(printf '%02d' "$STEP_TOTAL")"
    gum style --foreground 63 --bold -- "$title"
    [[ -z $detail ]] || gum style --faint -- "$detail"
  else
    ansi '1;38;5;63' "[$STEP_CURRENT/$STEP_TOTAL] $title"
    [[ -z $detail ]] || info "$detail"
  fi
}

info() {
  if has_gum; then
    gum style --faint -- "$*"
  else
    echo "  $*"
  fi
}

success() {
  if has_gum; then
    gum style --foreground 42 --bold -- "  OK  $*"
  else
    ansi '1;32' "  OK  $*"
  fi
}

run_task() {
  local title=$1 output pid frame=0 status=0
  local frames='|/-\\'
  shift

  if has_gum; then
    gum spin --spinner dot --spinner.foreground 63 \
      --title.foreground 252 --title "$title" --show-error -- "$@"
    status=$?
  else
    output=$(mktemp)
    "$@" >"$output" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r  \033[38;5;63m%s\033[0m  %s' \
        "${frames:frame++%${#frames}:1}" "$title"
      sleep 0.12
    done
    wait "$pid" || status=$?
    printf '\r\033[2K'
    if (( status != 0 )); then
      cat "$output" >&2
    fi
    rm -f "$output"
  fi

  (( status == 0 )) || return "$status"
  success "$title"
}

preflight_card() {
  local host=$1 os=$2 target=$3
  if has_gum; then
    gum style --border rounded --border-foreground 240 --padding "1 2" \
      "INSTALL SUMMARY" \
      "Machine   $host" \
      "System    $os" \
      "User      $USER" \
      "Target    $target"
  else
    ansi '38;5;240' '  +----------------------------------------------------------+'
    ansi '1' '    INSTALL SUMMARY'
    printf '    Machine   %s\n    System    %s\n    User      %s\n    Target    %s\n' \
      "$host" "$os" "$USER" "$target"
    ansi '38;5;240' '  +----------------------------------------------------------+'
  fi
}

die() {
  if has_gum; then
    gum style --foreground 196 --bold -- "Error: $*"
  else
    echo "Error: $*" >&2
  fi
  echo
  echo "Fedory failed partway through. It's safe to re-run this script --" >&2
  echo "steps that already finished are skipped." >&2
  exit 1
}

confirm() {
  local prompt="$1"
  if has_gum; then
    gum confirm -- "$prompt"
  else
    read -r -p "$prompt [y/N] " reply
    [[ $reply =~ ^[Yy]$ ]]
  fi
}

# Everything interactive lives inside main(), called as the very last line of
# this file. When run as `curl | bash`, bash reads this whole file from a
# pipe -- fd 0. A bare top-level `exec </dev/tty` would only be safe once
# nothing else in the file still needs to be *read* from that pipe, but bash
# parses and executes top-level statements incrementally, pulling more bytes
# from fd 0 as needed. Reassign fd 0 too early and every statement after it
# tries to read the *rest of this script* from the terminal instead of the
# pipe, which is what hung: no output, no visible prompt, just silence.
#
# A function body, though, is one compound statement -- bash must read it in
# full (open brace to matching close brace) before it can execute any of it.
# By the time `main "$@"` below runs, this entire file has already been
# consumed from the pipe, so reassigning stdin inside main is safe: there's
# nothing left on fd 0 that bash still needs for parsing.
main() {
  if [[ ! -t 0 ]]; then
    if [[ -r /dev/tty ]]; then
      exec </dev/tty
    else
      echo "Error: fedory bootstrap needs an interactive terminal to ask a couple of questions." >&2
      echo "Run it in a normal terminal session, not from a non-interactive pipe." >&2
      exit 1
    fi
  fi

  trap 'die "unexpected failure at line $LINENO. Log: /var/log/fedory-install.log (if created) or scroll up for the failing command."' ERR

  # --- preflight ------------------------------------------------------------
  banner

  if (( EUID == 0 )); then
    die "Don't run bootstrap.sh as root. Run it as the user who will use this desktop; it will prompt for sudo when it needs it."
  fi

  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    if [[ ${ID:-} != "fedora" && ${ID_LIKE:-} != *fedora* ]]; then
      die "Fedory targets Fedora Workstation. Detected: ${PRETTY_NAME:-unknown OS}."
    fi
  else
    die "Could not read /etc/os-release to confirm this is Fedora."
  fi

  preflight_card "$(hostname)" "${PRETTY_NAME:-Fedora}" "$FEDORY_PATH"
  echo
  info "Usually 15-30 minutes. Completed work is reused if you run it again."
  echo

  if ! confirm "Install Fedory on $(hostname)?"; then
    echo "Cancelled."
    exit 0
  fi

  # --- step 1: bootstrap dependencies ---------------------------------------
  phase "Prepare the installer" "Authenticate once, then install the small bootstrap toolset."
  info "Administrator access is required for system packages and services."
  sudo -v || die "administrator authentication failed"
  run_task "Install Git and the terminal UI" \
    sudo dnf install -y --quiet git gum \
    || die "failed to install git/gum via dnf"

  # From here on, gum is available and every helper uses the styled path.

  # --- step 2: clone the repo -------------------------------------------
  phase "Fetch Fedory" "Download the selected source and prepare its command environment."
  if [[ -d $FEDORY_PATH/.git ]]; then
    run_task "Update the existing $FEDORY_REF checkout" \
      git -C "$FEDORY_PATH" fetch --depth 1 origin "$FEDORY_REF"
    run_task "Select the latest $FEDORY_REF revision" \
      git -C "$FEDORY_PATH" checkout -B "$FEDORY_REF" "origin/$FEDORY_REF"
  else
    mkdir -p "$(dirname "$FEDORY_PATH")"
    run_task "Download Fedory $FEDORY_REF" \
      git clone --quiet --depth 1 --branch "$FEDORY_REF" \
        "$FEDORY_REPO_URL" "$FEDORY_PATH"
  fi
  export FEDORY_PATH
  export PATH="$FEDORY_PATH/bin:$PATH"

  FEDORY_PROGRESS_TOTAL=$(grep -h '^run_logged ' \
    "$FEDORY_PATH"/install/{config,hardware,login,post-install,user}/all.sh \
    | wc -l)
  FEDORY_PROGRESS_TOTAL=${FEDORY_PROGRESS_TOTAL//[[:space:]]/}
  # Keep the shared counter out of sticky /tmp itself. Fedora's
  # fs.protected_regular policy blocks root from truncating a user-owned file
  # there even when it is mode 0666; a private subdirectory is not sticky and
  # remains accessible to both the invoking user and sudo.
  FEDORY_PROGRESS_DIR=$(mktemp -d)
  FEDORY_PROGRESS_FILE="$FEDORY_PROGRESS_DIR/current"
  printf '0\n' >"$FEDORY_PROGRESS_FILE"
  chmod 0666 "$FEDORY_PROGRESS_FILE"
  export FEDORY_PROGRESS_TOTAL FEDORY_PROGRESS_FILE
  trap 'rm -rf "${FEDORY_PROGRESS_DIR:-}"' EXIT

  # --- step 3: collect a little identity info up front ----------------------
  phase "Personalize your setup" "Optional Git identity used by development tools."
  if has_gum; then
    FEDORY_USER_NAME=$(gum input --header "Git author name" \
      --placeholder "Optional - leave blank to configure later")
    FEDORY_USER_EMAIL=$(gum input --header "Git author email" \
      --placeholder "Optional - leave blank to configure later")
  else
    read -r -p "Your name (for git commits, optional): " FEDORY_USER_NAME
    read -r -p "Your email (for git commits, optional): " FEDORY_USER_EMAIL
  fi
  export FEDORY_USER_NAME FEDORY_USER_EMAIL

  # --- step 4: root-owned system setup ---------------------------------------
  # A problem installing or configuring one piece (a package unavailable on
  # this specific Fedora version, a COPR with a broken dependency, etc.)
  # doesn't stop here -- fedory-setup-system itself keeps going through
  # every remaining piece and only reports nonzero at the end if something
  # needs follow-up, so step 5 (per-user setup) still gets a chance to run
  # even when step 4 wasn't 100% clean.
  had_issues=0
  phase "Build the desktop" \
    "Packages, services, hardware support, login, and system integration."
  sudo env FEDORY_PATH="$FEDORY_PATH" PATH="$FEDORY_PATH/bin:$PATH" \
    FEDORY_PROGRESS_TOTAL="$FEDORY_PROGRESS_TOTAL" \
    FEDORY_PROGRESS_FILE="$FEDORY_PROGRESS_FILE" \
    fedory-setup-system --install-user "$USER" --first-install \
    || had_issues=1

  # --- step 5: per-user finalization -----------------------------------------
  phase "Configure your workspace" \
    "Seed user defaults, applications, theme, and development integrations."
  FEDORY_SETUP_CONTEXT=bootstrap fedory-finalize-user --first-install \
    || had_issues=1

  # --- step 6: done -----------------------------------------------------------
  phase "Installation complete"
  elapsed=$(( $(date +%s) - STEP_START_EPOCH ))
  if (( had_issues )); then
    if has_gum; then
      gum style --border rounded --border-foreground 214 --padding "1 2" \
        "FINISHED WITH WARNINGS" \
        "Elapsed   $(( elapsed / 60 ))m $(( elapsed % 60 ))s" \
        "Log       /var/log/fedory-install.log" \
        "Review the failed tasks above, then rerun the installer."
    else
      echo "Fedory is installed, but a few things need a second look -- scroll up (or check /var/log/fedory-install.log) for what to retry."
    fi
  elif has_gum; then
    gum style --border rounded --border-foreground 42 --padding "1 2" \
      "FEDORY IS READY" \
      "Elapsed   $(( elapsed / 60 ))m $(( elapsed % 60 ))s" \
      "Log       /var/log/fedory-install.log" \
      "Reboot to enter your new Hyprland desktop."
  else
    success "Fedory is installed in $(( elapsed / 60 ))m $(( elapsed % 60 ))s."
    info "Log: /var/log/fedory-install.log"
  fi
  echo
  if confirm "Reboot now?"; then
    sudo systemctl reboot
  else
    info "Remember to reboot before logging into Hyprland."
  fi

  # The installer deliberately continues through independent leaves so one
  # failure does not hide the rest of the machine's setup state. Preserve that
  # behavior while still giving automation a truthful final result.
  if (( had_issues )); then
    exit 1
  fi
}

main "$@"
