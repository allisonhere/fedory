#!/bin/bash
# Fedory bootstrap: curl-pipeable entry point for an existing Fedora
# Workstation install. Fedory-invented -- upstream Omarchy no longer has a
# repo-root equivalent post-4.0 ("Quattro"); see docs/scope.md for why.
#
#   curl -fsSL https://raw.githubusercontent.com/allisonhere/fedory/master/bootstrap.sh | bash
#
set -eEo pipefail

FEDORY_REPO="${FEDORY_REPO:-allisonhere/fedory}"
FEDORY_REF="${FEDORY_REF:-master}"
FEDORY_PATH="${FEDORY_PATH:-$HOME/.local/share/fedory}"

STEP_TOTAL=6
STEP_CURRENT=0
STEP_START_EPOCH=$(date +%s)

# --- output helpers -----------------------------------------------------
# gum isn't installed yet on step 1, so every helper below degrades to plain
# echo/read until has_gum starts reporting true.

has_gum() { command -v gum >/dev/null 2>&1; }

banner() {
  if has_gum; then
    gum style --border double --margin "1 0" --padding "1 4" --border-foreground 63 --bold \
      "FEDORY" "A beautiful, modern & opinionated Hyprland desktop for Fedora."
  else
    cat <<'BANNER'
==========================================================
  FEDORY
  A beautiful, modern & opinionated Hyprland desktop for Fedora.
==========================================================
BANNER
  fi
}

step() {
  STEP_CURRENT=$((STEP_CURRENT + 1))
  local msg="[$STEP_CURRENT/$STEP_TOTAL] $*"
  if has_gum; then
    gum style --foreground 63 --bold "$msg"
  else
    echo "$msg"
  fi
}

info() {
  if has_gum; then
    gum style --faint "$*"
  else
    echo "  $*"
  fi
}

die() {
  if has_gum; then
    gum style --foreground 196 --bold "Error: $*"
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
    gum confirm "$prompt"
  else
    read -r -p "$prompt [y/N] " reply
    [[ $reply =~ ^[Yy]$ ]]
  fi
}

trap 'die "unexpected failure at line $LINENO. Log: /var/log/fedory-install.log (if created) or scroll up for the failing command."' ERR

# --- preflight ------------------------------------------------------------
banner
echo
info "This installs Fedory onto the Fedora system you're currently logged into."
info "Expect roughly 15-30 minutes depending on your connection and how many"
info "packages are already cached. It's safe to re-run if it fails partway."
echo

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

if ! confirm "Ready to install Fedory on $(hostname)?"; then
  echo "Cancelled."
  exit 0
fi

# --- step 1: bootstrap dependencies ---------------------------------------
step "Installing bootstrap dependencies (git, gum)"
sudo dnf install -y --quiet git gum || die "failed to install git/gum via dnf"

# From here on, has_gum is true and every helper above gets the styled path.
banner

# --- step 2: clone the repo -------------------------------------------
step "Fetching Fedory ($FEDORY_REF)"
if [[ -d $FEDORY_PATH/.git ]]; then
  info "Existing checkout found at $FEDORY_PATH, updating instead of re-cloning."
  git -C "$FEDORY_PATH" fetch --depth 1 origin "$FEDORY_REF"
  git -C "$FEDORY_PATH" checkout "$FEDORY_REF"
  git -C "$FEDORY_PATH" reset --hard "origin/$FEDORY_REF"
else
  mkdir -p "$(dirname "$FEDORY_PATH")"
  git clone --depth 1 --branch "$FEDORY_REF" "https://github.com/$FEDORY_REPO.git" "$FEDORY_PATH"
fi
export FEDORY_PATH
export PATH="$FEDORY_PATH/bin:$PATH"

# --- step 3: collect a little identity info up front ----------------------
step "A couple of quick questions"
if has_gum; then
  FEDORY_USER_NAME=$(gum input --placeholder "Your name (for git commits, optional)")
  FEDORY_USER_EMAIL=$(gum input --placeholder "Your email (for git commits, optional)")
else
  read -r -p "Your name (for git commits, optional): " FEDORY_USER_NAME
  read -r -p "Your email (for git commits, optional): " FEDORY_USER_EMAIL
fi
export FEDORY_USER_NAME FEDORY_USER_EMAIL

# --- step 4: root-owned system setup ---------------------------------------
step "Applying system setup (needs sudo)"
info "Package installs, services, firewall, display manager, hardware setup."
sudo env FEDORY_PATH="$FEDORY_PATH" PATH="$FEDORY_PATH/bin:$PATH" \
  fedory-setup-system --install-user "$USER" --first-install \
  || die "fedory-setup-system failed -- see /var/log/fedory-install.log"

# --- step 5: per-user finalization -----------------------------------------
step "Finalizing your user setup"
FEDORY_SETUP_CONTEXT=bootstrap fedory-finalize-user --first-install \
  || die "fedory-finalize-user failed"

# --- step 6: done -----------------------------------------------------------
step "Done"
elapsed=$(( $(date +%s) - STEP_START_EPOCH ))
info "Finished in $(( elapsed / 60 ))m $(( elapsed % 60 ))s."
echo
if has_gum; then
  gum style --foreground 42 --bold "Fedory is installed. Reboot to log into your new Hyprland desktop."
else
  echo "Fedory is installed. Reboot to log into your new Hyprland desktop."
fi
echo
if confirm "Reboot now?"; then
  sudo systemctl reboot
else
  info "Remember to reboot before logging into Hyprland."
fi
