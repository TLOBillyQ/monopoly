local meta = require("src.ui.render.status3d.meta")
local scene = require("src.ui.render.status3d.scene")
local status = require("src.ui.render.status3d.status")
local host_runtime_resolver = require("src.ui.render.support.host_runtime_resolver")

local M = {}

local _resolve_host_runtime = host_runtime_resolver.from_state

local function _destroy_layer(host_runtime, layer)
  if layer ~= nil then
    host_runtime.destroy_scene_ui(layer)
  end
end

local function _destroy_cached_layers(cache, host_runtime)
  for _, player_layers in pairs(cache.layers or {}) do
    for _, layer in pairs(player_layers) do
      _destroy_layer(host_runtime, layer)
    end
  end
end

function M.reset(state, deps)
  if not state or not state.ui_status_3d then
    return
  end
  local host_runtime = _resolve_host_runtime(state, deps)
  _destroy_cached_layers(state.ui_status_3d, host_runtime)
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

local function _scene_ui_env_ready()
  return Enums and Enums.ModelSocket and Enums.ModelSocket.socket_head and math and math.Vector3
end

local function _check_scene_ui_env(cache)
  if not _scene_ui_env_ready() then
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

local function _scene_ready(cache, host_runtime)
  return _check_scene_ui_support(cache, host_runtime)
      and _check_scene_ui_env(cache)
      and _check_meta_ready(cache)
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

local function _sync_guard(cache, host_runtime, dirty, players)
  if cache.disabled then
    return false
  end
  if not _scene_ready(cache, host_runtime) then
    return false
  end
  return not _should_skip_sync(cache, dirty, players)
end

function M.sync(game, state, dirty, deps)
  if not game or not state then
    return
  end
  local host_runtime = _resolve_host_runtime(state, deps)
  local cache = meta.ensure_cache(state)
  if not _sync_guard(cache, host_runtime, dirty, game.players) then
    return
  end
  _ensure_all_player_layers(cache, game.players, deps)
  _sync_all_player_status(cache, game, game.players, deps)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=120cacc26a21aec5
scope.0.id=chunk:src/ui/render/status3d/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=128
scope.0.semanticHash=f6250800cad7942a
scope.1.id=function:_destroy_layer
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=14
scope.1.semanticHash=f4ce5ac53912da8d
scope.2.id=function:_destroy_cached_layers
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=22
scope.2.semanticHash=4ce2a757b8d66856
scope.3.id=function:M.reset
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=31
scope.3.semanticHash=dee9dda13b63dd4a
scope.4.id=function:_check_scene_ui_support
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=40
scope.4.semanticHash=2e2a3a10e2681a9a
scope.5.id=function:_scene_ui_env_ready
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=44
scope.5.semanticHash=e4116a0eb90d8572
scope.6.id=function:_check_scene_ui_env
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=53
scope.6.semanticHash=492899d1b2fc8415
scope.7.id=function:_check_meta_ready
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=63
scope.7.semanticHash=97177e0dd8a4b06f
scope.8.id=function:_has_any_dirty
scope.8.kind=function
scope.8.startLine=65
scope.8.endLine=67
scope.8.semanticHash=6b694d95de4ab102
scope.9.id=function:_has_missing_player_layer
scope.9.kind=function
scope.9.startLine=69
scope.9.endLine=76
scope.9.semanticHash=bdb4757ac74b7d5b
scope.10.id=function:_should_skip_sync
scope.10.kind=function
scope.10.startLine=78
scope.10.endLine=82
scope.10.semanticHash=8a76d05763c7079b
scope.11.id=function:_scene_ready
scope.11.kind=function
scope.11.startLine=84
scope.11.endLine=88
scope.11.semanticHash=310e3cecf84b7477
scope.12.id=function:_ensure_all_player_layers
scope.12.kind=function
scope.12.startLine=90
scope.12.endLine=94
scope.12.semanticHash=58e65e89398aac6c
scope.13.id=function:_sync_all_player_status
scope.13.kind=function
scope.13.startLine=96
scope.13.endLine=102
scope.13.semanticHash=2d1626c1b7e8a9a0
scope.14.id=function:_sync_guard
scope.14.kind=function
scope.14.startLine=104
scope.14.endLine=112
scope.14.semanticHash=a30b1a84bdcd40a4
scope.15.id=function:M.sync
scope.15.kind=function
scope.15.startLine=114
scope.15.endLine=125
scope.15.semanticHash=69c443dda01aab37
]]
