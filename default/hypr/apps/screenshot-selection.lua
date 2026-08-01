-- Based on basecamp/omarchy default/hypr/apps/screenshot-selection.lua with Fedory command and path names.
-- Remove the 1px border around the slurp region selection used by screenshots.
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true, animation = "none" })
