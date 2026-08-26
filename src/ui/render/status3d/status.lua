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

local function _text_node(cache, player, status_key)
  return cache.text_nodes[player.id] and cache.text_nodes[player.id][status_key]
end

local function _resolve_text_status_context(cache, player, status_key, game)
  local spec = specs.status_specs[status_key]
  if not (spec and spec.text_node_name) then
    return nil, nil
  end
  local remaining = resolve.resolve_remaining_value(game, player, spec.remaining_field)
  local text_node = _text_node(cache, player, status_key)
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
    -- ipairs 遇 nil 即停,role 恒非 nil,`role and` 是死防御(#262 删除:
    -- and->or 在 role 恒真下逐值等价)。
    if role.set_label_text then
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
version=4
projectHash=65eb8335c9b8c42e
scope.0.id=chunk:src/ui/render/status3d/status.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=81
scope.0.semanticHash=8a2b6ff885cbe8ff
scope.1.id=function:_get_remaining_text
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=17
scope.1.semanticHash=f1706fbb91212132
scope.2.id=function:_text_node
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=21
scope.2.semanticHash=71a486496cfde618
scope.3.id=function:_resolve_text_status_context
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=34
scope.3.semanticHash=f28ae6c46ba5d246
scope.4.id=function:_sync_text_status
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=49
scope.4.semanticHash=acf2d1c2b49a6d39
scope.5.id=function:_apply_layer_visibility
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=58
scope.5.semanticHash=f056f6210838610e
scope.6.id=function:M.sync_layer_status
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=74
scope.6.semanticHash=8e857963ab2ab865
]]
