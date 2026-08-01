-- Based on basecamp/omarchy default/hypr/workspace-layouts.lua with Fedory command and path names.
-- Restore workspace layouts saved by fedory-hyprland-workspace-layout-toggle.

local paths = require("default.hypr.paths")
local require_all = require("default.hypr.require_all")

local layouts_dir = paths.state_home .. "/fedory/workspace-layouts"

require_all.files(layouts_dir, "fedory.workspace-layouts", { reload = true })
