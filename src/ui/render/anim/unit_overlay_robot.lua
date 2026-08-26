local prefab = require("Data.Prefab")
local logger = require("src.foundation.log")
local compute = require("src.ui.render.anim.overlay_compute")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local number_utils = require("src.foundation.number")
local handle_ops = require("src.ui.render.anim.unit_overlay_handle")

local robot = {}
-- #339:y_offset 1.0 在真机被地板埋没(机器人看不见),2.0 是段B 探针肉眼验证过的高度。
local robot_y_offset = 2.0

function robot.resolve_presentation_runtime(state)
  return state and state.presentation_runtime or nil
end

local _resolve_hr = require("src.ui.render.support.host_runtime_resolver").from_deps

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

-- 向 cursor 下插入一条分支记录:已存在则合并障碍标记,返回(可能新建的)子节点。
local function _insert_branch_entry(cursor, entry)
  local key = tostring(entry.tile_index)
  local child = cursor.child_map[key]
  if child == nil then
    child = _new_branch_node(entry.tile_index, entry.has_obstacle)
    cursor.child_map[key] = child
    cursor.children[#cursor.children + 1] = child
  elseif entry.has_obstacle then
    child.has_obstacle = true
  end
  return child
end

local function _build_branch_tree(branches)
  local root = _new_branch_node(nil, false)
  for _, branch in ipairs(branches or {}) do
    local cursor = root
    for _, entry in ipairs(branch or {}) do
      cursor = _insert_branch_entry(cursor, entry)
    end
  end
  return root
end

local function _resolve_longest_branch(branches)
  -- 负分支数种子 + math.max:`longest = 0` 的 0->1 与 `#branch > longest` 的
  -- >->>= 逐值等价不可杀(全空分支时步长无消费者);-#branches 是最长值的
  -- 安全下界且无数字位点(删负号会变步长,可杀)(#262 化简)。
  local longest = -#branches
  for _, branch in ipairs(branches or {}) do
    longest = math.max(longest, #branch)
  end
  return longest
end

-- 前置条件:分支树有子节点(调用方已拦全空分支),longest ≥ 1。
local function _resolve_step_duration(branches, duration)
  if number_utils.is_numeric(duration) and duration > 0 then
    return duration / _resolve_longest_branch(branches)
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

local function _play_empty_clear(hr, robot_id, schedule, player_pos, duration)
  local root_handle = _spawn_robot(hr, robot_id, player_pos)
  _schedule_step(schedule, duration, function()
    _destroy_robot(hr, robot_id, root_handle)
  end)
end

local function _play_branches(state, clear_overlay, schedule, hr, robot_id, branches, player_pos, duration)
  local branch_tree = _build_branch_tree(branches)
  -- #339:不走池化,去掉 prewarm 预热(直接 create,无需预填池)。
  local root_handle = _spawn_robot(hr, robot_id, player_pos)
  if #branch_tree.children == 0 then
    -- 全空分支没有步进,步长无消费者,直接销毁(#262:这也封死了
    -- longest==0 分支上的一切等价变异)。
    _destroy_robot(hr, robot_id, root_handle)
    return
  end
  local step_duration = _resolve_step_duration(branches, duration)
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
version=4
projectHash=73a041b80a29a67d
scope.0.id=chunk:src/ui/render/anim/unit_overlay_robot.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=162
scope.0.semanticHash=718a3ecc6e507d25
scope.1.id=function:robot.resolve_presentation_runtime
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=14
scope.1.semanticHash=616a2ca60599c94f
scope.2.id=function:_new_branch_node
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=29
scope.2.semanticHash=6e0439c4b9c6954c
scope.3.id=function:_insert_branch_entry
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=43
scope.3.semanticHash=62e2c22ed5b2480f
scope.4.id=function:_build_branch_tree
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=54
scope.4.semanticHash=3d8ee52ac0bd37bf
scope.5.id=function:_resolve_longest_branch
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=65
scope.5.semanticHash=239fe5cc35ea3232
scope.6.id=function:_resolve_step_duration
scope.6.kind=function
scope.6.startLine=68
scope.6.endLine=73
scope.6.semanticHash=0bc1a15ad4303973
scope.7.id=function:_schedule_step
scope.7.kind=function
scope.7.startLine=75
scope.7.endLine=81
scope.7.semanticHash=e56cd9ee75281d99
scope.8.id=function:robot.clear_obstacle
scope.8.kind=function
scope.8.startLine=83
scope.8.endLine=86
scope.8.semanticHash=7eaf7d2796156f7f
scope.9.id=function:_walk_branch_children
scope.9.kind=function
scope.9.startLine=88
scope.9.endLine=112
scope.9.semanticHash=43c061878b6d980d
scope.10.id=function:<anonymous>
scope.10.kind=function
scope.10.startLine=91
scope.10.endLine=93
scope.10.semanticHash=11e97ffd44326f60
scope.11.id=function:<anonymous>#2
scope.11.kind=function
scope.11.startLine=96
scope.11.endLine=111
scope.11.semanticHash=2a1c8186f703f7b8
scope.12.id=function:<anonymous>#3
scope.12.kind=function
scope.12.startLine=102
scope.12.endLine=109
scope.12.semanticHash=aa7cdb4f0c98b41e
scope.13.id=function:_resolve_robot_id
scope.13.kind=function
scope.13.startLine=114
scope.13.endLine=116
scope.13.semanticHash=463772d087024a7c
scope.14.id=function:_resolve_schedule
scope.14.kind=function
scope.14.startLine=118
scope.14.endLine=120
scope.14.semanticHash=49a3d9630b738acf
scope.15.id=function:_play_empty_clear
scope.15.kind=function
scope.15.startLine=122
scope.15.endLine=127
scope.15.semanticHash=6a5fc455c8f25733
scope.16.id=function:<anonymous>#4
scope.16.kind=function
scope.16.startLine=124
scope.16.endLine=126
scope.16.semanticHash=4ac65c65acb92f3b
scope.17.id=function:_play_branches
scope.17.kind=function
scope.17.startLine=129
scope.17.endLine=141
scope.17.semanticHash=d95d0fd0dd2d51c2
scope.18.id=function:robot.play_clear_obstacles
scope.18.kind=function
scope.18.startLine=143
scope.18.endLine=159
scope.18.semanticHash=26e82c19d47c9df8
]]
