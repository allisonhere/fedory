-- Based on basecamp/omarchy default/hypr/apps/terminals.lua with Fedory command and path names.
-- Define terminal tag so themes and bindings can single terminals out. Fedory
-- launches TUIs and its own terminal windows under dedicated app-ids
-- (org.fedory.btop, org.fedory.terminal, TUI.float, ...), so match those too.
o.window(
  "(Alacritty|kitty|com.mitchellh.ghostty|foot|wezterm|org\\.fedory\\..*|TUI\\..*)",
  { tag = "+terminal" }
)
