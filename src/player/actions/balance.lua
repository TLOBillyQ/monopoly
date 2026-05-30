local action_anim_port = require("src.foundation.ports.action_anim")
local common = require("src.player.actions.state_common")

local balance_ops = {}

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

function balance_ops.player_balance(self, player, currency)
  local key = common.normalize_currency(currency)
  if key == "金币" then
    return player.cash
  end
  error("unsupported currency: " .. tostring(key))
end

function balance_ops.add_player_cash(self, player, amount, opts)
  local next_cash = self:player_balance(player, "金币") + amount
  local updated_cash = self:set_player_cash(player, next_cash)
  _queue_cash_anim(self, player, amount, opts)
  return updated_cash
end

function balance_ops.set_player_cash(self, player, amount)
  player.cash = amount
  common.mark_players(self)
  return amount
end

function balance_ops.deduct_player_cash(self, player, amount, opts)
  local new_balance = self:player_balance(player, "金币") - amount
  assert(new_balance >= 0, "negative balance: " .. tostring(new_balance))
  return self:add_player_cash(player, -amount, opts)
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
