local building_effects = require("src.presentation.render.BuildingEffects")
local tile_renderer = require("src.presentation.render.TileRenderer")
local number_utils = require("src.core.NumberUtils")
local runtime_constants = require("src.core.config.RuntimeConstants")

local M = {}

function M.on_tile_upgraded(state, tile_id, level)
  if tile_id == nil or level == nil then
    return false
  end
  local scene = state and state.board_scene or nil
  local buildings = scene and scene.buildings or nil
  local board = state and state.game and state.game.board or nil
  if not scene or not buildings or not board or type(board.index_of_tile_id) ~= "function" then
    return false
  end
  local idx = board:index_of_tile_id(tile_id)
  local lv = number_utils.to_integer(level)
  if idx == nil then
    return false
  end
  if lv == nil or lv < 1 or lv > 3 then
    return false
  end
  if buildings[idx] == nil then
    return false
  end
  local root_quaternion = assert(runtime_constants.q_zero, "missing Q_ZERO")
  building_effects.spawn_upgrade_building_units(scene, root_quaternion, idx, lv)
  return true
end

function M.on_tile_owner_changed(state, tile_id, owner_id)
  assert(tile_id ~= nil, "missing tile_id")
  local board = assert(state.game and state.game.board, "missing board")
  assert(board.index_of_tile_id ~= nil, "missing board.index_of_tile_id")
  local idx = assert(board:index_of_tile_id(tile_id), "missing tile index: " .. tostring(tile_id))
  assert(state.tile_units ~= nil, "missing tile_units")
  assert(state.tile_units[idx] ~= nil, "missing tile unit: " .. tostring(idx))
  tile_renderer.render_tile(state.tile_units[idx], tile_id, owner_id)
end

return M
