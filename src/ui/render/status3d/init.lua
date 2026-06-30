local meta = require("src.ui.render.status3d.meta")
local scene = require("src.ui.render.status3d.scene")
local status = require("src.ui.render.status3d.status")
local host_runtime_resolver = require("src.ui.render.host_runtime_resolver")

local M = {}

local _resolve_host_runtime = host_runtime_resolver.from_state

function M.reset(state, deps)
  if not state or not state.ui_status_3d then
    return
  end
  local host_runtime = _resolve_host_runtime(state, deps)
  local cache = state.ui_status_3d
  for _, player_layers in pairs(cache.layers or {}) do
    for _, layer in pairs(player_layers) do
      if layer ~= nil then
        host_runtime.destroy_scene_ui(layer)
      end
    end
  end
  state.ui_status_3d = nil
end

local function _check_scene_ui_support(cache, host_runtime)
  if not host_runtime.has_scene_ui_support() then
    meta.warn_once(cache, "missing_gameapi", "status3d disabled: missing scene ui GameAPI methods")
    cache.disabled = true
    return false
  end
  return true
end

local function _check_scene_ui_env(cache)
  if not (Enums and Enums.ModelSocket and Enums.ModelSocket.socket_head and math and math.Vector3) then
    meta.warn_once(cache, "missing_sceneui_env", "status3d disabled: missing scene ui runtime")
    cache.disabled = true
    return false
  end
  return true
end

local function _check_meta_ready(cache)
  local _, err = meta.build_meta(cache)
  if err then
    meta.warn_once(cache, "meta_error", "status3d disabled: " .. tostring(err))
    cache.disabled = true
    return false
  end
  return true
end

local function _has_any_dirty(dirty)
  return dirty and (dirty.players or dirty.turn or dirty.any)
end

local function _has_missing_player_layer(cache, players)
  for _, player in ipairs(players or {}) do
    if cache.layers[player.id] == nil then
      return true
    end
  end
  return false
end

local function _should_skip_sync(cache, dirty, players)
  local has_dirty = _has_any_dirty(dirty)
  local has_missing_layer = _has_missing_player_layer(cache, players)
  return not has_dirty and not has_missing_layer
end

local function _ensure_all_player_layers(cache, players, deps)
  for _, player in ipairs(players or {}) do
    scene.ensure_layers_for_player(cache, player, deps)
  end
end

local function _sync_all_player_status(cache, game, players, deps)
  for _, player in ipairs(players or {}) do
    if cache.layers[player.id] ~= nil then
      status.sync_layer_status(cache, player, status.resolve_player_status_key(game, player), deps, game)
    end
  end
end

function M.sync(game, state, dirty, deps)
  if not game or not state then
    return
  end
  local host_runtime = _resolve_host_runtime(state, deps)
  local cache = meta.ensure_cache(state)
  if cache.disabled then
    return
  end
  if not _check_scene_ui_support(cache, host_runtime) then
    return
  end
  if not _check_scene_ui_env(cache) then
    return
  end
  if not _check_meta_ready(cache) then
    return
  end
  if _should_skip_sync(cache, dirty, game.players) then
    return
  end
  _ensure_all_player_layers(cache, game.players, deps)
  _sync_all_player_status(cache, game, game.players, deps)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=188707d62494ef2b
scope.0.id=chunk:src/ui/render/status3d/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=113
scope.0.semanticHash=fde45251754433e2
scope.1.id=function:_check_scene_ui_support:26
scope.1.kind=function
scope.1.startLine=26
scope.1.endLine=33
scope.1.semanticHash=61b827573f732afb
scope.2.id=function:_check_scene_ui_env:35
scope.2.kind=function
scope.2.startLine=35
scope.2.endLine=42
scope.2.semanticHash=1fca0b0b35d267d3
scope.3.id=function:_check_meta_ready:44
scope.3.kind=function
scope.3.startLine=44
scope.3.endLine=52
scope.3.semanticHash=1099777e4ec36ecd
scope.4.id=function:_has_any_dirty:54
scope.4.kind=function
scope.4.startLine=54
scope.4.endLine=56
scope.4.semanticHash=2338a7e30f4779f9
scope.5.id=function:_should_skip_sync:67
scope.5.kind=function
scope.5.startLine=67
scope.5.endLine=71
scope.5.semanticHash=c57e763cac26353d
scope.6.id=function:M.sync:87
scope.6.kind=function
scope.6.startLine=87
scope.6.endLine=110
scope.6.semanticHash=856cd603e0051858
]]
