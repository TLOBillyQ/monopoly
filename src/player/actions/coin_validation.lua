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

--[[ mutate4lua-manifest
version=2
projectHash=4458c1c9304ed251
scope.0.id=chunk:src/player/actions/coin_validation.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=75
scope.0.semanticHash=ba64d50ebc1959f2
scope.0.lastMutatedAt=2026-06-25T01:26:34Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:_player_label:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=25
scope.1.semanticHash=694d2874da2083c1
scope.1.lastMutatedAt=2026-06-25T01:26:34Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=22
scope.1.lastMutationKilled=22
scope.2.id=function:_coin_error:27
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=29
scope.2.semanticHash=080b0dc53351b0b7
scope.2.lastMutatedAt=2026-06-25T01:26:34Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_fail:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=33
scope.3.semanticHash=00cbb07ee34ca349
scope.3.lastMutatedAt=2026-06-25T01:26:34Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:anonymous@39:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=41
scope.4.semanticHash=909770022d29387e
scope.5.id=function:_is_finite_numeric:35
scope.5.kind=function
scope.5.startLine=35
scope.5.endLine=43
scope.5.semanticHash=6a53b4abe2ef643e
scope.5.lastMutatedAt=2026-06-25T01:26:34Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=7
scope.5.lastMutationKilled=5
scope.6.id=function:_require_finite_integer:45
scope.6.kind=function
scope.6.startLine=45
scope.6.endLine=54
scope.6.semanticHash=63a15c55c77a74a1
scope.6.lastMutatedAt=2026-06-25T01:26:34Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=8
scope.6.lastMutationKilled=8
scope.7.id=function:_validate_coin_amount:56
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=63
scope.7.semanticHash=40059eecb6f425c6
scope.7.lastMutatedAt=2026-06-25T01:26:34Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=5
scope.7.lastMutationKilled=5
scope.8.id=function:_validate_delta:65
scope.8.kind=function
scope.8.startLine=65
scope.8.endLine=67
scope.8.semanticHash=5078705721aef9b4
scope.8.lastMutatedAt=2026-06-25T01:26:34Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
]]
