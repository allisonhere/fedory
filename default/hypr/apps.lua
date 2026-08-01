-- Based on basecamp/omarchy default/hypr/apps.lua with Fedory command and path names.
-- App-specific tweaks.
local paths = require("default.hypr.paths")
local require_all = require("default.hypr.require_all")

require_all.files(paths.fedory_path .. "/default/hypr/apps", "default.hypr.apps")
