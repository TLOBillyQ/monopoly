local context = require("src.game.systems.market.query.context")
local feedback = require("src.game.systems.market.choice.feedback")
local purchase_policy = require("src.game.systems.market.purchase.policy")
local fulfillment = require("src.game.systems.market.purchase.fulfillment")

local paid_fulfillment = {}

function paid_fulfillment.fulfill_entry(game, player, entry)
  local price = context.entry_price(entry)
  local currency = context.entry_currency(entry)
  local decision = purchase_policy.validate_entry(game, player, entry)
  if not decision.ok then
    feedback.emit_buy_failed(player, entry, decision.reason, decision.body)
    return false
  end

  local result = fulfillment.apply(game, player, entry, {
    skip_charge = true,
    price = price,
    currency = currency,
    priced_text = false,
  })
  if result.ok then
    return true
  end
  feedback.emit_buy_failed(player, entry, result.reason, result.body)
  return false
end

return paid_fulfillment
