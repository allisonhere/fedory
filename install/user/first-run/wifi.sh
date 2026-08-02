notify_update() {
  (
    if [[ -n $(fedory-notification-send -u critical -g 󰚰 "Update System" "$1" -a) ]]; then
      fedory-launch-floating-terminal-with-presentation fedory-update
    fi
  ) >/dev/null 2>&1 &
}

notify_wifi() {
  (
    if [[ -n $(fedory-notification-send -u critical -g 󰖩 "Setup Wi-Fi" "Click to configure the wireless network." -a) ]]; then
      fedory-shell shell toggle fedory.network
    fi
  ) >/dev/null 2>&1 &
}

# The update invitation is a one-time courtesy, so mark it the way welcome.sh
# marks its own. fedory-first-run replays every step when any step fails, and
# without this the toast came back on each login. The Wi-Fi toast below stays
# unguarded on purpose: it only fires while there is no connectivity, which is
# a condition worth re-raising until it is resolved.
offer_update() {
  fedory-done ensure update-system-invitation || return 0

  # Only claim there is something to install when there actually is. This used
  # to say "Click to update the system" unconditionally, so a freshly updated
  # machine was still told to update.
  if fedory-update-available >/dev/null 2>&1; then
    notify_update "Click to update the system."
  fi
}

if ! ping -c3 -W1 1.1.1.1 >/dev/null 2>&1; then
  # Offline, so fedory-update-available cannot answer yet. Invite the update
  # for when connectivity returns, then queue Wi-Fi.
  if fedory-done ensure update-system-invitation; then
    notify_update "When you have internet, click to update the system."
  fi
  # Both toasts are sent from background subshells, so let the update one
  # register before queueing Wi-Fi. Newest stacks on top, and Wi-Fi is what
  # you need first.
  sleep 0.3
  notify_wifi
else
  offer_update
fi
