echo "Install the August 2026 Omarchy parity updates"

fedory-pkg-add ddcutil gtk4-layer-shell python-dbus
fedory-pkg-drop gnome-calculator
fedory-calculator --install
fedory-mise-install github:can1357/oh-my-pi omp

mkdir -p "$HOME/.config/fastfetch"
cp -n "$FEDORY_PATH/default/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

whatsapp_slim_ext="$FEDORY_PATH/default/chromium/extensions/whatsapp-slim"

add_whatsapp_slim_extension() {
  local file=$1

  [[ -f $file ]] || return 0
  grep -q 'extensions/whatsapp-slim' "$file" && return 0

  if grep -q '^--load-extension=' "$file"; then
    sed -i --follow-symlinks "s|^--load-extension=\(.*\)$|--load-extension=\1,$whatsapp_slim_ext|" "$file"
  else
    printf '%s\n' "--load-extension=$whatsapp_slim_ext" >>"$file"
  fi
}

for browser in chromium chrome google-chrome brave brave-beta brave-nightly brave-origin-beta microsoft-edge-stable; do
  add_whatsapp_slim_extension "$HOME/.config/$browser-flags.conf"
done

foot_config="$HOME/.config/foot/foot.ini"
if [[ -f $foot_config ]] && ! grep -q '^multiplier=' "$foot_config"; then
  if grep -qxF '[scrollback]' "$foot_config"; then
    tmp=$(mktemp)
    awk '
      { print }
      !inserted && $0 == "[scrollback]" {
        print "multiplier=7.0"
        inserted = 1
      }
    ' "$foot_config" >"$tmp"
    cat "$tmp" >"$foot_config"
    rm -f "$tmp"
  else
    printf '\n[scrollback]\nmultiplier=7.0\n' >>"$foot_config"
  fi
fi

user_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
sleep_lock_unit="$user_config_home/systemd/user/fedory-sleep-lock.service"
sleep_lock_dropin_dir="$user_config_home/systemd/user/fedory-sleep-lock.service.d"
sleep_lock_dropin="$sleep_lock_dropin_dir/90-fedory-session-environment.conf"

if [[ -f $sleep_lock_unit ]]; then
  mkdir -p "$sleep_lock_dropin_dir"
  printf '%s\n' \
    '[Unit]' \
    'After=dbus.socket wayland-session-waitenv.service' \
    'Requires=dbus.socket' \
    'PartOf=graphical-session.target' \
    'ConditionEnvironment=FEDORY_PATH' \
    'ConditionEnvironment=WAYLAND_DISPLAY' >"$sleep_lock_dropin"
else
  mkdir -p "$(dirname "$sleep_lock_unit")"
  cp "$FEDORY_PATH/default/systemd/user/fedory-sleep-lock.service" "$sleep_lock_unit"
fi

# Without a live user manager there is no inherited monitor to replace. The
# repaired unit will be loaded at the next graphical login.
user_manager_socket="${XDG_RUNTIME_DIR:-/run/user/$UID}/systemd/private"
if ! error=$(systemctl --user show-environment 2>&1); then
  if [[ -S $user_manager_socket ]]; then
    echo "Could not reach the running user service manager: $error"
    echo "The sleep-lock repair will be retried by fedory-migrate."
    exit 1
  fi
  exit 0
fi

if ! error=$(systemctl --user daemon-reload 2>&1); then
  echo "Could not reload the user service manager: $error"
  exit 1
fi

if ! graphical_state=$(systemctl --user show --property=ActiveState --value graphical-session.target 2>&1); then
  echo "Could not inspect graphical-session.target: $graphical_state"
  exit 1
fi

if [[ $graphical_state == "active" ]]; then
  if ! error=$(systemctl --user enable fedory-sleep-lock.service 2>&1); then
    echo "Could not enable fedory-sleep-lock.service: $error"
    echo "The sleep-lock repair will be retried by fedory-migrate."
    exit 1
  elif ! error=$(systemctl --user reset-failed fedory-sleep-lock.service 2>&1); then
    echo "Could not reset fedory-sleep-lock.service: $error"
    echo "The sleep-lock repair will be retried by fedory-migrate."
    exit 1
  elif ! error=$(systemctl --user restart fedory-sleep-lock.service 2>&1); then
    echo "Could not restart fedory-sleep-lock.service: $error"
    echo "The sleep-lock repair will be retried by fedory-migrate."
    exit 1
  elif ! sleep_lock_state=$(systemctl --user show --property=ActiveState --value fedory-sleep-lock.service 2>&1); then
    echo "Could not inspect fedory-sleep-lock.service: $sleep_lock_state"
    echo "The sleep-lock repair will be retried by fedory-migrate."
    exit 1
  elif [[ $sleep_lock_state != "active" ]]; then
    echo "fedory-sleep-lock.service did not stay active after restart."
    echo "The sleep-lock repair will be retried by fedory-migrate."
    exit 1
  fi
else
  if ! error=$(systemctl --user stop fedory-sleep-lock.service 2>&1); then
    echo "Could not stop stale fedory-sleep-lock.service: $error"
    echo "The sleep-lock repair will be retried by fedory-migrate."
    exit 1
  elif ! error=$(systemctl --user reset-failed fedory-sleep-lock.service 2>&1); then
    echo "Could not reset fedory-sleep-lock.service: $error"
    echo "The sleep-lock repair will be retried by fedory-migrate."
    exit 1
  fi
fi
