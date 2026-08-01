-- Based on basecamp/omarchy default/hypr/require_optional.lua with Fedory command and path names.
-- Require a module only when it can be found on package.path.
-- Errors inside existing modules still surface normally.

local M = {}

function M.module(module)
  if package.searchpath(module, package.path) then
    return require(module)
  end
end

return M
