local action_anim_port = require("src.foundation.ports.action_anim")
local common = require("src.player.actions.state_common")
local coin_validation = require("src.player.actions.coin_validation")
local coin_store = require("src.player.actions.coin_store")

local coin_settlement = {}

local _fail = coin_validation.fail
local _coin_error = coin_validation.coin_error
local _validate_coin_amount = coin_validation.validate_amount
local _validate_delta = coin_validation.validate_delta
local _read_coin_count = coin_store.read_count
local _try_write_coin_count = coin_store.try_write

local function _mark_players(game)
  if game ~= nil then
    common.mark_players(game)
  end
end

local function _queue_cash_anim(game, player, delta, opts)
  if opts and opts.suppress_cash_receive_anim == true then
    return
  end
  if delta == 0 then
    return
  end
  action_anim_port.queue(game, {
    kind = "cash_receive",
    player_id = player.id,
    amount = delta,
  })
end

local function _write_coin_count(game, player, amount)
  local ok, result = _try_write_coin_count(player, amount)
  if not ok then
    _fail(player, "写入失败: " .. tostring(result))
  end
  _mark_players(game)
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

local function _transfer_amount(payer, requested, opts)
  if requested < 0 then
    _fail(payer, "支付金额不能为负数")
  end
  local payer_before = _read_coin_count(payer)
  if opts and opts.allow_partial == true and payer_before < requested then
    return payer_before, payer_before
  end
  return requested, payer_before
end

function coin_settlement.set_balance(game, player, amount)
  return _write_coin_count(game, player, amount)
end

function coin_settlement.add_delta(game, player, amount, opts)
  local delta = _validate_delta(player, amount)
  local current_cash = _read_coin_count(player)
  local next_cash = current_cash + delta
  if next_cash < 0 then
    next_cash = 0
  end
  local updated_cash = _write_coin_count(game, player, next_cash)
  _queue_cash_anim(game, player, updated_cash - current_cash, opts)
  return updated_cash
end

function coin_settlement.deduct(game, player, amount, opts)
  local cost = _validate_delta(player, amount)
  local new_balance = _read_coin_count(player) - cost
  if new_balance < 0 then
    _fail(player, "余额不足: " .. tostring(new_balance))
  end
  return coin_settlement.add_delta(game, player, -cost, opts)
end

function coin_settlement.transfer(game, payer, receiver, amount, opts)
  local requested = _validate_delta(payer, amount)
  local actual, payer_before = _transfer_amount(payer, requested, opts)
  local receiver_before = _read_coin_count(receiver)
  local payer_after = payer_before - actual
  if payer_after < 0 then
    _fail(payer, "余额不足: " .. tostring(payer_after))
  end
  local receiver_after = receiver_before + actual
  _validate_coin_amount(receiver, receiver_after, "写入值")

  local payer_ok, payer_err = _try_write_coin_count(payer, payer_after)
  if not payer_ok then
    _fail(payer, "写入失败: " .. tostring(payer_err))
  end

  _write_receiver_or_rollback(payer, payer_before, receiver, receiver_after)

  _mark_players(game)
  _queue_cash_anim(game, payer, -actual, opts)
  _queue_cash_anim(game, receiver, actual, opts)
  return payer_after, receiver_after, actual
end

return coin_settlement

--[[ mutate4lua-manifest
version=2
projectHash=2567d7676c438bcb
scope.0.id=chunk:src/player/actions/coin_settlement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=118
scope.0.semanticHash=14dc9948af76eb7a
scope.1.id=function:_mark_players:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=19
scope.1.semanticHash=6defbfa967d212ab
scope.2.id=function:_queue_cash_anim:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=33
scope.2.semanticHash=a14b90869a4fb8a1
scope.3.id=function:_write_coin_count:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=42
scope.3.semanticHash=ac7d940b042af833
scope.4.id=function:_write_receiver_or_rollback:44
scope.4.kind=function
scope.4.startLine=44
scope.4.endLine=55
scope.4.semanticHash=4049d57d0e6c122b
scope.5.id=function:_transfer_amount:57
scope.5.kind=function
scope.5.startLine=57
scope.5.endLine=66
scope.5.semanticHash=50b2997275019d1d
scope.6.id=function:coin_settlement.set_balance:68
scope.6.kind=function
scope.6.startLine=68
scope.6.endLine=70
scope.6.semanticHash=c5d5e27c56c3bc98
scope.7.id=function:coin_settlement.add_delta:72
scope.7.kind=function
scope.7.startLine=72
scope.7.endLine=82
scope.7.semanticHash=883d8435f3176eae
scope.8.id=function:coin_settlement.deduct:84
scope.8.kind=function
scope.8.startLine=84
scope.8.endLine=91
scope.8.semanticHash=257a98c4c333202b
scope.9.id=function:coin_settlement.transfer:93
scope.9.kind=function
scope.9.startLine=93
scope.9.endLine=115
scope.9.semanticHash=f9c68bc33c7c2794
]]
