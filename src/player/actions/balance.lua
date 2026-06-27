local common = require("src.player.actions.state_common")
local coin_validation = require("src.player.actions.coin_validation")
local coin_store = require("src.player.actions.coin_store")
local coin_settlement = require("src.player.actions.coin_settlement")

local balance_ops = {}

balance_ops.COIN_COUNT_ATTR_ID = coin_validation.COIN_COUNT_ATTR_ID
balance_ops.new_memory_coin_role = coin_store.new_memory_coin_role

local _validate_coin_amount = coin_validation.validate_amount
local _read_coin_raw = coin_store.read_raw
local _read_coin_count = coin_store.read_count

local function _write_coin_count(self, player, amount)
  return coin_settlement.set_balance(self, player, amount)
end

function balance_ops.initialize_player_coins(player, amount)
  local current = _read_coin_raw(player)
  if current ~= nil then
    return _validate_coin_amount(player, current, "读取值")
  end
  return _write_coin_count(nil, player, amount)
end

function balance_ops.seed_player_coins(player, amount)
  return _write_coin_count(nil, player, amount)
end

function balance_ops.player_balance(self, player, currency)
  local key = common.normalize_currency(currency)
  if key == "金币" then
    return _read_coin_count(player)
  end
  error("unsupported currency: " .. tostring(key))
end

function balance_ops.add_player_cash(self, player, amount, opts)
  return coin_settlement.add_delta(self, player, amount, opts)
end

function balance_ops.set_player_cash(self, player, amount)
  return _write_coin_count(self, player, amount)
end

function balance_ops.deduct_player_cash(self, player, amount, opts)
  return coin_settlement.deduct(self, player, amount, opts)
end

function balance_ops.transfer_player_cash(self, payer, receiver, amount, opts)
  return coin_settlement.transfer(self, payer, receiver, amount, opts)
end

function balance_ops.deduct_player_balance(self, player, currency, amount, opts)
  local key = common.normalize_currency(currency)
  if key == "金币" then
    return self:deduct_player_cash(player, amount, opts)
  end
  error("unsupported currency: " .. tostring(key))
end

return balance_ops

--[[ mutate4lua-manifest
version=2
projectHash=afa3caf1d2658a0c
scope.0.id=chunk:src/player/actions/balance.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=134
scope.0.semanticHash=f82ed91341991a7a
scope.0.lastMutatedAt=2026-06-25T01:25:55Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:_write_coin_count:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=28
scope.1.semanticHash=975942012f68a610
scope.1.lastMutatedAt=2026-06-25T01:25:55Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_write_receiver_or_rollback:30
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=41
scope.2.semanticHash=4049d57d0e6c122b
scope.2.lastMutatedAt=2026-06-25T01:25:55Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_queue_cash_anim:43
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=55
scope.3.semanticHash=ab3817e6bc820e1d
scope.3.lastMutatedAt=2026-06-25T01:25:55Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=6
scope.3.lastMutationKilled=6
scope.4.id=function:balance_ops.initialize_player_coins:57
scope.4.kind=function
scope.4.startLine=57
scope.4.endLine=63
scope.4.semanticHash=2599abba03cb4e82
scope.4.lastMutatedAt=2026-06-25T01:25:55Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
scope.5.id=function:balance_ops.player_balance:65
scope.5.kind=function
scope.5.startLine=65
scope.5.endLine=71
scope.5.semanticHash=a45f98e71fdbc5a2
scope.5.lastMutatedAt=2026-06-25T01:25:55Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=5
scope.6.id=function:balance_ops.add_player_cash:73
scope.6.kind=function
scope.6.startLine=73
scope.6.endLine=83
scope.6.semanticHash=d9c72b29c175d8fb
scope.6.lastMutatedAt=2026-06-25T01:25:55Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=survived
scope.6.lastMutationSites=8
scope.6.lastMutationKilled=6
scope.7.id=function:balance_ops.set_player_cash:85
scope.7.kind=function
scope.7.startLine=85
scope.7.endLine=87
scope.7.semanticHash=a98e915ba6998a49
scope.7.lastMutatedAt=2026-06-25T01:25:55Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:balance_ops.deduct_player_cash:89
scope.8.kind=function
scope.8.startLine=89
scope.8.endLine=96
scope.8.semanticHash=d6839dd6c00330ad
scope.8.lastMutatedAt=2026-06-25T01:25:55Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=7
scope.8.lastMutationKilled=7
scope.9.id=function:balance_ops.transfer_player_cash:98
scope.9.kind=function
scope.9.startLine=98
scope.9.endLine=123
scope.9.semanticHash=d0ac57320a437d6c
scope.9.lastMutatedAt=2026-06-25T01:25:55Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=19
scope.9.lastMutationKilled=19
scope.10.id=function:balance_ops.deduct_player_balance:125
scope.10.kind=function
scope.10.startLine=125
scope.10.endLine=131
scope.10.semanticHash=29add5e9e99db7ac
scope.10.lastMutatedAt=2026-06-25T01:25:55Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=5
scope.10.lastMutationKilled=5
]]
