local entry = require("game.shop.entry")
local inventory = require("game.item.inventory")
local paid_currency_bridge = require("game.commerce.paid_bridge")

local validate = {}

local function _remaining_global_limit(game, product_id)
  return game.market_limits[product_id] or 0
end

local function _sync_managed_balance(game, player, currency)
  if paid_currency_bridge.is_managed_currency(game, currency) then
    paid_currency_bridge.sync_player_currency(game, player, currency)
  end
end

function validate.can_buy(game, player, e)
  if not entry.is_vehicle_enabled(e) then
    return false
  end
  if not entry.is_market_enabled(e) then
    return false
  end
  if e.kind == "item" and inventory.is_full(player) then
    return false
  end
  if _remaining_global_limit(game, e.product_id) <= 0 then
    return false
  end
  local price = entry.price(e)
  local currency = entry.currency(e)
  _sync_managed_balance(game, player, currency)
  return game:player_balance(player, currency) >= price
end

function validate.remaining_limit(game, product_id)
  return _remaining_global_limit(game, product_id)
end

function validate.consume_limit(game, product_id)
  local remaining = assert(game.market_limits[product_id], "missing global limit")
  local next_remaining = math.max(0, remaining - 1)
  game.market_limits[product_id] = next_remaining
  game.dirty.market = true
  game.dirty.any = true
end

return validate
