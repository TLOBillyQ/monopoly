local prefab = require("Data.Prefab")
local logger = require("src.core.utils.logger")
local compute = require("src.ui.render.anim_overlay_compute")
local runtime = require("src.ui.render.anim_overlay_runtime")
local host_runtime_bridge = require("src.ui.runtime.host_bridge")
local runtime_constants = require("src.config.gameplay.runtime_constants")

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
  local robot_id = prefab.group["清障机器人"]
  local player_pos = compute.overlay_pos_for_player(state, assert(anim.player_id, "missing player_id"))
  local hr = _resolve_hr(_deps(state))
  for _, branch in ipairs(branches) do
    hr.create_unit_group(robot_id, player_pos, runtime_constants.q_zero)
    for _, entry in ipairs(branch) do
      if entry.has_obstacle then
        clear_overlay(state, "roadblock", entry.tile_index)
        clear_overlay(state, "mine", entry.tile_index)
      end
    end
  end
end

return overlay
