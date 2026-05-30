local unit_lifecycle = require("src.host.units")
local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")
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

local function _access_field(obj, key)
  return obj[key]
end

local function _call_method(handle, name, ...)
  if handle == nil then return false end
  local ok, method = pcall(_access_field, handle, name)
  if not ok or type(method) ~= "function" then return false end
  return (pcall(method, ...))
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

local function _return_or_destroy(b, handle)
  if #b.idle < _max_idle then
    b.idle[#b.idle + 1] = handle
  else
    unit_lifecycle.destroy_unit(handle)
  end
end

function entity_pool.release(unit_key, handle)
  if unit_key == nil or handle == nil then return end
  local b = _bucket(unit_key)
  _call_method(handle, "set_model_visible", false)
  _call_method(handle, "set_position", runtime_constants.entity_pool_park_pos)
  _return_or_destroy(b, handle)
  if number_utils.is_numeric(b.live) and b.live > 0 then
    b.live = b.live - 1
  end
end

local function _valid_prewarm_args(unit_key, count)
  return unit_key ~= nil and number_utils.is_numeric(count) and count > 0
end

local function _prewarm_one(unit_key, b, pos, rotation, scale)
  if #b.idle >= _max_idle then return false end
  local handle = unit_lifecycle.create_unit_with_scale(unit_key, pos, rotation, scale)
  if not handle then return true end
  _call_method(handle, "set_model_visible", false)
  _call_method(handle, "set_position", runtime_constants.entity_pool_park_pos)
  b.idle[#b.idle + 1] = handle
  return true
end

local function _fill_prewarm(unit_key, b, count, pos, rotation, scale)
  for _ = 1, count - #b.idle do
    if not _prewarm_one(unit_key, b, pos, rotation, scale) then break end
  end
end

function entity_pool.prewarm(unit_key, count, rotation, scale, sample_pos)
  if not _valid_prewarm_args(unit_key, count) then return end
  local b = _bucket(unit_key)
  _fill_prewarm(unit_key, b, count, sample_pos or runtime_constants.entity_pool_park_pos, rotation, scale)
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

--[[ mutate4lua-manifest
version=2
projectHash=48936cbf4de3207e
scope.0.id=chunk:src/host/entity_pool.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=122
scope.0.semanticHash=a38916ddd132edac
scope.1.id=function:_bucket:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=16
scope.1.semanticHash=44348a51b5895dfa
scope.2.id=function:_access_field:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=e28a6b558e3f7cfb
scope.3.id=function:_call_method:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=27
scope.3.semanticHash=b622853e0a9d4ecd
scope.4.id=function:entity_pool.acquire:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=52
scope.4.semanticHash=e5698bb69fca8842
scope.5.id=function:_return_or_destroy:54
scope.5.kind=function
scope.5.startLine=54
scope.5.endLine=60
scope.5.semanticHash=f879c33241019c59
scope.6.id=function:entity_pool.release:62
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=71
scope.6.semanticHash=8a684cb37d1f9c14
scope.7.id=function:_valid_prewarm_args:73
scope.7.kind=function
scope.7.startLine=73
scope.7.endLine=75
scope.7.semanticHash=65691f00b5bfc400
scope.8.id=function:_prewarm_one:77
scope.8.kind=function
scope.8.startLine=77
scope.8.endLine=85
scope.8.semanticHash=b09c80104a612674
scope.9.id=function:entity_pool.prewarm:93
scope.9.kind=function
scope.9.startLine=93
scope.9.endLine=97
scope.9.semanticHash=509cfeebab9acc72
]]
