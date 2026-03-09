local logger = require("src.core.utils.logger")
local runtime_constants = require("src.core.config.runtime_constants")
local host_runtime = require("src.presentation.runtime.host")

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
  return host_runtime.create_unit_group(group_id, pos, runtime_constants.q_zero)
end

local function _spawn_unit(unit_id, pos, scale)
  assert(unit_id ~= nil, "missing unit_id")
  assert(pos ~= nil, "missing pos")
  return host_runtime.create_unit_with_scale(
    unit_id,
    pos,
    runtime_constants.q_zero,
    scale or runtime_constants.v3_one
  )
end

local function _destroy_unit(entry)
  if not entry or not entry.handle then
    return
  end
  if entry.kind == "group" then
    host_runtime.destroy_unit_with_children(entry.handle, true)
    return
  end
  host_runtime.destroy_unit(entry.handle)
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

function runtime.spawn_overlay(scene, kind, tile_index, group_id, unit_id, pos, scale)
  assert(scene ~= nil, "missing board_scene")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  assert(pos ~= nil, "missing pos")

  logger.info_unlimited(
    "[OverlayDebug]",
    "spawn_overlay request",
    "kind=" .. tostring(kind),
    "tile_index=" .. tostring(tile_index),
    "group_id=" .. tostring(group_id),
    "unit_id=" .. tostring(unit_id)
  )

  local overlays = _ensure_overlays(scene)
  local bucket = _get_overlay_bucket(overlays, kind)
  if not bucket then
    logger.warn(
      "[OverlayDebug]",
      "spawn_overlay missing bucket",
      "kind=" .. tostring(kind),
      "tile_index=" .. tostring(tile_index)
    )
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
      logger.info_unlimited(
        "[OverlayDebug]",
        "spawn_overlay success",
        "kind=" .. tostring(kind),
        "tile_index=" .. tostring(tile_index),
        "spawn_kind=group"
      )
      return true
    end
    logger.warn(
      "[OverlayDebug]",
      "spawn_overlay group failed",
      "kind=" .. tostring(kind),
      "tile_index=" .. tostring(tile_index),
      "group_id=" .. tostring(group_id)
    )
    return false
  end
  if unit_id then
    local handle = _spawn_unit(unit_id, pos, scale)
    if handle then
      bucket[tile_index] = { kind = "unit", handle = handle }
      logger.info_unlimited(
        "[OverlayDebug]",
        "spawn_overlay success",
        "kind=" .. tostring(kind),
        "tile_index=" .. tostring(tile_index),
        "spawn_kind=unit"
      )
      return true
    end
    logger.warn(
      "[OverlayDebug]",
      "spawn_overlay unit failed",
      "kind=" .. tostring(kind),
      "tile_index=" .. tostring(tile_index),
      "unit_id=" .. tostring(unit_id)
    )
    return false
  end
  logger.warn(
    "[OverlayDebug]",
    "spawn_overlay skipped because no prefab id resolved",
    "kind=" .. tostring(kind),
    "tile_index=" .. tostring(tile_index)
  )
  return false
end

function runtime.spawn_transient(group_id, unit_id, pos, duration)
  if not group_id and not unit_id then
    logger.warn("[OverlayDebug]", "spawn_transient skipped because no prefab id resolved")
    return
  end
  logger.info_unlimited(
    "[OverlayDebug]",
    "spawn_transient request",
    "group_id=" .. tostring(group_id),
    "unit_id=" .. tostring(unit_id),
    "duration=" .. tostring(duration)
  )
  local entry
  if group_id then
    local handle = _spawn_unit_group(group_id, pos)
    if not handle then
      logger.warn(
        "[OverlayDebug]",
        "spawn_transient group failed",
        "group_id=" .. tostring(group_id)
      )
      return
    end
    entry = { kind = "group", handle = handle }
  else
    local handle = _spawn_unit(unit_id, pos)
    if not handle then
      logger.warn(
        "[OverlayDebug]",
        "spawn_transient unit failed",
        "unit_id=" .. tostring(unit_id)
      )
      return
    end
    entry = { kind = "unit", handle = handle }
  end
  logger.info_unlimited(
    "[OverlayDebug]",
    "spawn_transient success",
    "entry_kind=" .. tostring(entry.kind),
    "duration=" .. tostring(duration)
  )

  if duration and duration > 0 then
    host_runtime.schedule(duration, function()
      _destroy_unit(entry)
    end)
    return
  end
  _destroy_unit(entry)
end

return runtime
