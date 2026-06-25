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
  function role:get_attr_raw_fixed(attr_id)
    return attrs[attr_id]
  end
  function role:set_attr_raw_fixed(attr_id, value)
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
  local role, getter = _resolve_coin_role(player)
  local ok, value = pcall(getter, role, _COIN_COUNT_ATTR_ID)
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
  local role, _, setter = _resolve_coin_role(player)
  local ok, result = pcall(setter, role, _COIN_COUNT_ATTR_ID, amount)
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
