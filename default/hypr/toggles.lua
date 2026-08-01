-- Based on basecamp/omarchy default/hypr/toggles.lua with Fedory command and path names.
local paths = require("default.hypr.paths")
local require_all = require("default.hypr.require_all")

local toggles_dir = paths.state_home .. "/fedory/toggles/hypr"
package.path = toggles_dir .. "/?.lua;" .. package.path

require_all.files(toggles_dir, nil, { reload = true })

require("default.hypr.workspace-layouts")
