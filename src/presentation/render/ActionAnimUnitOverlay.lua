local prefab = require("Data.Prefab")
local logger = require("src.core.utils.Logger")
local compute = require("src.presentation.render.ActionAnimOverlayCompute")
local runtime = require("src.presentation.render.ActionAnimOverlayRuntime")

local overlay = {}
local roadblock_scale = (function()
  if math and math.Vector3 then
    return math.Vector3(4.0, 4.0, 4.0)
  end
  return { x = 4.0, y = 4.0, z = 4.0 }
end)()

function overlay.clear_overlay(state, kind, tile_index)
  assert(state ~= nil, "missing state")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  runtime.clear_overlay(assert(state.board_scene, "missing board_scene"), kind, tile_index)
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
      roadblock_scale
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
      compute.overlay_pos_for_tile(state, tile_index))
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
  runtime.spawn_transient(group_id, unit_id, compute.overlay_pos_for_tile(state, tile_index), duration)
end

function overlay.play_clear_obstacles(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local cleared = anim.cleared_indices or {}
  for _, idx in ipairs(cleared) do
    clear_overlay(state, "roadblock", idx)
    clear_overlay(state, "mine", idx)
  end
  local robot_id = prefab.group["清障机器人"]
  runtime.spawn_transient(robot_id, nil, compute.overlay_pos_for_player(state, assert(anim.player_id, "missing clear_obstacles player_id")), duration)
end

return overlay
