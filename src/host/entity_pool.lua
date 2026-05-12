local unit_lifecycle = require("src.host.units")
local number_utils = require("src.foundation.lang.number")
local logger = require("src.foundation.log.logger")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local entity_pool = {}

local _buckets = {}
local _max_idle = runtime_constants.entity_pool_max_idle

local function _bucket(unit_key)
  if not _buckets[unit_key] then
    _buckets[unit_key] = { idle = {}, live = 0, peak = 0, miss = 0 }
  end
  return _buckets[unit_key]
end

local function _call_method(handle, name, ...)
  if handle == nil then return false end
  local ok, method = pcall(function()
    return handle[name]
  end)
  if not ok or type(method) ~= "function" then return false end
  local called = pcall(method, ...)
  return called == true
end

function entity_pool.acquire(unit_key, pos, rotation, scale)
  if unit_key == nil or pos == nil then return nil end
  local b = _bucket(unit_key)
  local handle
  if #b.idle > 0 then
    handle = table.remove(b.idle)
    _call_method(handle, "set_position", pos)
    _call_method(handle, "set_orientation", rotation)
    _call_method(handle, "set_world_scale", scale)
    _call_method(handle, "set_model_visible", true)
  else
    b.miss = b.miss + 1
    handle = unit_lifecycle.create_unit_with_scale(unit_key, pos, rotation, scale)
    if handle == nil then
      logger.warn("[entity_pool]", "create_unit_with_scale returned nil for key=" .. tostring(unit_key))
      return nil
    end
  end
  b.live = b.live + 1
  if number_utils.is_numeric(b.live) and number_utils.is_numeric(b.peak) and b.live > b.peak then
    b.peak = b.live
  end
  return handle
end

function entity_pool.release(unit_key, handle)
  if unit_key == nil or handle == nil then return end
  local b = _bucket(unit_key)
  _call_method(handle, "set_model_visible", false)
  _call_method(handle, "set_position", runtime_constants.entity_pool_park_pos)
  if #b.idle < _max_idle then
    b.idle[#b.idle + 1] = handle
  else
    unit_lifecycle.destroy_unit(handle)
  end
  if number_utils.is_numeric(b.live) and b.live > 0 then
    b.live = b.live - 1
  end
end

function entity_pool.prewarm(unit_key, count, rotation, scale, sample_pos)
  if unit_key == nil then return end
  if not number_utils.is_numeric(count) or count <= 0 then return end
  local b = _bucket(unit_key)
  local park = runtime_constants.entity_pool_park_pos
  local pos = sample_pos or park
  local to_create = count - #b.idle
  for _ = 1, to_create do
    if #b.idle >= _max_idle then break end
    local handle = unit_lifecycle.create_unit_with_scale(unit_key, pos, rotation, scale)
    if handle then
      _call_method(handle, "set_model_visible", false)
      _call_method(handle, "set_position", park)
      b.idle[#b.idle + 1] = handle
    end
  end
end

function entity_pool.stats()
  local snapshot = {}
  for unit_key, b in pairs(_buckets) do
    snapshot[unit_key] = {
      idle = #b.idle,
      live = b.live,
      peak = b.peak,
      miss = b.miss,
    }
  end
  return snapshot
end

function entity_pool.reset()
  for _, b in pairs(_buckets) do
    for _, handle in ipairs(b.idle) do
      unit_lifecycle.destroy_unit(handle)
    end
    b.idle = {}
  end
end

return entity_pool
