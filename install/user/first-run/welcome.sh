(
  if [[ -n $(fedory-notification-send -u critical -g  "Learn Keybindings" "Super + K for cheatsheet.\nSuper + Space for application launcher.\nSuper + Alt + Space for Fedory Menu." -a) ]]; then
    fedory-menu-keybindings
  fi
) >/dev/null 2>&1 &
