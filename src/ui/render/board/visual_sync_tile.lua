local building_effects = require("src.ui.render.board.building_effects")
local tile_renderer = require("src.ui.render.board.tile")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local contiguous_count = require("src.ui.view.contiguous_count")
local tile_rent = require("src.ui.view.tile_rent")
local shared = require("src.ui.render.board.visual_sync_shared")
local tables = require("src.foundation.tables")

local visual_sync_tile = {}

local function _scene_tiles(scene)
  return scene and scene.tiles or nil
end

local function _resolve_tile_unit(state, scene, idx)
  local tile_units = state and state.tile_units or nil
  local from_state = tables.at(tile_units, idx)
  if from_state ~= nil then
    return from_state
  end
  return tables.at(_scene_tiles(scene), idx)
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
projectHash=ff67a269322a90d3
scope.0.id=chunk:src/ui/render/board/visual_sync_tile.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=125
scope.0.semanticHash=765145573c6770ef
scope.1.id=function:_scene_tiles
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=616a2ca60599c94f
scope.2.id=function:_resolve_tile_unit
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=22
scope.2.semanticHash=78bf0620d982df2f
scope.3.id=function:_resolve_contiguous_rent
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=36
scope.3.semanticHash=f17ffd341f6fbf97
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=30
scope.4.semanticHash=73906ad2679f0f78
scope.5.id=function:_game_of
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=40
scope.5.semanticHash=616a2ca60599c94f
scope.6.id=function:_find_player_by_id
scope.6.kind=function
scope.6.startLine=42
scope.6.endLine=47
scope.6.semanticHash=1bd5be72b009cc8e
scope.7.id=function:_resolve_owner_name
scope.7.kind=function
scope.7.startLine=49
scope.7.endLine=55
scope.7.semanticHash=fa8801ebaacc5fb2
scope.8.id=function:_tile_owner_and_level
scope.8.kind=function
scope.8.startLine=57
scope.8.endLine=60
scope.8.semanticHash=8d50068d7c62f539
scope.9.id=function:_sync_owner_visual
scope.9.kind=function
scope.9.startLine=62
scope.9.endLine=70
scope.9.semanticHash=d7da935e3f3efff3
scope.10.id=function:_sync_building_level
scope.10.kind=function
scope.10.startLine=72
scope.10.endLine=85
scope.10.semanticHash=7a09a59632918525
scope.11.id=function:_sync_building_visual
scope.11.kind=function
scope.11.startLine=87
scope.11.endLine=94
scope.11.semanticHash=98d2da3d9513c566
scope.12.id=function:_board_and_scene
scope.12.kind=function
scope.12.startLine=97
scope.12.endLine=104
scope.12.semanticHash=a3164f602dbac9a8
scope.13.id=function:visual_sync_tile.sync_tile_visual
scope.13.kind=function
scope.13.startLine=106
scope.13.endLine=122
scope.13.semanticHash=3e2683e7d958efd1
]]
