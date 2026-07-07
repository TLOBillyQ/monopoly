local prefab = require("Data.Prefab")
local logger = require("src.foundation.log")
local compute = require("src.ui.render.anim.overlay_compute")
local runtime = require("src.ui.render.anim.overlay_runtime")
local robot = require("src.ui.render.anim.unit_overlay_robot")

local host_types = require("src.foundation.host_types")

local overlay = {}
local roadblock_scale = host_types.vec3(4.0, 4.0, 4.0)

local _deps = robot.resolve_presentation_runtime

local function _play_roadblock(state, tile_index)
  local unit_id = prefab.unit and prefab.unit["路障"] or nil
  runtime.spawn_overlay(
    assert(state.board_scene, "missing board_scene"),
    "roadblock",
    tile_index,
    nil,
    unit_id,
    compute.overlay_pos_for_tile(state, tile_index),
    roadblock_scale,
    _deps(state)
  )
end

local function _play_mine(state, tile_index)
  local group_id = prefab.group["地雷"]
  local unit_id = prefab.unit and prefab.unit["地雷"] or nil
  if not group_id and not unit_id then
    logger.warn("[Eggy]", "地雷 prefab 缺失，已跳过生成")
    return
  end
  -- 地雷贴近地面生成 (y_offset = 0.05)
  runtime.spawn_overlay(assert(state.board_scene, "missing board_scene"), "mine", tile_index, group_id, unit_id,
    compute.overlay_pos_for_tile(state, tile_index, 0.05), nil, _deps(state))
end

function overlay.clear_overlay(state, kind, tile_index)
  assert(state ~= nil, "missing state")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  runtime.clear_overlay(assert(state.board_scene, "missing board_scene"), kind, tile_index, _deps(state))
end

function overlay.play_overlay(state, anim, duration, opts)
  local tile_index = assert(anim.tile_index, "missing tile_index")
  if anim.kind == "roadblock" then
    return _play_roadblock(state, tile_index)
  end
  if anim.kind == "mine" then
    return _play_mine(state, tile_index)
  end
end

function overlay.play_missile(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local tile_index = assert(anim.tile_index, "missing missile tile_index")
  robot.clear_obstacle(state, clear_overlay, tile_index)
  local unit_id = prefab.unit and prefab.unit["导弹"] or nil
  local group_id = prefab.group["导弹"]
  runtime.spawn_transient(group_id, unit_id, compute.overlay_pos_for_tile(state, tile_index), duration, _deps(state))
end

overlay.play_clear_obstacles = robot.play_clear_obstacles

return overlay

--[[ mutate4lua-manifest
version=2
projectHash=78ddf4b475afc5b2
scope.0.id=chunk:src/ui/render/anim/unit_overlay.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=71
scope.0.semanticHash=c746f60fb492b02d
scope.1.id=function:_deps:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=14
scope.1.semanticHash=8972a7f932e00b0f
scope.2.id=function:_play_roadblock:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=28
scope.2.semanticHash=a6bf6167f6d2ea2b
scope.3.id=function:_play_mine:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=40
scope.3.semanticHash=5140ad2eb7b93e58
scope.4.id=function:overlay.clear_overlay:42
scope.4.kind=function
scope.4.startLine=42
scope.4.endLine=47
scope.4.semanticHash=79e023776af2956f
scope.5.id=function:overlay.play_overlay:49
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=57
scope.5.semanticHash=a10d48e8e15113d5
scope.6.id=function:overlay.play_missile:59
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=66
scope.6.semanticHash=329e655ebe735361
]]
