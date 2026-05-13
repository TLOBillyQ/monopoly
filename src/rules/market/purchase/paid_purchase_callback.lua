local paid_fulfillment = require("src.rules.market.purchase.paid_fulfillment")
local choice_session = require("src.rules.market.choice.session")

local paid_purchase_callback = {}

local IN_FLIGHT_FIELD = "_market_paid_in_flight"

local function _clear_in_flight(game, player, entry)
  local map = game[IN_FLIGHT_FIELD]
  if map and player and entry then
    map[tostring(player.id) .. ":" .. tostring(entry.product_id)] = nil
  end
end

function paid_purchase_callback.handle(game, player, entry)
  _clear_in_flight(game, player, entry)
  local ok = paid_fulfillment.fulfill_entry(game, player, entry)
  if ok then
    choice_session.refresh_after_paid_callback(game, player, entry)
  end
  return ok
end

return paid_purchase_callback
