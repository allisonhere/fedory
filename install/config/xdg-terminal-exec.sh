# Install the reference implementation of the proposed XDG default-terminal
# specification. Based on Vladimir-csp/xdg-terminal-exec at the pinned commit
# below; Fedory installs only the shell implementation and its Foot preference.

xdg_terminal_exec_commit=065925df9f419008159258ae169018bfd23df71b
xdg_terminal_exec_sha256=89f2be9a65deb8df93633a9a09b4953a921c83d591ab987f7569280ecd3127ac

if fedory-cmd-missing xdg-terminal-exec; then
  xdg_terminal_exec_tmp=$(mktemp)
  curl -fsSL \
    "https://raw.githubusercontent.com/Vladimir-csp/xdg-terminal-exec/$xdg_terminal_exec_commit/xdg-terminal-exec" \
    -o "$xdg_terminal_exec_tmp"
  printf '%s  %s\n' "$xdg_terminal_exec_sha256" "$xdg_terminal_exec_tmp" \
    | sha256sum -c -
  install -Dm755 "$xdg_terminal_exec_tmp" /usr/local/bin/xdg-terminal-exec
  rm -f "$xdg_terminal_exec_tmp"
fi

install -Dm644 \
  "$FEDORY_PATH/default/xdg-terminal-exec/hyprland-xdg-terminals.list" \
  /usr/local/share/xdg-terminal-exec/hyprland-xdg-terminals.list
