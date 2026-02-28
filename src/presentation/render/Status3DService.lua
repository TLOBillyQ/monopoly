local meta = require("src.presentation.render.status3d_service.meta")
local scene = require("src.presentation.render.status3d_service.scene")
local status = require("src.presentation.render.status3d_service.status")

local M = {}

function M.reset(state)
  if not state or not state.ui_status_3d then
    return
  end
  local cache = state.ui_status_3d
  if GameAPI and GameAPI.destroy_scene_ui then
    for _, player_layers in pairs(cache.layers or {}) do
      for _, layer in pairs(player_layers) do
        if layer ~= nil then
          pcall(GameAPI.destroy_scene_ui, layer)
        end
      end
    end
  end
  state.ui_status_3d = nil
end

function M.sync(game, state, dirty)
  if not game or not state then
    return
  end
  local cache = meta.ensure_cache(state)
  if cache.disabled then
    return
  end
  if not (GameAPI and GameAPI.get_role and GameAPI.set_scene_ui_visible) then
    meta.warn_once(cache, "missing_gameapi", "status3d disabled: missing scene ui GameAPI methods")
    cache.disabled = true
    return
  end
  if not (Enums and Enums.ModelSocket and Enums.ModelSocket.socket_head and math and math.Vector3) then
    meta.warn_once(cache, "missing_sceneui_env", "status3d disabled: missing scene ui runtime")
    cache.disabled = true
    return
  end
  local _, err = meta.build_meta(cache)
  if err then
    meta.warn_once(cache, "meta_error", "status3d disabled: " .. tostring(err))
    cache.disabled = true
    return
  end
  local has_dirty = dirty and (dirty.players or dirty.turn or dirty.any)
  local has_missing_layer = false
  for _, player in ipairs(game.players or {}) do
    if cache.layers[player.id] == nil then
      has_missing_layer = true
      break
    end
  end
  if not has_dirty and not has_missing_layer then
    return
  end
  for _, player in ipairs(game.players or {}) do
    scene.ensure_layers_for_player(cache, player)
  end
  for _, player in ipairs(game.players or {}) do
    if cache.layers[player.id] ~= nil then
      status.sync_layer_status(cache, player, status.resolve_player_status_key(game, player))
    end
  end
end

return M
