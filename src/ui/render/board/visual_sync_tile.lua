local building_effects = require("src.ui.render.building_effects")
local tile_renderer = require("src.ui.render.tile")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local contiguous_count = require("src.ui.view.contiguous_count")
local tile_rent = require("src.ui.view.tile_rent")
local shared = require("src.ui.render.board.visual_sync_shared")

local visual_sync_tile = {}

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

local function _resolve_owner_name(state, owner_id)
  if not owner_id then
    return nil
  end
  local game = state and state.game or nil
  if not (game and type(game.find_player_by_id) == "function") then
    return nil
  end
  local player = game:find_player_by_id(owner_id)
  return player and player.name or nil
end

local function _sync_owner_visual(state, tile_unit, tile_id, board)
  if tile_unit == nil then
    return
  end
  local tile = board:get_tile_by_id(tile_id)
  local owner_id = tile and tile.owner_id or nil
  local level = tile and tile.level or 0
  local owner_name = _resolve_owner_name(state, owner_id)
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
      shared.deps(state)
    ) or tile_unit ~= nil
  end
  building_effects.clear_building_units(scene, idx, shared.deps(state))
  return true
end

function visual_sync_tile.sync_tile_visual(state, tile_id)
  if tile_id == nil then
    return false
  end
  local board = shared.resolve_board(state)
  local scene = shared.resolve_scene(state)
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

return visual_sync_tile

--[[ mutate4lua-manifest
version=2
projectHash=186c147d7d8d988a
scope.0.id=chunk:src/ui/render/board/visual_sync_tile.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=99
scope.0.semanticHash=376b564270bbe712
scope.0.lastMutatedAt=2026-07-07T02:48:20Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=6
scope.0.lastMutationKilled=6
scope.1.id=function:_resolve_tile_unit:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=20
scope.1.semanticHash=bd87a79fb1bb7d82
scope.1.lastMutatedAt=2026-07-07T02:48:20Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=12
scope.1.lastMutationKilled=12
scope.2.id=function:anonymous@26:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=28
scope.2.semanticHash=dc3439c0ecf96c9a
scope.3.id=function:_resolve_contiguous_rent:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=34
scope.3.semanticHash=b85555259e1ccd7e
scope.3.lastMutatedAt=2026-07-07T02:48:20Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=survived
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=6
scope.4.id=function:_resolve_owner_name:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=46
scope.4.semanticHash=719601e6852aa98e
scope.4.lastMutatedAt=2026-07-07T02:48:20Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=11
scope.4.lastMutationKilled=11
scope.5.id=function:_sync_owner_visual:48
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=58
scope.5.semanticHash=6cd2712b0bcd7476
scope.5.lastMutatedAt=2026-07-07T02:48:20Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=10
scope.5.lastMutationKilled=10
scope.6.id=function:_sync_building_visual:60
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=77
scope.6.semanticHash=81ae16a63e80ed58
scope.6.lastMutatedAt=2026-07-07T02:48:20Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=15
scope.6.lastMutationKilled=15
scope.7.id=function:visual_sync_tile.sync_tile_visual:79
scope.7.kind=function
scope.7.startLine=79
scope.7.endLine=96
scope.7.semanticHash=2d011183da8f3835
scope.7.lastMutatedAt=2026-07-07T02:48:20Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=17
scope.7.lastMutationKilled=17
]]
