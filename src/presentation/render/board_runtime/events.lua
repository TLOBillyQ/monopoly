local building_effects = require("src.presentation.render.BuildingEffects")
local tile_renderer = require("src.presentation.render.TileRenderer")
local number_utils = require("src.core.NumberUtils")
local runtime_constants = require("src.core.config.RuntimeConstants")

local M = {}

function M.on_tile_upgraded(state, tile_id, level)
  assert(tile_id ~= nil, "missing tile_id")
  assert(level ~= nil, "missing level")
  local scene = assert(state.board_scene, "missing board_scene")
  local buildings = assert(scene.buildings, "missing board_scene.buildings")
  local board = assert(state.game and state.game.board, "missing board")
  assert(board.index_of_tile_id ~= nil, "missing board.index_of_tile_id")
  local idx = assert(board:index_of_tile_id(tile_id), "missing tile index: " .. tostring(tile_id))
  assert(buildings[idx] ~= nil, "missing building unit: " .. tostring(idx))
  local lv = assert(number_utils.to_integer(level), "invalid level: " .. tostring(level))
  assert(lv >= 1 and lv <= 3, "invalid level: " .. tostring(lv))
  local root_quaternion = assert(runtime_constants.q_zero, "missing Q_ZERO")
  building_effects.spawn_upgrade_building_units(scene, root_quaternion, idx, lv)
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
