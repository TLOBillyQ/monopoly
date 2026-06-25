local runtime_ports = require("src.foundation.ports.runtime_ports")
local coin_validation = require("src.player.actions.coin_validation")

local coin_store = {}

local _COIN_COUNT_ATTR_ID = coin_validation.COIN_COUNT_ATTR_ID
local _fail = coin_validation.fail
local _validate_coin_amount = coin_validation.validate_amount

local function _new_memory_coin_role(initial)
  local attrs = {}
  if initial ~= nil then
    attrs[_COIN_COUNT_ATTR_ID] = initial
  end
  local role = {}
  function role.get_attr_raw_fixed(first, second)
    local attr_id = first == role and second or first
    return attrs[attr_id]
  end
  function role.set_attr_raw_fixed(first, second, third)
    local attr_id = first == role and second or first
    local value = first == role and third or second
    attrs[attr_id] = value
    return true
  end
  return role
end

local function _role_method(role, method_name)
  local fn = role and role[method_name] or nil
  if type(fn) ~= "function" then
    return nil
  end
  return fn
end

local function _role_with_coin_methods(role)
  local getter = _role_method(role, "get_attr_raw_fixed")
  local setter = _role_method(role, "set_attr_raw_fixed")
  if getter ~= nil and setter ~= nil then
    return role, getter, setter
  end
  return nil, getter, setter
end

local function _runtime_role_for(player)
  if player and player.id ~= nil then
    return runtime_ports.resolve_role(player.id)
  end
  return nil
end

local function _resolve_coin_role(player)
  local runtime_role = _runtime_role_for(player)
  local role, getter, setter = _role_with_coin_methods(runtime_role)
  if role ~= nil then
    return role, getter, setter
  end

  local player_role = player and player._coin_role or nil
  role, getter, setter = _role_with_coin_methods(player_role)
  if role ~= nil then
    return role, getter, setter
  end

  if runtime_role == nil and player_role == nil then
    _fail(player, "缺少Role")
  end
  _fail(player, "缺少get_attr_raw_fixed或set_attr_raw_fixed")
end

local function _read_coin_raw(player)
  local _, getter = _resolve_coin_role(player)
  local ok, value = pcall(getter, _COIN_COUNT_ATTR_ID)
  if not ok then
    _fail(player, "读取失败: " .. tostring(value))
  end
  return value
end

local function _read_coin_count(player)
  local value = _read_coin_raw(player)
  if value == nil then
    _fail(player, "未初始化")
  end
  return _validate_coin_amount(player, value, "读取值")
end

local function _try_write_coin_count(player, amount)
  amount = _validate_coin_amount(player, amount, "写入值")
  local _, _, setter = _resolve_coin_role(player)
  local ok, result = pcall(setter, _COIN_COUNT_ATTR_ID, amount)
  if not ok then
    return false, tostring(result)
  end
  if result ~= true then
    return false, "set_attr_raw_fixed返回" .. tostring(result)
  end
  return true, amount
end

coin_store.new_memory_coin_role = _new_memory_coin_role
coin_store.read_raw = _read_coin_raw
coin_store.read_count = _read_coin_count
coin_store.try_write = _try_write_coin_count

return coin_store

--[[ mutate4lua-manifest
version=2
projectHash=aaa767136a5ddbc2
scope.0.id=chunk:src/player/actions/coin_store.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=105
scope.0.semanticHash=5e7898686daec6bc
scope.0.lastMutatedAt=2026-06-25T01:26:15Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:role:get_attr_raw_fixed:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=a5111437773c2111
scope.2.id=function:role:set_attr_raw_fixed:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=22
scope.2.semanticHash=64e50de392ba27b8
scope.2.lastMutatedAt=2026-06-25T01:26:15Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:_new_memory_coin_role:10
scope.3.kind=function
scope.3.startLine=10
scope.3.endLine=24
scope.3.semanticHash=6445a504abcd8d70
scope.3.lastMutatedAt=2026-06-25T01:26:15Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:_role_method:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=32
scope.4.semanticHash=dff565a64608c82b
scope.4.lastMutatedAt=2026-06-25T01:26:15Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
scope.5.id=function:_role_with_coin_methods:34
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=41
scope.5.semanticHash=5c4badb7b6881f9d
scope.5.lastMutatedAt=2026-06-25T01:26:15Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=5
scope.6.id=function:_runtime_role_for:43
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=48
scope.6.semanticHash=95b9d5e139e598d9
scope.6.lastMutatedAt=2026-06-25T01:26:15Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=survived
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=2
scope.7.id=function:_resolve_coin_role:50
scope.7.kind=function
scope.7.startLine=50
scope.7.endLine=67
scope.7.semanticHash=49965f6b87c326e8
scope.7.lastMutatedAt=2026-06-25T01:26:15Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=12
scope.7.lastMutationKilled=12
scope.8.id=function:_read_coin_raw:69
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=76
scope.8.semanticHash=8d059d5cabf208ff
scope.8.lastMutatedAt=2026-06-25T01:26:15Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=4
scope.8.lastMutationKilled=4
scope.9.id=function:_read_coin_count:78
scope.9.kind=function
scope.9.startLine=78
scope.9.endLine=84
scope.9.semanticHash=b9da02209ff650d2
scope.9.lastMutatedAt=2026-06-25T01:26:15Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=4
scope.9.lastMutationKilled=4
scope.10.id=function:_try_write_coin_count:86
scope.10.kind=function
scope.10.startLine=86
scope.10.endLine=97
scope.10.semanticHash=da2c4c41879ac2aa
scope.10.lastMutatedAt=2026-06-25T01:26:15Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=12
scope.10.lastMutationKilled=12
]]
