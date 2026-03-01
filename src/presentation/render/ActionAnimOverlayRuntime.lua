local logger = require("src.core.Logger")
local runtime_constants = require("Config.RuntimeConstants")

local runtime = {}

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

function runtime.clear_overlay(scene, kind, tile_index)
  assert(scene ~= nil, "missing board_scene")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
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

function runtime.spawn_overlay(scene, kind, tile_index, group_id, unit_id, pos)
  assert(scene ~= nil, "missing board_scene")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  assert(pos ~= nil, "missing pos")

  local overlays = _ensure_overlays(scene)
  local bucket = _get_overlay_bucket(overlays, kind)
  if not bucket then
    return false
  end
  if bucket[tile_index] then
    _destroy_unit(bucket[tile_index])
    bucket[tile_index] = nil
  end

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

function runtime.spawn_transient(group_id, unit_id, pos, duration)
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
    return
  end
  _destroy_unit(entry)
end

return runtime
