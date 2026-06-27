local prefab = require("Data.Prefab")
local building_effects = require("src.ui.render.building_effects")
local tile_renderer = require("src.ui.render.tile")
local overlay_runtime = require("src.ui.render.anim.overlay_runtime")
local overlay_compute = require("src.ui.render.anim.overlay_compute")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local contiguous_count = require("src.ui.view.contiguous_count")
local tile_rent = require("src.ui.view.tile_rent")

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

local function _dedupe_into(raw_list, out, seen)
  for k in pairs(out) do out[k] = nil end
  for k in pairs(seen) do seen[k] = nil end
  if type(raw_list) ~= "table" then
    return out
  end
  for _, value in ipairs(raw_list) do
    if value ~= nil and not seen[value] then
      seen[value] = true
      out[#out + 1] = value
    end
  end
  return out
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

local function _resolve_contiguous_rent(board, tile_id, owner_id)
  if owner_id == nil or board == nil then
    return nil
  end
  local rents = contiguous_count.build_rent_for_owner(board, owner_id, function(tile)
    return tile_rent.for_level(tile, tile and tile.level or 0)
  end)
  local rent = rents[tile_id]
  if rent and rent > 0 then
    return rent
  end
  return nil
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
  local contiguous_rent = _resolve_contiguous_rent(board, tile_id, owner_id)
  tile_renderer.render_tile(tile_unit, tile_id, owner_id, owner_name, level, contiguous_rent)
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

local _norm_tiles = {}
local _norm_tiles_seen = {}
local _norm_overlays = {}
local _norm_overlays_seen = {}
local _norm_owners = {}
local _norm_owners_seen = {}
local _normalized = { tile_ids = _norm_tiles, overlay_indices = _norm_overlays, affected_owner_ids = _norm_owners }

local function _normalize_payload(payload)
  payload = payload or {}
  _normalized.tile_ids = _dedupe_into(payload.tile_ids, _norm_tiles, _norm_tiles_seen)
  _normalized.overlay_indices = _dedupe_into(payload.overlay_indices, _norm_overlays, _norm_overlays_seen)
  _normalized.affected_owner_ids = _dedupe_into(payload.affected_owner_ids, _norm_owners, _norm_owners_seen)
  return _normalized
end

local _expand_owner_set = {}
local _expand_tile_ids = {}
local function _expand_affected_tiles(state, owner_ids)
  for k in pairs(_expand_tile_ids) do _expand_tile_ids[k] = nil end
  if not owner_ids or #owner_ids == 0 then
    return _expand_tile_ids
  end
  local board = _resolve_board(state)
  if not (board and type(board.path) == "table") then
    return _expand_tile_ids
  end
  for k in pairs(_expand_owner_set) do _expand_owner_set[k] = nil end
  for _, owner_id in ipairs(owner_ids) do
    _expand_owner_set[owner_id] = true
  end
  for _, tile in ipairs(board.path) do
    if tile and tile.type == "land" and tile.owner_id and _expand_owner_set[tile.owner_id] then
      _expand_tile_ids[#_expand_tile_ids + 1] = tile.id
    end
  end
  return _expand_tile_ids
end

local _sync_seen = {}

local function _sync_tile_dedup(state, tile_ids)
  local handled = false
  for _, tile_id in ipairs(tile_ids) do
    if tile_id ~= nil and not _sync_seen[tile_id] then
      _sync_seen[tile_id] = true
      if visual_sync.sync_tile_visual(state, tile_id) then handled = true end
    end
  end
  return handled
end

local function _sync_overlays(state, indices)
  local handled = false
  for _, board_index in ipairs(indices) do
    if visual_sync.sync_overlay_visual(state, board_index) then
      handled = true
    end
  end
  return handled
end

function visual_sync.sync_many(state, payload)
  local normalized = _normalize_payload(payload)
  for k in pairs(_sync_seen) do _sync_seen[k] = nil end
  local handled = _sync_tile_dedup(state, normalized.tile_ids)
  if _sync_tile_dedup(state, _expand_affected_tiles(state, normalized.affected_owner_ids)) then
    handled = true
  end
  if _sync_overlays(state, normalized.overlay_indices) then
    handled = true
  end
  return handled
end

return visual_sync

--[[ mutate4lua-manifest
version=2
projectHash=b73bed1d41e1ba71
scope.0.id=chunk:src/ui/render/board/visual_sync.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=279
scope.0.semanticHash=3244cb5ec5ecdecc
scope.1.id=function:_has_pending_trigger_anim:34
scope.1.kind=function
scope.1.startLine=34
scope.1.endLine=49
scope.1.semanticHash=c64f87d15881d642
scope.2.id=function:_deps:66
scope.2.kind=function
scope.2.startLine=66
scope.2.endLine=68
scope.2.semanticHash=8972a7f932e00b0f
scope.3.id=function:_resolve_board:70
scope.3.kind=function
scope.3.startLine=70
scope.3.endLine=73
scope.3.semanticHash=6a668276745376f2
scope.4.id=function:_resolve_scene:75
scope.4.kind=function
scope.4.startLine=75
scope.4.endLine=77
scope.4.semanticHash=5d4d8299cf6431e0
scope.5.id=function:_resolve_tile_unit:79
scope.5.kind=function
scope.5.startLine=79
scope.5.endLine=89
scope.5.semanticHash=bd87a79fb1bb7d82
scope.6.id=function:_spawn_roadblock_overlay:91
scope.6.kind=function
scope.6.startLine=91
scope.6.endLine=102
scope.6.semanticHash=eaeb5d1ae603381f
scope.7.id=function:_spawn_mine_overlay:104
scope.7.kind=function
scope.7.startLine=104
scope.7.endLine=114
scope.7.semanticHash=e57a1de1cc599b42
scope.8.id=function:_resolve_contiguous_count:116
scope.8.kind=function
scope.8.startLine=116
scope.8.endLine=125
scope.8.semanticHash=77e94cc72291c77d
scope.9.id=function:_sync_owner_visual:127
scope.9.kind=function
scope.9.startLine=127
scope.9.endLine=144
scope.9.semanticHash=b6f41f0ab5b23a99
scope.10.id=function:_sync_building_visual:146
scope.10.kind=function
scope.10.startLine=146
scope.10.endLine=163
scope.10.semanticHash=eff623d96007f398
scope.11.id=function:visual_sync.sync_tile_visual:165
scope.11.kind=function
scope.11.startLine=165
scope.11.endLine=182
scope.11.semanticHash=d2ab91c7c6321eea
scope.12.id=function:visual_sync.sync_overlay_visual:184
scope.12.kind=function
scope.12.startLine=184
scope.12.endLine=210
scope.12.semanticHash=44814c86db18b13f
scope.13.id=function:_normalize_payload:220
scope.13.kind=function
scope.13.startLine=220
scope.13.endLine=226
scope.13.semanticHash=2bd0c165cdf35b21
]]
