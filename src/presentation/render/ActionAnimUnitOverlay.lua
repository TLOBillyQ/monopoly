local prefab = require("Data.Prefab")
local logger = require("src.core.Logger")
local runtime_constants = require("Config.RuntimeConstants")

local overlay = {}

local function _resolve_tile_pos(state, tile_index)
  assert(state ~= nil, "missing state")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local tiles = assert(scene.tiles, "missing scene.tiles")
  local tile = assert(tiles[tile_index], "missing tile unit: " .. tostring(tile_index))
  assert(tile.get_position ~= nil, "missing tile.get_position: " .. tostring(tile_index))
  return tile.get_position()
end

local function _resolve_vector_value(vec, key, index)
  if type(vec) ~= "table" then
    return nil
  end
  return vec[key] or vec[index]
end

local function _offset_pos(pos, offset)
  local ok, result = pcall(function()
    return pos + offset
  end)
  if ok then
    return result
  end
  local pos_x = _resolve_vector_value(pos, "x", 1) or 0
  local pos_y = _resolve_vector_value(pos, "y", 2) or 0
  local pos_z = _resolve_vector_value(pos, "z", 3) or 0
  local offset_x = _resolve_vector_value(offset, "x", 1) or 0
  local offset_y = _resolve_vector_value(offset, "y", 2) or 0
  local offset_z = _resolve_vector_value(offset, "z", 3) or 0
  if math and math.Vector3 then
    return math.Vector3(pos_x + offset_x, pos_y + offset_y, pos_z + offset_z)
  end
  return pos
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
  if not (GameAPI ~= nil and GameAPI.create_unit_group ~= nil) then
    return nil, "missing GameAPI.create_unit_group"
  end
  return GameAPI.create_unit_group(group_id, pos, runtime_constants.q_zero)
end

local function _spawn_unit(unit_id, pos)
  assert(unit_id ~= nil, "missing unit_id")
  assert(pos ~= nil, "missing pos")
  if not (GameAPI ~= nil and GameAPI.create_unit_with_scale ~= nil) then
    return nil, "missing GameAPI.create_unit_with_scale"
  end
  return GameAPI.create_unit_with_scale(unit_id, pos, runtime_constants.q_zero, runtime_constants.v3_one)
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
    _destroy_unit(bucket[tile_index])
    bucket[tile_index] = nil
  end
  local pos = _offset_pos(_resolve_tile_pos(state, tile_index), math.Vector3(0.0, 1.0, 0.0))
  if group_id then
    local handle = _spawn_unit_group(group_id, pos)
    if handle then
      bucket[tile_index] = { kind = "group", handle = handle }
      return true
    end
    logger.warn("[ActionAnim]", "create_unit_group missing, skip overlay")
    return false
  end
  if unit_id then
    local handle = _spawn_unit(unit_id, pos)
    if handle then
      bucket[tile_index] = { kind = "unit", handle = handle }
      return true
    end
    logger.warn("[ActionAnim]", "create_unit_with_scale missing, skip overlay")
    return false
  end
  return false
end

local function _spawn_transient(group_id, unit_id, pos, duration)
  if not group_id and not unit_id then
    return
  end
  local entry
  if group_id then
    local handle = _spawn_unit_group(group_id, pos)
    if not handle then
      logger.warn("[ActionAnim]", "create_unit_group missing, skip transient")
      return
    end
    entry = { kind = "group", handle = handle }
  else
    local handle = _spawn_unit(unit_id, pos)
    if not handle then
      logger.warn("[ActionAnim]", "create_unit_with_scale missing, skip transient")
      return
    end
    entry = { kind = "unit", handle = handle }
  end
  if duration and duration > 0 then
    SetTimeOut(duration, function()
      _destroy_unit(entry)
    end)
  else
    _destroy_unit(entry)
  end
end

function overlay.clear_overlay(state, kind, tile_index)
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

function overlay.play_overlay(state, anim, opts)
  local kind = anim.kind
  local tile_index = assert(anim.tile_index, "missing tile_index")
  local overlay_kind = kind
  if kind == "roadblock" then
    local group_id = prefab.group["路障"]
    local unit_id = prefab.unit and prefab.unit["路障"] or nil
    _spawn_overlay(state, overlay_kind, tile_index, group_id, unit_id)
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
    _spawn_overlay(state, overlay_kind, tile_index, group_id, unit_id)
  end
end

function overlay.play_missile(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local tile_index = assert(anim.tile_index, "missing missile tile_index")
  clear_overlay(state, "roadblock", tile_index)
  clear_overlay(state, "mine", tile_index)
  local unit_id = prefab.unit and prefab.unit["导弹"] or nil
  local group_id = prefab.group["导弹"]
  local pos = _offset_pos(_resolve_tile_pos(state, tile_index), math.Vector3(0.0, 1.0, 0.0))
  _spawn_transient(group_id, unit_id, pos, duration)
end

function overlay.play_clear_obstacles(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local cleared = anim.cleared_indices or {}
  for _, idx in ipairs(cleared) do
    clear_overlay(state, "roadblock", idx)
    clear_overlay(state, "mine", idx)
  end
  local player_id = assert(anim.player_id, "missing clear_obstacles player_id")
  local game = assert(state.game, "missing state.game")
  local player = assert(game:find_player_by_id(player_id), "missing player: " .. tostring(player_id))
  local pos = _offset_pos(_resolve_tile_pos(state, player.position), math.Vector3(0.0, 1.0, 0.0))
  local robot_id = prefab.group["清障机器人"]
  _spawn_transient(robot_id, nil, pos, duration)
end

return overlay
