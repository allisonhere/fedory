notify_update() {
  (
    if [[ -n $(fedory-notification-send -u critical -g  "Update System" "$1" -a) ]]; then
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

if ! ping -c3 -W1 1.1.1.1 >/dev/null 2>&1; then
  notify_update "When you have internet, click to update the system."
  # Both toasts are sent from background subshells, so let the update one
  # register before queueing Wi-Fi. Newest stacks on top, and Wi-Fi is what
  # you need first.
  sleep 0.3
  notify_wifi
else
  notify_update "Click to update the system."
fi
