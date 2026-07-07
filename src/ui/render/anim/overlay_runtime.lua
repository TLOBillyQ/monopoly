local runtime_constants = require("src.config.gameplay.runtime_constants")
local host_runtime_resolver = require("src.ui.render.host_runtime_resolver")

local runtime = {}

local _resolve_host_runtime = host_runtime_resolver.from_state

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
  if type(host_runtime.acquire_unit) == "function" then
    local handle = host_runtime.acquire_unit(unit_id, pos, runtime_constants.q_zero, scale or runtime_constants.v3_one)
    return handle, handle ~= nil
  end
  return host_runtime.create_unit_with_scale(
    unit_id,
    pos,
    runtime_constants.q_zero,
    scale or runtime_constants.v3_one
  ), false
end

local function _destroy_unit(host_runtime, entry)
  if not entry or not entry.handle then
    return
  end
  if entry.kind == "group" then
    host_runtime.destroy_unit_with_children(entry.handle, true)
    return
  end
  if entry.pooled and type(host_runtime.release_unit) == "function" then
    host_runtime.release_unit(entry.unit_id, entry.handle)
    return
  end
  host_runtime.destroy_unit(entry.handle)
end

local function _spawn_entry(host_runtime, group_id, unit_id, pos, scale)
  if group_id then
    local handle = _spawn_unit_group(host_runtime, group_id, pos)
    if not handle then
      return nil
    end
    return { kind = "group", handle = handle }
  end
  if unit_id then
    local handle, pooled = _spawn_unit(host_runtime, unit_id, pos, scale)
    if not handle then
      return nil
    end
    return { kind = "unit", handle = handle, unit_id = unit_id, pooled = pooled }
  end
  return nil
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

local function _clear_bucket_entry(host_runtime, bucket, tile_index)
  local entry = bucket[tile_index]
  if not entry then
    return
  end
  _destroy_unit(host_runtime, entry)
  bucket[tile_index] = nil
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
  _clear_bucket_entry(host_runtime, bucket, tile_index)

  local entry = _spawn_entry(host_runtime, group_id, unit_id, pos, scale)
  if entry == nil then
    return false
  end
  bucket[tile_index] = entry
  return true
end

function runtime.spawn_transient(group_id, unit_id, pos, duration, deps)
  if not group_id and not unit_id then
    return
  end
  local host_runtime = _resolve_host_runtime(deps and deps.scene or nil, deps)
  local entry = _spawn_entry(host_runtime, group_id, unit_id, pos)
  if not entry then
    return
  end
  _schedule_transient_destroy(host_runtime, entry, duration)
end

return runtime

--[[ mutate4lua-manifest
version=2
projectHash=b11b3941d0f09488
scope.0.id=chunk:src/ui/render/anim/overlay_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=151
scope.0.semanticHash=a36a9ed5abfa2f03
scope.0.lastMutatedAt=2026-07-07T03:30:24Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:_ensure_overlays:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=f6dfc618d0956bbd
scope.1.lastMutatedAt=2026-07-07T03:30:24Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_get_overlay_bucket:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=23
scope.2.semanticHash=5d80abb3d86710e4
scope.2.lastMutatedAt=2026-07-07T03:30:24Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_spawn_unit_group:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=29
scope.3.semanticHash=7588314b75dd8ab0
scope.3.lastMutatedAt=2026-07-07T03:30:24Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:_spawn_unit:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=44
scope.4.semanticHash=cd6f49713b050808
scope.4.lastMutatedAt=2026-07-07T03:30:24Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=survived
scope.4.lastMutationSites=9
scope.4.lastMutationKilled=8
scope.5.id=function:_destroy_unit:46
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=59
scope.5.semanticHash=6e56d5c37a11295e
scope.5.lastMutatedAt=2026-07-07T03:30:24Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=12
scope.5.lastMutationKilled=10
scope.6.id=function:_spawn_entry:61
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=77
scope.6.semanticHash=dc5a8b68ea092603
scope.6.lastMutatedAt=2026-07-07T03:30:24Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=survived
scope.6.lastMutationSites=6
scope.6.lastMutationKilled=5
scope.7.id=function:anonymous@81:81
scope.7.kind=function
scope.7.startLine=81
scope.7.endLine=83
scope.7.semanticHash=279a5c4ddd49c5b9
scope.7.lastMutatedAt=2026-07-07T03:30:24Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=no_sites
scope.7.lastMutationSites=0
scope.7.lastMutationKilled=0
scope.8.id=function:_schedule_transient_destroy:79
scope.8.kind=function
scope.8.startLine=79
scope.8.endLine=87
scope.8.semanticHash=ac4786cace59b8b3
scope.8.lastMutatedAt=2026-07-07T03:30:24Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=5
scope.8.lastMutationKilled=5
scope.9.id=function:_clear_bucket_entry:89
scope.9.kind=function
scope.9.startLine=89
scope.9.endLine=96
scope.9.semanticHash=4231cfd4b4421761
scope.9.lastMutatedAt=2026-07-07T03:30:24Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=2
scope.9.lastMutationKilled=2
scope.10.id=function:runtime.clear_overlay:98
scope.10.kind=function
scope.10.startLine=98
scope.10.endLine=114
scope.10.semanticHash=682565b85520bbeb
scope.10.lastMutatedAt=2026-07-07T03:30:24Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=9
scope.10.lastMutationKilled=9
scope.11.id=function:runtime.spawn_overlay:116
scope.11.kind=function
scope.11.startLine=116
scope.11.endLine=136
scope.11.semanticHash=e09ddd14d4683738
scope.11.lastMutatedAt=2026-07-07T03:30:24Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=14
scope.11.lastMutationKilled=14
scope.12.id=function:runtime.spawn_transient:138
scope.12.kind=function
scope.12.startLine=138
scope.12.endLine=148
scope.12.semanticHash=af69407f9ad3d8eb
scope.12.lastMutatedAt=2026-07-07T03:30:24Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=7
scope.12.lastMutationKilled=7
]]
