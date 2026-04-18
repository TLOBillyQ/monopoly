local context = require("src.rules.market.query.context")
local feedback = require("src.rules.market.choice.feedback")
local fulfillment = require("src.rules.market.purchase.fulfillment")

local local_purchase = {}

function local_purchase.execute(game, player, entry, _opts)
  local product_id = entry.product_id
  local price = context.entry_price(entry)
  local currency = context.entry_currency(entry)

  if game:player_balance(player, currency) < price then
    feedback.emit_buy_failed(player, entry, "insufficient_balance", player.name .. " 余额不足")
    return { ok = false, reason = "insufficient_balance", option_id = product_id }
  end

  local result = fulfillment.apply(game, player, entry, {
    skip_charge = false,
    price = price,
    currency = currency,
    priced_text = true,
  })
  if not result.ok then
    feedback.emit_buy_failed(player, entry, result.reason, result.body)
    return { ok = false, reason = result.reason }
  end
  return result
end

return local_purchase
