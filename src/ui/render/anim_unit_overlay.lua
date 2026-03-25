local prefab = require("Data.Prefab")
local logger = require("src.core.utils.logger")
local compute = require("src.ui.render.anim_overlay_compute")
local runtime = require("src.ui.render.anim_overlay_runtime")
local host_runtime_bridge = require("src.ui.runtime.host_bridge")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local number_utils = require("src.core.utils.number_utils")

local overlay = {}
local roadblock_scale = (function()
  if math and math.Vector3 then
    return math.Vector3(4.0, 4.0, 4.0)
  end
  return { x = 4.0, y = 4.0, z = 4.0 }
end)()

local function _deps(state)
  return state and state.presentation_runtime or nil
end

local function _resolve_hr(deps)
  if deps and deps.host_runtime then return deps.host_runtime end
  return host_runtime_bridge
end

local function _call_handle_method(handle, method_name, ...)
  if type(handle) ~= "table" then
    return false
  end
  local method = handle[method_name]
  if type(method) ~= "function" then
    return false
  end
  method(...)
  return true
end

local function _spawn_robot(hr, robot_id, pos)
  if type(hr.create_unit_group) ~= "function" then
    return nil
  end
  return hr.create_unit_group(robot_id, pos, runtime_constants.q_zero)
end

local function _destroy_robot(hr, handle)
  if handle == nil then
    return
  end
  if type(hr.destroy_unit_with_children) == "function" then
    hr.destroy_unit_with_children(handle, true)
    return
  end
  if type(hr.destroy_unit) == "function" then
    hr.destroy_unit(handle)
  end
end

local function _move_robot(hr, robot_id, handle, pos)
  if _call_handle_method(handle, "set_position_smooth", pos) then
    return handle
  end
  if _call_handle_method(handle, "set_position", pos) then
    return handle
  end
  _destroy_robot(hr, handle)
  return _spawn_robot(hr, robot_id, pos)
end

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

local function _clear_obstacle(state, clear_overlay, tile_index)
  clear_overlay(state, "roadblock", tile_index)
  clear_overlay(state, "mine", tile_index)
end

local function _walk_branch_children(state, clear_overlay, schedule, hr, robot_id, node, current_pos, step_duration)
  local children = node.children or {}
  if #children == 0 then
    return function(handle)
      _destroy_robot(hr, handle)
    end
  end

  return function(handle)
    for child_index, child in ipairs(children) do
      local child_handle = handle
      if child_index > 1 then
        child_handle = _spawn_robot(hr, robot_id, current_pos)
      end
      _schedule_step(schedule, step_duration, function()
        local child_pos = compute.overlay_pos_for_tile(state, child.tile_index)
        local moved_handle = _move_robot(hr, robot_id, child_handle, child_pos)
        if child.has_obstacle then
          _clear_obstacle(state, clear_overlay, child.tile_index)
        end
        _walk_branch_children(state, clear_overlay, schedule, hr, robot_id, child, child_pos, step_duration)(moved_handle)
      end)
    end
  end
end

function overlay.clear_overlay(state, kind, tile_index)
  assert(state ~= nil, "missing state")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  runtime.clear_overlay(assert(state.board_scene, "missing board_scene"), kind, tile_index, _deps(state))
end

function overlay.play_overlay(state, anim, duration, opts)
  local kind = anim.kind
  local tile_index = assert(anim.tile_index, "missing tile_index")
  local overlay_kind = kind
  if kind == "roadblock" then
    local unit_id = prefab.unit and prefab.unit["路障"] or nil
    runtime.spawn_overlay(
      assert(state.board_scene, "missing board_scene"),
      overlay_kind,
      tile_index,
      nil,
      unit_id,
      compute.overlay_pos_for_tile(state, tile_index),
      roadblock_scale,
      _deps(state)
    )
    return
  end
  if kind == "mine" then
    local group_id = prefab.group["地雷"]
    local unit_id = prefab.unit and prefab.unit["地雷"] or nil
    if not group_id and not unit_id then
      if opts and opts.show_tip then
        opts.show_tip("缺少地雷 prefab，跳过生成", 1.5)
      end
      logger.warn("[Eggy]", "地雷 prefab 缺失，已跳过生成")
      return
    end
    runtime.spawn_overlay(assert(state.board_scene, "missing board_scene"), overlay_kind, tile_index, group_id, unit_id,
      compute.overlay_pos_for_tile(state, tile_index), nil, _deps(state))
    return
  end
end

function overlay.play_missile(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local tile_index = assert(anim.tile_index, "missing missile tile_index")
  clear_overlay(state, "roadblock", tile_index)
  clear_overlay(state, "mine", tile_index)
  local unit_id = prefab.unit and prefab.unit["导弹"] or nil
  local group_id = prefab.group["导弹"]
  runtime.spawn_transient(group_id, unit_id, compute.overlay_pos_for_tile(state, tile_index), duration, _deps(state))
end

function overlay.play_monster(_state, _anim, _duration, _opts)
end

function overlay.play_clear_obstacles(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local branches = anim.branches or {}
  if #branches == 0 then
    return
  end
  local robot_id = prefab.group["清障机器人"]
  local player_pos = compute.overlay_pos_for_player(state, assert(anim.player_id, "missing player_id"))
  local hr = _resolve_hr(_deps(state))
  local schedule = opts.schedule or hr.schedule
  local step_duration = _resolve_step_duration(branches, duration)
  local branch_tree = _build_branch_tree(branches)
  local root_handle = _spawn_robot(hr, robot_id, player_pos)
  _walk_branch_children(state, clear_overlay, schedule, hr, robot_id, branch_tree, player_pos, step_duration)(root_handle)
end

return overlay
