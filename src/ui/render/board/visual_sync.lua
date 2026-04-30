local prefab = require("Data.Prefab")
local building_effects = require("src.ui.render.building_effects")
local tile_renderer = require("src.ui.render.tile_renderer")
local overlay_runtime = require("src.ui.render.anim.overlay_runtime")
local overlay_compute = require("src.ui.render.anim.overlay_compute")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local visual_sync = {}

local roadblock_scale = math and math.Vector3 and math.Vector3(4.0, 4.0, 4.0) or {
  x = 4.0,
  y = 4.0,
  z = 4.0,
}

local _trigger_kind_for_overlay = {
  roadblock = "roadblock_trigger",
  mine = "mine_trigger",
}

local function _match_in_anim_queue(queue, target_kind, tile_index)
  if type(queue) ~= "table" then
    return false
  end
  for _, entry in ipairs(queue) do
    if entry.kind == target_kind and entry.tile_index == tile_index then
      return true
    end
  end
  return false
end

local function _has_pending_trigger_anim(state, overlay_kind, tile_index)
  local game = state and state.game or nil
  local turn = game and game.turn or nil
  if not turn then
    return false
  end
  local target_kind = _trigger_kind_for_overlay[overlay_kind]
  if not target_kind then
    return false
  end
  local current = turn.action_anim
  if current and current.kind == target_kind and current.tile_index == tile_index then
    return true
  end
  return _match_in_anim_queue(turn.action_anim_queue, target_kind, tile_index)
end

local function _dedupe_list(raw_list)
  local list = {}
  local seen = {}
  if type(raw_list) ~= "table" then
    return list
  end
  for _, value in ipairs(raw_list) do
    if value ~= nil and not seen[value] then
      seen[value] = true
      list[#list + 1] = value
    end
  end
  return list
end

local function _deps(state)
  return state and state.presentation_runtime or nil
end

local function _resolve_board(state)
  local game = state and state.game or nil
  return game and game.board or nil
end

local function _resolve_scene(state)
  return state and state.board_scene or nil
end

local function _resolve_tile_unit(state, scene, idx)
  local tile_units = state and state.tile_units or nil
  if type(tile_units) == "table" and tile_units[idx] ~= nil then
    return tile_units[idx]
  end
  local scene_tiles = scene and scene.tiles or nil
  if type(scene_tiles) == "table" then
    return scene_tiles[idx]
  end
  return nil
end

local function _spawn_roadblock_overlay(state, idx)
  return overlay_runtime.spawn_overlay(
    assert(_resolve_scene(state), "missing board_scene"),
    "roadblock",
    idx,
    nil,
    prefab.unit and prefab.unit["路障"] or nil,
    overlay_compute.overlay_pos_for_tile(state, idx),
    roadblock_scale,
    _deps(state)
  )
end

local function _spawn_mine_overlay(state, idx)
  return overlay_runtime.spawn_overlay(
    assert(_resolve_scene(state), "missing board_scene"),
    "mine",
    idx,
    prefab.group["地雷"],
    prefab.unit and prefab.unit["地雷"] or nil,
    overlay_compute.overlay_pos_for_tile(state, idx),
    _deps(state)
  )
end

local function _sync_owner_visual(state, tile_unit, tile_id, board)
  if tile_unit == nil then
    return
  end
  local tile = board:get_tile_by_id(tile_id)
  local owner_id = tile and tile.owner_id or nil
  local level = tile and tile.level or 0
  local owner_name = nil
  if owner_id then
    local game = state and state.game or nil
    if game and type(game.find_player_by_id) == "function" then
      local player = game:find_player_by_id(owner_id)
      owner_name = player and player.name or nil
    end
  end
  tile_renderer.render_tile(tile_unit, tile_id, owner_id, owner_name, level)
end

local function _sync_building_visual(state, scene, idx, board, tile_id, tile_unit)
  local tile = board:get_tile_by_id(tile_id)
  local level = tile and tile.level or 0
  if not (scene.buildings and scene.building_unit_groups) then
    return tile_unit ~= nil
  end
  if level and level > 0 then
    return building_effects.spawn_upgrade_building_units(
      scene,
      assert(runtime_constants.q_zero, "missing Q_ZERO"),
      idx,
      level,
      _deps(state)
    ) or tile_unit ~= nil
  end
  building_effects.clear_building_units(scene, idx, _deps(state))
  return true
end

function visual_sync.sync_tile_visual(state, tile_id)
  if tile_id == nil then
    return false
  end
  local board = _resolve_board(state)
  local scene = _resolve_scene(state)
  if not (board and scene and type(board.index_of_tile_id) == "function") then
    return false
  end
  local idx = board:index_of_tile_id(tile_id)
  if idx == nil then
    return false
  end

  local tile_unit = _resolve_tile_unit(state, scene, idx)
  _sync_owner_visual(state, tile_unit, tile_id, board)
  return _sync_building_visual(state, scene, idx, board, tile_id, tile_unit)
end

function visual_sync.sync_overlay_visual(state, board_index)
  if board_index == nil then
    return false
  end
  local board = _resolve_board(state)
  local scene = _resolve_scene(state)
  if not (board and scene) then
    return false
  end

  local has_roadblock = board:has_roadblock(board_index)
  local has_mine = board:has_mine(board_index)

  if has_roadblock then
    _spawn_roadblock_overlay(state, board_index)
  elseif not _has_pending_trigger_anim(state, "roadblock", board_index) then
    overlay_runtime.clear_overlay(scene, "roadblock", board_index, _deps(state))
  end

  if has_mine then
    _spawn_mine_overlay(state, board_index)
  elseif not _has_pending_trigger_anim(state, "mine", board_index) then
    overlay_runtime.clear_overlay(scene, "mine", board_index, _deps(state))
  end

  return true
end

function visual_sync.normalize_payload(payload)
  payload = payload or {}
  return {
    tile_ids = _dedupe_list(payload.tile_ids),
    overlay_indices = _dedupe_list(payload.overlay_indices),
  }
end

function visual_sync.sync_many(state, payload)
  local normalized = visual_sync.normalize_payload(payload)
  local handled = false

  for _, tile_id in ipairs(normalized.tile_ids) do
    if visual_sync.sync_tile_visual(state, tile_id) then
      handled = true
    end
  end
  for _, board_index in ipairs(normalized.overlay_indices) do
    if visual_sync.sync_overlay_visual(state, board_index) then
      handled = true
    end
  end

  return handled
end

return visual_sync
