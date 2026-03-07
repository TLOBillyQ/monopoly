local common = require("src.game.core.player.state_ops.Common")

local balance_ops = {}

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

function balance_ops.add_player_cash(self, player, amount)
  local next_cash = self:player_balance(player, "金币") + amount
  return self:set_player_cash(player, next_cash)
end

function balance_ops.set_player_cash(self, player, amount)
  player.cash = amount
  common.mark_players(self)
  return amount
end

function balance_ops.deduct_player_cash(self, player, amount)
  local next_cash = self:player_balance(player, "金币") - amount
  return self:set_player_cash(player, next_cash)
end

function balance_ops.deduct_player_balance(self, player, currency, amount)
  local key = common.normalize_currency(currency)
  if key == "金币" then
    return self:deduct_player_cash(player, amount)
  end
  local current = self:player_balance(player, key)
  local next_value = current - amount
  self:set_player_balance(player, key, next_value)
  return next_value
end

return balance_ops
