if ! fedory-done ensure learn-keybindings-invitation; then
  return 0 2>/dev/null || exit 0
fi

(
  # $'...' rather than "..." so the line breaks are real newlines. In double
  # quotes bash leaves \n as a literal backslash-n, and fedory-notification-send
  # hands the body to notify-send untouched, so the escape reached the
  # notification daemon verbatim and was displayed as text.
  #
  # -g also needs an actual glyph. It was empty here, so it consumed the next
  # argument: "Learn Keybindings" became the glyph, the body became the
  # headline, and the title was lost entirely -- which is why the invitation
  # rendered with its heading stranded in the middle of the message.
  if [[ -n $(fedory-notification-send -u critical -g 󰌌 "Learn Keybindings" \
    $'Super + K for cheatsheet.\nSuper + Space for application launcher.\nSuper + Alt + Space for Fedory Menu.' \
    -a) ]]; then
    fedory-menu-keybindings
  fi
) >/dev/null 2>&1 &
