local prefab = require("Data.Prefab")
local building_effects = require("src.presentation.view.render.building_effects")
local tile_renderer = require("src.presentation.view.render.tile_renderer")
local overlay_runtime = require("src.presentation.view.render.anim_overlay_runtime")
local overlay_compute = require("src.presentation.view.render.anim_overlay_compute")
local runtime_constants = require("src.core.config.runtime_constants")

local M = {}
local roadblock_scale = math and math.Vector3 and math.Vector3(4.0, 4.0, 4.0) or { x = 4.0, y = 4.0, z = 4.0 }

local function _render_tile(state, scene, board, tile_id)
  if not (board and board.index_of_tile_id and board.get_tile_by_id) then
    return false
  end
  local idx = board:index_of_tile_id(tile_id)
  local tile_units = (state and state.tile_units) or (scene and scene.tiles)
  local unit = tile_units and tile_units[idx] or nil
  if idx == nil or unit == nil then
    return false
  end
  local tile = board:get_tile_by_id(tile_id)
  local owner_id = tile and tile.owner_id or nil
  tile_renderer.render_tile(unit, tile_id, owner_id)
  return true
end

local function _render_building(scene, board, tile_id)
  if not (scene and scene.buildings and scene.building_unit_groups and board and board.index_of_tile_id and board.get_tile_by_id) then
    return false
  end
  local idx = board:index_of_tile_id(tile_id)
  if idx == nil or scene.buildings[idx] == nil then
    return false
  end
  local tile = board:get_tile_by_id(tile_id)
  local level = tile and tile.level or 0
  if level == nil or level < 1 then
    return false
  end
  return building_effects.spawn_upgrade_building_units(scene, assert(runtime_constants.q_zero, "missing Q_ZERO"), idx, level)
end

local function _spawn_overlay_for_index(state, kind, board_index)
  if state == nil or board_index == nil then
    return false
  end
  if kind == "roadblock" then
    return overlay_runtime.spawn_overlay(
      assert(state.board_scene, "missing board_scene"),
      kind,
      board_index,
      nil,
      prefab.unit and prefab.unit["路障"] or nil,
      overlay_compute.overlay_pos_for_tile(state, board_index),
      roadblock_scale
    )
  end
  if kind == "mine" then
    return overlay_runtime.spawn_overlay(
      assert(state.board_scene, "missing board_scene"),
      kind,
      board_index,
      prefab.group["地雷"],
      prefab.unit and prefab.unit["地雷"] or nil,
      overlay_compute.overlay_pos_for_tile(state, board_index)
    )
  end
  return false
end

function M.apply(state, board, scene)
  local game = state and state.game or nil
  local render_bootstrap = game and game.test_profile_render_bootstrap or nil
  if type(render_bootstrap) ~= "table" or render_bootstrap.applied == true then
    return false
  end

  local rendered = false
  local tiles_by_id = render_bootstrap.tiles_by_id or {}
  for tile_id in pairs(tiles_by_id) do
    if _render_tile(state, scene, game and game.board or nil, tile_id) then
      rendered = true
    end
    if _render_building(scene, game and game.board or nil, tile_id) then
      rendered = true
    end
  end

  local overlays = render_bootstrap.overlays or {}
  for board_index in pairs(overlays.roadblock or {}) do
    if _spawn_overlay_for_index(state, "roadblock", board_index) then
      rendered = true
    end
  end
  for board_index in pairs(overlays.mine or {}) do
    if _spawn_overlay_for_index(state, "mine", board_index) then
      rendered = true
    end
  end
  render_bootstrap.applied = true
  return rendered
end

return M
