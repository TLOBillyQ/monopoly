local prefab = require("Data.Prefab")
local overlay_runtime = require("src.ui.render.anim.overlay_runtime")
local overlay_compute = require("src.ui.render.anim.overlay_compute")
local shared = require("src.ui.render.board.visual_sync_shared")

local visual_sync_overlay = {}

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

local function _spawn_roadblock_overlay(state, idx)
  return overlay_runtime.spawn_overlay(
    assert(shared.resolve_scene(state), "missing board_scene"),
    "roadblock",
    idx,
    nil,
    prefab.unit and prefab.unit["路障"] or nil,
    overlay_compute.overlay_pos_for_tile(state, idx),
    roadblock_scale,
    shared.deps(state)
  )
end

local function _spawn_mine_overlay(state, idx)
  return overlay_runtime.spawn_overlay(
    assert(shared.resolve_scene(state), "missing board_scene"),
    "mine",
    idx,
    prefab.group["地雷"],
    prefab.unit and prefab.unit["地雷"] or nil,
    overlay_compute.overlay_pos_for_tile(state, idx),
    shared.deps(state)
  )
end

function visual_sync_overlay.sync_overlay_visual(state, board_index)
  if board_index == nil then
    return false
  end
  local board = shared.resolve_board(state)
  local scene = shared.resolve_scene(state)
  if not (board and scene) then
    return false
  end

  local has_roadblock = board:has_roadblock(board_index)
  local has_mine = board:has_mine(board_index)

  if has_roadblock then
    _spawn_roadblock_overlay(state, board_index)
  elseif not _has_pending_trigger_anim(state, "roadblock", board_index) then
    overlay_runtime.clear_overlay(scene, "roadblock", board_index, shared.deps(state))
  end

  if has_mine then
    _spawn_mine_overlay(state, board_index)
  elseif not _has_pending_trigger_anim(state, "mine", board_index) then
    overlay_runtime.clear_overlay(scene, "mine", board_index, shared.deps(state))
  end

  return true
end

return visual_sync_overlay

--[[ mutate4lua-manifest
version=2
projectHash=6f15738cdadb686b
scope.0.id=chunk:src/ui/render/board/visual_sync_overlay.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=102
scope.0.semanticHash=1f304d2193ddebf7
scope.0.lastMutatedAt=2026-07-07T02:48:02Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=20
scope.0.lastMutationKilled=20
scope.1.id=function:_has_pending_trigger_anim:31
scope.1.kind=function
scope.1.startLine=31
scope.1.endLine=46
scope.1.semanticHash=c64f87d15881d642
scope.1.lastMutatedAt=2026-07-07T02:48:02Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=14
scope.1.lastMutationKilled=13
scope.2.id=function:_spawn_roadblock_overlay:48
scope.2.kind=function
scope.2.startLine=48
scope.2.endLine=59
scope.2.semanticHash=c53d3a2c5c50309f
scope.2.lastMutatedAt=2026-07-07T02:48:02Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:_spawn_mine_overlay:61
scope.3.kind=function
scope.3.startLine=61
scope.3.endLine=71
scope.3.semanticHash=d4dd860096c9ff1a
scope.3.lastMutatedAt=2026-07-07T02:48:02Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:visual_sync_overlay.sync_overlay_visual:73
scope.4.kind=function
scope.4.startLine=73
scope.4.endLine=99
scope.4.semanticHash=b1739890a1c71266
scope.4.lastMutatedAt=2026-07-07T02:48:02Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=18
scope.4.lastMutationKilled=18
]]
