require "Config.RuntimeConstants"

local prefab = require("Data.Prefab")
local logger = require("src.core.Logger")

local action_anim = {}

local durations = {
  roll = 1.0,
  roadblock = 0.8,
  mine = 0.8,
  missile = 1.2,
  monster = 1.2,
  clear_obstacles = 1.0,
}

local function _build_tip(anim)
  local kind = anim.kind
  if kind == "roll" then
    local rolls = anim.rolls and table.concat(anim.rolls, ",") or "?"
    local total = anim.total or "?"
    return "投骰动画：" .. rolls .. " => " .. total
  end
  if kind == "roadblock" then
    return "路障动画：放置在格子 " .. tostring(anim.tile_index or "?")
  end
  if kind == "mine" then
    return "地雷动画：埋设在格子 " .. tostring(anim.tile_index or "?")
  end
  if kind == "missile" then
    return "导弹动画：轰炸格子 " .. tostring(anim.tile_index or "?")
  end
  if kind == "monster" then
    return "怪兽动画：破坏格子 " .. tostring(anim.tile_index or "?")
  end
  if kind == "clear_obstacles" then
    local count = anim.cleared_indices and #anim.cleared_indices or 0
    return "清障动画：清除数量 " .. tostring(count)
  end
  return "动作动画"
end

local function _resolve_tile_pos(state, tile_index)
  assert(state ~= nil, "missing state")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local tiles = assert(scene.tiles, "missing scene.tiles")
  local tile = assert(tiles[tile_index], "missing tile unit: " .. tostring(tile_index))
  assert(tile.get_position ~= nil, "missing tile.get_position: " .. tostring(tile_index))
  return tile.get_position()
end

local function _ensure_overlays(scene)
  if not scene.overlay_units then
    scene.overlay_units = { roadblocks = {}, mines = {} }
  end
  return scene.overlay_units
end

local function _get_overlay_bucket(overlays, kind)
  if kind == "roadblock" then
    return overlays.roadblocks
  end
  if kind == "mine" then
    return overlays.mines
  end
  return nil
end

local function _spawn_unit_group(group_id, pos)
  assert(group_id ~= nil, "missing group_id")
  assert(pos ~= nil, "missing pos")
  assert(GameAPI ~= nil and GameAPI.create_unit_group ~= nil, "missing GameAPI.create_unit_group")
  return GameAPI.create_unit_group(group_id, pos, q_zero)
end

local function _spawn_unit(unit_id, pos)
  assert(unit_id ~= nil, "missing unit_id")
  assert(pos ~= nil, "missing pos")
  assert(GameAPI ~= nil and GameAPI.create_unit_with_scale ~= nil, "missing GameAPI.create_unit_with_scale")
  return GameAPI.create_unit_with_scale(unit_id, pos, q_zero, v3_one)
end

local function _destroy_unit(entry)
  if not entry or not entry.handle then
    return
  end
  if entry.kind == "group" then
    if GameAPI and GameAPI.destroy_unit_with_children then
      GameAPI.destroy_unit_with_children(entry.handle, true)
    end
    return
  end
  if GameAPI and GameAPI.destroy_unit then
    GameAPI.destroy_unit(entry.handle)
  end
end

function action_anim.clear_overlay(state, kind, tile_index)
  assert(state ~= nil, "missing state")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local overlays = _ensure_overlays(scene)
  local bucket = _get_overlay_bucket(overlays, kind)
  if not bucket then
    return
  end
  local entry = bucket[tile_index]
  if not entry then
    return
  end
  _destroy_unit(entry)
  bucket[tile_index] = nil
end

local function _spawn_overlay(state, kind, tile_index, group_id, unit_id)
  assert(state ~= nil, "missing state")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local overlays = _ensure_overlays(scene)
  local bucket = _get_overlay_bucket(overlays, kind)
  if not bucket then
    return false
  end
  if bucket[tile_index] then
    action_anim.clear_overlay(state, kind, tile_index)
  end
  local pos = _resolve_tile_pos(state, tile_index) + math.Vector3(0.0, 1.0, 0.0)
  if group_id then
    local handle = _spawn_unit_group(group_id, pos)
    bucket[tile_index] = { kind = "group", handle = handle }
    return true
  end
  if unit_id then
    local handle = _spawn_unit(unit_id, pos)
    bucket[tile_index] = { kind = "unit", handle = handle }
    return true
  end
  return false
end

local function _spawn_transient(group_id, unit_id, pos, duration)
  if not group_id and not unit_id then
    return
  end
  local entry
  if group_id then
    entry = { kind = "group", handle = _spawn_unit_group(group_id, pos) }
  else
    entry = { kind = "unit", handle = _spawn_unit(unit_id, pos) }
  end
  if duration and duration > 0 then
    SetTimeOut(duration, function()
      _destroy_unit(entry)
    end)
  else
    _destroy_unit(entry)
  end
end

function action_anim.play(state, anim)
  assert(anim ~= nil, "missing anim")
  assert(state ~= nil, "missing state")
  local duration = anim.duration or durations[anim.kind] or 1.0
  local tip_duration = duration
  if type(duration) == "number" and math and math.tofixed then
    tip_duration = math.tofixed(duration)
  end
  GlobalAPI.show_tips(_build_tip(anim), tip_duration)

  local kind = anim.kind
  if kind == "roadblock" then
    local tile_index = assert(anim.tile_index, "missing roadblock tile_index")
    local group_id = prefab.group["路障"]
    local unit_id = prefab.unit and prefab.unit["路障"] or nil
    _spawn_overlay(state, "roadblock", tile_index, group_id, unit_id)
  elseif kind == "mine" then
    local tile_index = assert(anim.tile_index, "missing mine tile_index")
    local group_id = prefab.group["地雷"]
    local unit_id = prefab.unit and prefab.unit["地雷"] or nil
    if not group_id and not unit_id then
      GlobalAPI.show_tips("缺少地雷 prefab，跳过生成", 1.5)
      logger.warn("[Eggy]", "地雷 prefab 缺失，已跳过生成")
    else
      _spawn_overlay(state, "mine", tile_index, group_id, unit_id)
    end
  elseif kind == "missile" then
    local tile_index = assert(anim.tile_index, "missing missile tile_index")
    action_anim.clear_overlay(state, "roadblock", tile_index)
    action_anim.clear_overlay(state, "mine", tile_index)
    local unit_id = prefab.unit and prefab.unit["导弹"] or nil
    local group_id = prefab.group["导弹"]
    local pos = _resolve_tile_pos(state, tile_index) + math.Vector3(0.0, 1.0, 0.0)
    _spawn_transient(group_id, unit_id, pos, duration)
  elseif kind == "clear_obstacles" then
    local cleared = anim.cleared_indices or {}
    for _, idx in ipairs(cleared) do
      action_anim.clear_overlay(state, "roadblock", idx)
      action_anim.clear_overlay(state, "mine", idx)
    end
    local player_id = assert(anim.player_id, "missing clear_obstacles player_id")
    local game = assert(state.game, "missing state.game")
    local player = assert(game.players[player_id], "missing player: " .. tostring(player_id))
    local pos = _resolve_tile_pos(state, player.position) + math.Vector3(0.0, 1.0, 0.0)
    local robot_id = prefab.group["清障机器人"]
    _spawn_transient(robot_id, nil, pos, duration)
  end

  return duration
end

return action_anim

