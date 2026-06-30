local specs = require("src.ui.render.status3d.specs")
local scene = require("src.ui.render.status3d.scene")
local resolve = require("src.ui.render.status3d.status_resolve")

local M = {}

local _remaining_text_cache = {}
local _remaining_text_prefix = "剩余回合："

local function _get_remaining_text(remaining)
  local text = _remaining_text_cache[remaining]
  if text == nil then
    text = _remaining_text_prefix .. tostring(remaining)
    _remaining_text_cache[remaining] = text
  end
  return text
end

local function _resolve_text_status_context(cache, player, status_key, game)
  local spec = specs.status_specs[status_key]
  if not (spec and spec.text_node_name) then
    return nil, nil
  end
  local remaining = resolve.resolve_remaining_value(game, player, spec.remaining_field)
  local text_node = cache.text_nodes[player.id] and cache.text_nodes[player.id][status_key]
  if remaining <= 0 or text_node == nil then
    return nil, nil
  end
  return remaining, text_node
end

local function _sync_text_status(cache, player, status_key, roles, game)
  local remaining, text_node = _resolve_text_status_context(cache, player, status_key, game)
  if remaining == nil then
    return
  end
  local text = _get_remaining_text(remaining)
  for _, role in ipairs(roles) do
    if role and role.set_label_text then
      pcall(role.set_label_text, text_node, text)
    end
  end
end

local function _apply_layer_visibility(player_layers, roles, status_key, deps)
  for _, key in ipairs(specs.status_priority) do
    local layer = player_layers[key]
    if layer then
      scene.set_layer_visible_for_roles(layer, roles, status_key == key, deps)
    end
  end
end

function M.sync_layer_status(cache, player, status_key, deps, game)
  local player_id = player.id
  local player_layers = cache.layers[player_id]
  if not player_layers then
    return
  end
  local roles = scene.resolve_observer_roles()
  if cache.last_status_key_by_player[player_id] == status_key then
    _sync_text_status(cache, player, status_key, roles, game)
    return
  end
  _apply_layer_visibility(player_layers, roles, status_key, deps)
  _sync_text_status(cache, player, status_key, roles, game)
  cache.last_status_key_by_player[player_id] = status_key
end

-- Status-key resolution lives in status_resolve; re-exported here so existing
-- callers (init.lua, behavior specs) keep a single status entry point.
M.resolve_player_status_key = resolve.resolve_player_status_key

return M

--[[ mutate4lua-manifest
version=2
projectHash=448d006e56c66a1f
scope.0.id=chunk:src/ui/render/status3d/status.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=75
scope.0.semanticHash=3ddaf86fb77382b2
scope.0.lastMutatedAt=2026-06-30T13:40:57Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=12
scope.0.lastMutationKilled=11
scope.1.id=function:_get_remaining_text:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=17
scope.1.semanticHash=265d86e3382fb223
scope.1.lastMutatedAt=2026-06-30T13:40:57Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:_resolve_text_status_context:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=30
scope.2.semanticHash=35b9a0fa07073292
scope.2.lastMutatedAt=2026-06-30T13:40:57Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=8
scope.2.lastMutationKilled=8
scope.3.id=function:M.sync_layer_status:54
scope.3.kind=function
scope.3.startLine=54
scope.3.endLine=68
scope.3.semanticHash=33089e49400ddc36
scope.3.lastMutatedAt=2026-06-30T13:40:57Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=6
scope.3.lastMutationKilled=6
]]
