local paid_fulfillment = require("src.game.systems.market.application.paid_fulfillment")
local choice_session = require("src.game.systems.market.application.choice_session")

local paid_purchase_callback = {}

function paid_purchase_callback.handle(game, player, entry)
  local ok = paid_fulfillment.fulfill_entry(game, player, entry)
  if ok then
    choice_session.refresh_after_paid_callback(game, player, entry)
  end
  return ok
end

return paid_purchase_callback
