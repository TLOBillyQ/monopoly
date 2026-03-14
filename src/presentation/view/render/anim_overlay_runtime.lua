local runtime_constants = require("src.config.gameplay.runtime_constants")

local runtime = {}

local function _resolve_host_runtime(scene, deps)
  local resolved_deps = deps or scene and scene.presentation_runtime or nil
  if resolved_deps and resolved_deps.host_runtime then
    return resolved_deps.host_runtime
  end
  local loaded = package.loaded["src.host.eggy"]
  if loaded ~= nil then
    return loaded
  end
  error("missing deps.host_runtime")
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

local function _spawn_unit_group(host_runtime, group_id, pos)
  assert(group_id ~= nil, "missing group_id")
  assert(pos ~= nil, "missing pos")
  return host_runtime.create_unit_group(group_id, pos, runtime_constants.q_zero)
end

local function _spawn_unit(host_runtime, unit_id, pos, scale)
  assert(unit_id ~= nil, "missing unit_id")
  assert(pos ~= nil, "missing pos")
  return host_runtime.create_unit_with_scale(
    unit_id,
    pos,
    runtime_constants.q_zero,
    scale or runtime_constants.v3_one
  )
end

local function _destroy_unit(host_runtime, entry)
  if not entry or not entry.handle then
    return
  end
  if entry.kind == "group" then
    host_runtime.destroy_unit_with_children(entry.handle, true)
    return
  end
  host_runtime.destroy_unit(entry.handle)
end

local function _spawn_transient_entry(host_runtime, group_id, unit_id, pos)
  if group_id then
    local handle = _spawn_unit_group(host_runtime, group_id, pos)
    if not handle then
      return nil
    end
    return { kind = "group", handle = handle }
  end
  local handle = _spawn_unit(host_runtime, unit_id, pos)
  if not handle then
    return nil
  end
  return { kind = "unit", handle = handle }
end

local function _schedule_transient_destroy(host_runtime, entry, duration)
  if duration and duration > 0 then
    host_runtime.schedule(duration, function()
      _destroy_unit(host_runtime, entry)
    end)
    return
  end
  _destroy_unit(host_runtime, entry)
end

function runtime.clear_overlay(scene, kind, tile_index, deps)
  assert(scene ~= nil, "missing board_scene")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  local host_runtime = _resolve_host_runtime(scene, deps)
  local overlays = _ensure_overlays(scene)
  local bucket = _get_overlay_bucket(overlays, kind)
  if not bucket then
    return
  end
  local entry = bucket[tile_index]
  if not entry then
    return
  end
  _destroy_unit(host_runtime, entry)
  bucket[tile_index] = nil
end

function runtime.spawn_overlay(scene, kind, tile_index, group_id, unit_id, pos, scale, deps)
  assert(scene ~= nil, "missing board_scene")
  assert(kind ~= nil, "missing kind")
  assert(tile_index ~= nil, "missing tile_index")
  assert(pos ~= nil, "missing pos")

  local host_runtime = _resolve_host_runtime(scene, deps)
  local overlays = _ensure_overlays(scene)
  local bucket = _get_overlay_bucket(overlays, kind)
  if not bucket then
    return false
  end
  if bucket[tile_index] then
    _destroy_unit(host_runtime, bucket[tile_index])
    bucket[tile_index] = nil
  end

  if group_id then
    local handle = _spawn_unit_group(host_runtime, group_id, pos)
    if handle then
      bucket[tile_index] = { kind = "group", handle = handle }
      return true
    end
    return false
  end
  if unit_id then
    local handle = _spawn_unit(host_runtime, unit_id, pos, scale)
    if handle then
      bucket[tile_index] = { kind = "unit", handle = handle }
      return true
    end
    return false
  end
  return false
end

function runtime.spawn_transient(group_id, unit_id, pos, duration, deps)
  if not group_id and not unit_id then
    return
  end
  local host_runtime = _resolve_host_runtime(deps and deps.scene or nil, deps)
  local entry = _spawn_transient_entry(host_runtime, group_id, unit_id, pos)
  if not entry then
    return
  end
  _schedule_transient_destroy(host_runtime, entry, duration)
end

return runtime
