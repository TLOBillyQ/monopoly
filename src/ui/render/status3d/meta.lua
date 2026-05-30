local logger = require("src.foundation.log")
local specs = require("src.ui.render.status3d.specs")

local M = {}

function M.ensure_cache(state)
  assert(state ~= nil, "missing state")
  if state.ui_status_3d == nil then
    state.ui_status_3d = {
      layers = {},
      text_nodes = {},
      last_status_key_by_player = {},
      warned_once = {},
      disabled = false,
      meta = nil,
    }
  end
  return state.ui_status_3d
end

function M.warn_once(cache, key, ...)
  if cache.warned_once[key] then
    return
  end
  cache.warned_once[key] = true
  logger.warn(...)
end

function M.build_meta(cache)
  if cache.meta ~= nil then
    return cache.meta
  end
  local layouts = {}
  for status_key in pairs(specs.status_specs) do
    local layout_id = specs.get_layout_id(status_key)
    if not layout_id then
      return nil, "missing scene_eui layout for status: " .. tostring(status_key)
    end
    layouts[status_key] = layout_id
  end
  cache.meta = { layouts = layouts }
  return cache.meta
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=34ce547f97fc1bda
scope.0.id=chunk:src/ui/render/status3d/meta.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=4b4547cca9937b2a
scope.1.id=function:M.ensure_cache:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=19
scope.1.semanticHash=7b406af14e7ebc36
scope.2.id=function:M.warn_once:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=27
scope.2.semanticHash=e02964e59a8e2fcc
]]
