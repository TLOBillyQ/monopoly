local meta = require("src.ui.render.status3d.meta")
local scene = require("src.ui.render.status3d.scene")
local status = require("src.ui.render.status3d.status")
local host_runtime_bridge = require("src.ui.runtime.host_bridge")

local M = {}

local function _resolve_host_runtime(state, deps)
  local resolved_deps = deps or (state and state.presentation_runtime) or nil
  if resolved_deps and resolved_deps.host_runtime then
    return resolved_deps.host_runtime
  end
  return host_runtime_bridge
end

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
      status.sync_layer_status(cache, player, status.resolve_player_status_key(game, player), deps)
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
