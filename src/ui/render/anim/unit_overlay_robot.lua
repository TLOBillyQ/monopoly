local prefab = require("Data.Prefab")
local logger = require("src.foundation.log")
local compute = require("src.ui.render.anim.overlay_compute")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local number_utils = require("src.foundation.number")
local host_types = require("src.foundation.host_types")
local handle_ops = require("src.ui.render.anim.unit_overlay_handle")

local robot = {}
local robot_scale = host_types.vec3(0.06, 0.94, 0.06)
local robot_y_offset = 1.0
local robot_rotation = host_types.quat(0.0, 0.0, 0.0)

function robot.resolve_presentation_runtime(state)
  return state and state.presentation_runtime or nil
end

local _resolve_hr = require("src.ui.render.host_runtime_resolver").from_deps

local _spawn_robot = handle_ops.spawn
local _destroy_robot = handle_ops.destroy
local _move_robot = handle_ops.move

local function _new_branch_node(tile_index, has_obstacle)
  return {
    tile_index = tile_index,
    has_obstacle = has_obstacle == true,
    children = {},
    child_map = {},
  }
end

local function _build_branch_tree(branches)
  local root = _new_branch_node(nil, false)
  for _, branch in ipairs(branches or {}) do
    local cursor = root
    for _, entry in ipairs(branch or {}) do
      local key = tostring(entry.tile_index)
      local child = cursor.child_map[key]
      if child == nil then
        child = _new_branch_node(entry.tile_index, entry.has_obstacle)
        cursor.child_map[key] = child
        cursor.children[#cursor.children + 1] = child
      elseif entry.has_obstacle then
        child.has_obstacle = true
      end
      cursor = child
    end
  end
  return root
end

local function _resolve_longest_branch(branches)
  local longest = 0
  for _, branch in ipairs(branches or {}) do
    if #branch > longest then
      longest = #branch
    end
  end
  return longest
end

local function _resolve_step_duration(branches, duration)
  local longest = _resolve_longest_branch(branches)
  if longest > 0 and number_utils.is_numeric(duration) and duration > 0 then
    return duration / longest
  end
  return 3.0 / runtime_constants.robot_speed
end

local function _schedule_step(schedule, delay, callback)
  if type(schedule) == "function" then
    schedule(delay, callback)
    return
  end
  callback()
end

function robot.clear_obstacle(state, clear_overlay, tile_index)
  clear_overlay(state, "roadblock", tile_index)
  clear_overlay(state, "mine", tile_index)
end

local function _walk_branch_children(state, clear_overlay, schedule, hr, robot_id, node, current_pos, step_duration)
  local children = node.children or {}
  if #children == 0 then
    return function(handle)
      _destroy_robot(hr, robot_id, handle)
    end
  end

  return function(handle)
    for child_index, child in ipairs(children) do
      local child_handle = handle
      if child_index > 1 then
        child_handle = _spawn_robot(hr, robot_id, current_pos)
      end
      _schedule_step(schedule, step_duration, function()
        local child_pos = compute.overlay_pos_for_tile(state, child.tile_index, robot_y_offset)
        local moved_handle = _move_robot(hr, robot_id, child_handle, child_pos)
        if child.has_obstacle then
          robot.clear_obstacle(state, clear_overlay, child.tile_index)
        end
        _walk_branch_children(state, clear_overlay, schedule, hr, robot_id, child, child_pos, step_duration)(moved_handle)
      end)
    end
  end
end

local function _resolve_robot_id()
  return prefab.unit and prefab.unit["清障机器人"] or nil
end

local function _resolve_schedule(opts, hr)
  return opts.schedule or hr.schedule
end

local function _maybe_prewarm(hr, robot_id, branches, player_pos)
  if type(hr.prewarm_unit) == "function" then
    hr.prewarm_unit(robot_id, 1 + #branches, robot_rotation, robot_scale, player_pos)
  end
end

local function _play_empty_clear(hr, robot_id, schedule, player_pos, duration)
  local root_handle = _spawn_robot(hr, robot_id, player_pos)
  _schedule_step(schedule, duration, function()
    _destroy_robot(hr, robot_id, root_handle)
  end)
end

local function _play_branches(state, clear_overlay, schedule, hr, robot_id, branches, player_pos, duration)
  local step_duration = _resolve_step_duration(branches, duration)
  local branch_tree = _build_branch_tree(branches)
  _maybe_prewarm(hr, robot_id, branches, player_pos)
  local root_handle = _spawn_robot(hr, robot_id, player_pos)
  _walk_branch_children(state, clear_overlay, schedule, hr, robot_id, branch_tree, player_pos, step_duration)(root_handle)
end

function robot.play_clear_obstacles(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local robot_id = _resolve_robot_id()
  if robot_id == nil then
    logger.warn("[Eggy]", "清障机器人 prefab 缺失，已跳过生成")
    return
  end
  local player_pos = compute.overlay_pos_for_player(state, assert(anim.player_id, "missing player_id"), robot_y_offset)
  local hr = _resolve_hr(robot.resolve_presentation_runtime(state))
  local schedule = _resolve_schedule(opts, hr)
  local branches = anim.branches or {}
  if #branches == 0 then
    _play_empty_clear(hr, robot_id, schedule, player_pos, duration)
    return
  end
  _play_branches(state, clear_overlay, schedule, hr, robot_id, branches, player_pos, duration)
end

return robot

--[[ mutate4lua-manifest
version=2
projectHash=d7004bb2c62e8890
scope.0.id=chunk:src/ui/render/anim/unit_overlay_robot.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=158
scope.0.semanticHash=0b130fc9baaf0e24
scope.0.lastMutatedAt=2026-07-07T02:46:49Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=25
scope.0.lastMutationKilled=23
scope.1.id=function:robot.resolve_presentation_runtime:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=16
scope.1.semanticHash=7ec8eba81ae37104
scope.1.lastMutatedAt=2026-07-07T02:46:49Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:_new_branch_node:24
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=31
scope.2.semanticHash=4e6ef1c4034ff4d9
scope.2.lastMutatedAt=2026-07-07T02:46:49Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:_resolve_step_duration:63
scope.3.kind=function
scope.3.startLine=63
scope.3.endLine=69
scope.3.semanticHash=91cb4ac4e1685b76
scope.3.lastMutatedAt=2026-07-07T02:46:49Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=survived
scope.3.lastMutationSites=10
scope.3.lastMutationKilled=9
scope.4.id=function:_schedule_step:71
scope.4.kind=function
scope.4.startLine=71
scope.4.endLine=77
scope.4.semanticHash=f7c71eaa0a3e9c36
scope.4.lastMutatedAt=2026-07-07T02:46:49Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
scope.5.id=function:robot.clear_obstacle:79
scope.5.kind=function
scope.5.startLine=79
scope.5.endLine=82
scope.5.semanticHash=bc8e4d6363984c26
scope.5.lastMutatedAt=2026-07-07T02:46:49Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:anonymous@87:87
scope.6.kind=function
scope.6.startLine=87
scope.6.endLine=89
scope.6.semanticHash=cedd51eae67c7396
scope.6.lastMutatedAt=2026-07-07T02:46:49Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:anonymous@98:98
scope.7.kind=function
scope.7.startLine=98
scope.7.endLine=105
scope.7.semanticHash=a6657482604be88a
scope.8.id=function:anonymous@92:92
scope.8.kind=function
scope.8.startLine=92
scope.8.endLine=108
scope.8.semanticHash=1947b8ca4a6b27ba
scope.8.lastMutatedAt=2026-07-07T02:46:49Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=5
scope.8.lastMutationKilled=5
scope.9.id=function:_resolve_robot_id:110
scope.9.kind=function
scope.9.startLine=110
scope.9.endLine=112
scope.9.semanticHash=86667b960903dcfa
scope.9.lastMutatedAt=2026-07-07T02:46:49Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=3
scope.9.lastMutationKilled=3
scope.10.id=function:_resolve_schedule:114
scope.10.kind=function
scope.10.startLine=114
scope.10.endLine=116
scope.10.semanticHash=74471c6a63a2eeeb
scope.10.lastMutatedAt=2026-07-07T02:46:49Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:_maybe_prewarm:118
scope.11.kind=function
scope.11.startLine=118
scope.11.endLine=122
scope.11.semanticHash=18ffb795f9f3f9ff
scope.11.lastMutatedAt=2026-07-07T02:46:49Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=4
scope.11.lastMutationKilled=4
scope.12.id=function:anonymous@126:126
scope.12.kind=function
scope.12.startLine=126
scope.12.endLine=128
scope.12.semanticHash=0aba74b0651c453b
scope.13.id=function:_play_empty_clear:124
scope.13.kind=function
scope.13.startLine=124
scope.13.endLine=129
scope.13.semanticHash=2bbba838235fad29
scope.13.lastMutatedAt=2026-07-07T02:46:49Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=2
scope.13.lastMutationKilled=2
scope.14.id=function:_play_branches:131
scope.14.kind=function
scope.14.startLine=131
scope.14.endLine=137
scope.14.semanticHash=0b72977dae965c91
scope.14.lastMutatedAt=2026-07-07T02:46:49Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=5
scope.14.lastMutationKilled=5
scope.15.id=function:robot.play_clear_obstacles:139
scope.15.kind=function
scope.15.startLine=139
scope.15.endLine=155
scope.15.semanticHash=df2ac9898bc535e2
scope.15.lastMutatedAt=2026-07-07T02:46:49Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=12
scope.15.lastMutationKilled=12
]]
