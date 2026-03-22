local action_anim_port = require("src.core.ports.action_anim")
local common = require("src.player.actions.state_ops.common")

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
  local value = player.balances and player.balances[key]
  assert(value ~= nil, "missing balance: " .. tostring(key))
  return value
end

function balance_ops.set_player_balance(self, player, currency, value)
  local key = common.normalize_currency(currency)
  if key == "金币" then
    return self:set_player_cash(player, value)
  end
  player.balances = player.balances or {}
  player.balances[key] = value
  common.mark_players(self)
  return value
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
  return self:add_player_cash(player, -amount, opts)
end

function balance_ops.deduct_player_balance(self, player, currency, amount, opts)
  local key = common.normalize_currency(currency)
  if key == "金币" then
    return self:deduct_player_cash(player, amount, opts)
  end
  local current = self:player_balance(player, key)
  local next_value = current - amount
  self:set_player_balance(player, key, next_value)
  return next_value
end

return balance_ops
