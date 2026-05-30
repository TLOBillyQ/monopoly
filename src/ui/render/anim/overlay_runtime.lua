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

local function _clear_bucket_entry(host_runtime, bucket, tile_index)
  local entry = bucket[tile_index]
  if not entry then
    return
  end
  _destroy_unit(host_runtime, entry)
  bucket[tile_index] = nil
end

local function _spawn_overlay_entry(host_runtime, group_id, unit_id, pos, scale)
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
    return { handle = handle, pooled = pooled, unit_id = unit_id }
  end
  return nil
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

  local entry = _spawn_overlay_entry(host_runtime, group_id, unit_id, pos, scale)
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
  local entry = _spawn_transient_entry(host_runtime, group_id, unit_id, pos)
  if not entry then
    return
  end
  _schedule_transient_destroy(host_runtime, entry, duration)
end

return runtime

--[[ mutate4lua-manifest
version=2
projectHash=a5fc99a6213a2006
scope.0.id=chunk:src/ui/render/anim/overlay_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=166
scope.0.semanticHash=515cb0ab7e510074
scope.1.id=function:_ensure_overlays:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=f6dfc618d0956bbd
scope.2.id=function:_get_overlay_bucket:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=23
scope.2.semanticHash=5d80abb3d86710e4
scope.3.id=function:_spawn_unit_group:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=29
scope.3.semanticHash=7588314b75dd8ab0
scope.4.id=function:_spawn_unit:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=44
scope.4.semanticHash=cd6f49713b050808
scope.5.id=function:_destroy_unit:46
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=59
scope.5.semanticHash=6e56d5c37a11295e
scope.6.id=function:_spawn_transient_entry:61
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=74
scope.6.semanticHash=6716433a222a6fbd
scope.7.id=function:anonymous@78:78
scope.7.kind=function
scope.7.startLine=78
scope.7.endLine=80
scope.7.semanticHash=279a5c4ddd49c5b9
scope.8.id=function:_schedule_transient_destroy:76
scope.8.kind=function
scope.8.startLine=76
scope.8.endLine=84
scope.8.semanticHash=ac4786cace59b8b3
scope.9.id=function:_clear_bucket_entry:86
scope.9.kind=function
scope.9.startLine=86
scope.9.endLine=93
scope.9.semanticHash=4231cfd4b4421761
scope.10.id=function:_spawn_overlay_entry:95
scope.10.kind=function
scope.10.startLine=95
scope.10.endLine=111
scope.10.semanticHash=d1eaaaab3fb8e195
scope.11.id=function:runtime.clear_overlay:113
scope.11.kind=function
scope.11.startLine=113
scope.11.endLine=129
scope.11.semanticHash=682565b85520bbeb
scope.12.id=function:runtime.spawn_overlay:131
scope.12.kind=function
scope.12.startLine=131
scope.12.endLine=151
scope.12.semanticHash=a6a21733a8f9fcd7
scope.13.id=function:runtime.spawn_transient:153
scope.13.kind=function
scope.13.startLine=153
scope.13.endLine=163
scope.13.semanticHash=a8fc77fd7e538450
]]
