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
version=4
projectHash=342d554b5a980d74
scope.0.id=chunk:src/ui/render/status3d/meta.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=e3e84f87c30029f7
scope.1.id=function:M.ensure_cache
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=19
scope.1.semanticHash=f04483395a5e0b68
scope.2.id=function:M.warn_once
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=27
scope.2.semanticHash=f2bc4a071deab55c
scope.3.id=function:M.build_meta
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=43
scope.3.semanticHash=036958d966e2a70f
]]
