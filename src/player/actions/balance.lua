local action_anim_port = require("src.foundation.ports.action_anim")
local common = require("src.player.actions.state_common")
local coin_validation = require("src.player.actions.coin_validation")
local coin_store = require("src.player.actions.coin_store")

local balance_ops = {}

balance_ops.COIN_COUNT_ATTR_ID = coin_validation.COIN_COUNT_ATTR_ID
balance_ops.new_memory_coin_role = coin_store.new_memory_coin_role

local _fail = coin_validation.fail
local _coin_error = coin_validation.coin_error
local _validate_coin_amount = coin_validation.validate_amount
local _validate_delta = coin_validation.validate_delta
local _read_coin_raw = coin_store.read_raw
local _read_coin_count = coin_store.read_count
local _try_write_coin_count = coin_store.try_write

local function _write_coin_count(self, player, amount)
  local ok, result = _try_write_coin_count(player, amount)
  if not ok then
    _fail(player, "写入失败: " .. tostring(result))
  end
  if self ~= nil then
    common.mark_players(self)
  end
  return result
end

local function _write_receiver_or_rollback(payer, payer_before, receiver, receiver_after)
  local receiver_ok, receiver_err = _try_write_coin_count(receiver, receiver_after)
  if receiver_ok then
    return
  end
  local rollback_ok, rollback_err = _try_write_coin_count(payer, payer_before)
  if not rollback_ok then
    error(_coin_error(receiver, "写入失败: " .. tostring(receiver_err)
      .. "; 回滚结果=fatal: " .. tostring(rollback_err)))
  end
  error(_coin_error(receiver, "写入失败: " .. tostring(receiver_err) .. "; 回滚结果=成功"))
end

local function _queue_cash_anim(self, player, delta, opts)
  if opts and opts.suppress_cash_receive_anim == true then
    return
  end
  if delta == 0 then
    return
  end
  action_anim_port.queue(self, {
    kind = "cash_receive",
    player_id = player.id,
    amount = delta,
  })
end

function balance_ops.initialize_player_coins(player, amount)
  local current = _read_coin_raw(player)
  if current ~= nil then
    return _validate_coin_amount(player, current, "读取值")
  end
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
  local delta = _validate_delta(player, amount)
  local current_cash = self:player_balance(player, "金币")
  local next_cash = current_cash + delta
  if next_cash < 0 then
    next_cash = 0
  end
  local updated_cash = self:set_player_cash(player, next_cash)
  _queue_cash_anim(self, player, updated_cash - current_cash, opts)
  return updated_cash
end

function balance_ops.set_player_cash(self, player, amount)
  return _write_coin_count(self, player, amount)
end

function balance_ops.deduct_player_cash(self, player, amount, opts)
  local cost = _validate_delta(player, amount)
  local new_balance = self:player_balance(player, "金币") - cost
  if new_balance < 0 then
    _fail(player, "余额不足: " .. tostring(new_balance))
  end
  return self:add_player_cash(player, -cost, opts)
end

function balance_ops.transfer_player_cash(self, payer, receiver, amount, opts)
  local delta = _validate_delta(payer, amount)
  if delta < 0 then
    _fail(payer, "支付金额不能为负数")
  end
  local payer_before = _read_coin_count(payer)
  local receiver_before = _read_coin_count(receiver)
  local payer_after = payer_before - delta
  if payer_after < 0 then
    _fail(payer, "余额不足: " .. tostring(payer_after))
  end
  local receiver_after = receiver_before + delta
  _validate_coin_amount(receiver, receiver_after, "写入值")

  local payer_ok, payer_err = _try_write_coin_count(payer, payer_after)
  if not payer_ok then
    _fail(payer, "写入失败: " .. tostring(payer_err))
  end

  _write_receiver_or_rollback(payer, payer_before, receiver, receiver_after)

  common.mark_players(self)
  _queue_cash_anim(self, payer, -delta, opts)
  _queue_cash_anim(self, receiver, delta, opts)
  return payer_after, receiver_after
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
projectHash=dc40de52ac82a2ec
scope.0.id=chunk:src/player/actions/balance.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=56
scope.0.semanticHash=f0a346d3020eeb76
scope.1.id=function:_queue_cash_anim:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=18
scope.1.semanticHash=ab3817e6bc820e1d
scope.2.id=function:balance_ops.player_balance:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=26
scope.2.semanticHash=9697b199d20cb271
scope.3.id=function:balance_ops.add_player_cash:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=33
scope.3.semanticHash=17c3ecc29443bcfa
scope.4.id=function:balance_ops.set_player_cash:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=39
scope.4.semanticHash=4c37283c9089460c
scope.5.id=function:balance_ops.deduct_player_cash:41
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=45
scope.5.semanticHash=593e330dc62e34b9
scope.6.id=function:balance_ops.deduct_player_balance:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=53
scope.6.semanticHash=29add5e9e99db7ac
]]
