local building_effects = require("src.ui.render.board.building_effects")
local tile_renderer = require("src.ui.render.board.tile")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local contiguous_count = require("src.ui.view.contiguous_count")
local tile_rent = require("src.ui.view.tile_rent")
local shared = require("src.ui.render.board.visual_sync_shared")

local visual_sync_tile = {}

local function _lookup_at(table, idx)
  if type(table) == "table" and table[idx] ~= nil then
    return table[idx]
  end
  return nil
end

local function _scene_tiles(scene)
  return scene and scene.tiles or nil
end

local function _resolve_tile_unit(state, scene, idx)
  local tile_units = state and state.tile_units or nil
  local from_state = _lookup_at(tile_units, idx)
  if from_state ~= nil then
    return from_state
  end
  return _lookup_at(_scene_tiles(scene), idx)
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

local function _game_of(state)
  return state and state.game or nil
end

local function _find_player_by_id(game, owner_id)
  if game and type(game.find_player_by_id) == "function" then
    return game:find_player_by_id(owner_id)
  end
  return nil
end

local function _resolve_owner_name(state, owner_id)
  if not owner_id then
    return nil
  end
  local player = _find_player_by_id(_game_of(state), owner_id)
  return player and player.name or nil
end

local function _tile_owner_and_level(board, tile_id)
  local tile = board:get_tile_by_id(tile_id)
  return tile and tile.owner_id or nil, tile and tile.level or 0
end

local function _sync_owner_visual(state, tile_unit, tile_id, board)
  if tile_unit == nil then
    return
  end
  local owner_id, level = _tile_owner_and_level(board, tile_id)
  local owner_name = _resolve_owner_name(state, owner_id)
  local contiguous_rent = _resolve_contiguous_rent(board, tile_id, owner_id)
  tile_renderer.render_tile(tile_unit, tile_id, owner_id, owner_name, level, contiguous_rent)
end

local function _sync_building_level(state, scene, idx, level, tile_unit)
  if level and level > 0 then
    local spawned = building_effects.spawn_upgrade_building_units(
      scene,
      assert(runtime_constants.q_zero, "missing Q_ZERO"),
      idx,
      level,
      shared.deps(state)
    )
    return spawned or tile_unit ~= nil
  end
  building_effects.clear_building_units(scene, idx, shared.deps(state))
  return true
end

local function _sync_building_visual(state, scene, idx, board, tile_id, tile_unit)
  local tile = board:get_tile_by_id(tile_id)
  local level = tile and tile.level or 0
  if not (scene.buildings and scene.building_unit_groups) then
    return tile_unit ~= nil
  end
  return _sync_building_level(state, scene, idx, level, tile_unit)
end

-- board + scene 且 board 可索引时才可同步;否则 (nil, nil)。
local function _board_and_scene(state)
  local board = shared.resolve_board(state)
  local scene = shared.resolve_scene(state)
  if not (board and scene and type(board.index_of_tile_id) == "function") then
    return nil, nil
  end
  return board, scene
end

function visual_sync_tile.sync_tile_visual(state, tile_id)
  if tile_id == nil then
    return false
  end
  local board, scene = _board_and_scene(state)
  if board == nil then
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

return visual_sync_tile

--[[ mutate4lua-manifest
version=4
projectHash=c6c28c1203ee61a4
scope.0.id=chunk:src/ui/render/board/visual_sync_tile.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=131
scope.0.semanticHash=c816f2af6f332711
scope.1.id=function:_lookup_at
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=15
scope.1.semanticHash=c8a72cd40cf0620d
scope.2.id=function:_scene_tiles
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=19
scope.2.semanticHash=616a2ca60599c94f
scope.3.id=function:_resolve_tile_unit
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=28
scope.3.semanticHash=78bf0620d982df2f
scope.4.id=function:_resolve_contiguous_rent
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=42
scope.4.semanticHash=f17ffd341f6fbf97
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=36
scope.5.semanticHash=73906ad2679f0f78
scope.6.id=function:_game_of
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=46
scope.6.semanticHash=616a2ca60599c94f
scope.7.id=function:_find_player_by_id
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=53
scope.7.semanticHash=1bd5be72b009cc8e
scope.8.id=function:_resolve_owner_name
scope.8.kind=function
scope.8.startLine=55
scope.8.endLine=61
scope.8.semanticHash=fa8801ebaacc5fb2
scope.9.id=function:_tile_owner_and_level
scope.9.kind=function
scope.9.startLine=63
scope.9.endLine=66
scope.9.semanticHash=8d50068d7c62f539
scope.10.id=function:_sync_owner_visual
scope.10.kind=function
scope.10.startLine=68
scope.10.endLine=76
scope.10.semanticHash=d7da935e3f3efff3
scope.11.id=function:_sync_building_level
scope.11.kind=function
scope.11.startLine=78
scope.11.endLine=91
scope.11.semanticHash=7a09a59632918525
scope.12.id=function:_sync_building_visual
scope.12.kind=function
scope.12.startLine=93
scope.12.endLine=100
scope.12.semanticHash=98d2da3d9513c566
scope.13.id=function:_board_and_scene
scope.13.kind=function
scope.13.startLine=103
scope.13.endLine=110
scope.13.semanticHash=a3164f602dbac9a8
scope.14.id=function:visual_sync_tile.sync_tile_visual
scope.14.kind=function
scope.14.startLine=112
scope.14.endLine=128
scope.14.semanticHash=3e2683e7d958efd1
]]
