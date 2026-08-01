-- Based on basecamp/omarchy default/hypr/paths.lua with Fedory paths.
-- Shared path constants for Fedory's Hyprland Lua modules.
-- Lua files loaded with require() have separate local scopes, so modules that
-- need these paths import this table instead of repeating os.getenv() lookups.

local home = os.getenv("HOME")
local fedory_path = assert(os.getenv("FEDORY_PATH"), "FEDORY_PATH is not set by the uwsm session")

return {
  home = home,
  config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config"),
  state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state"),
  fedory_path = fedory_path,
}
