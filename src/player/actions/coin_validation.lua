local number_utils = require("src.foundation.number")

local coin_validation = {}

coin_validation.COIN_COUNT_ATTR_ID = "coin_count"

local _COIN_COUNT_ATTR_ID = coin_validation.COIN_COUNT_ATTR_ID

local function _player_label(player)
  if player == nil then
    return "玩家?"
  end
  local id = player.id
  local name = player.name
  if id ~= nil and name ~= nil and name ~= "" then
    return "玩家" .. tostring(id) .. "(" .. tostring(name) .. ")"
  end
  if id ~= nil then
    return "玩家" .. tostring(id)
  end
  if name ~= nil and name ~= "" then
    return tostring(name)
  end
  return "玩家?"
end

local function _coin_error(player, reason)
  return _player_label(player) .. " " .. _COIN_COUNT_ATTR_ID .. " " .. tostring(reason)
end

local function _fail(player, reason)
  error(_coin_error(player, reason))
end

local function _is_finite_numeric(value)
  if not number_utils.is_numeric(value) then
    return false
  end
  local ok, diff = pcall(function()
    return value - value
  end)
  return ok and diff == 0
end

local function _require_finite_integer(player, value, label)
  if not _is_finite_numeric(value) then
    _fail(player, label .. "必须是有限整数")
  end
  local as_int = number_utils.to_integer(value)
  if as_int == nil or as_int ~= value then
    _fail(player, label .. "必须是有限整数")
  end
  return as_int
end

local function _validate_coin_amount(player, value, reason)
  local label = tostring(reason or "金币值")
  local as_int = _require_finite_integer(player, value, label)
  if as_int < 0 then
    _fail(player, label .. "不能为负数")
  end
  return as_int
end

local function _validate_delta(player, value)
  return _require_finite_integer(player, value, "金币变化量")
end

coin_validation.coin_error = _coin_error
coin_validation.fail = _fail
coin_validation.validate_amount = _validate_coin_amount
coin_validation.validate_delta = _validate_delta

return coin_validation
