local context = require("src.rules.market.query.context")
local feedback = require("src.rules.market.choice.feedback")
local purchase_policy = require("src.rules.market.purchase.policy")
local fulfillment = require("src.rules.market.purchase.fulfillment")

local local_purchase = {}

function local_purchase.execute(game, player, entry, opts)
  opts = opts or {}
  local product_id = entry.product_id
  local price = context.entry_price(entry)
  local currency = context.entry_currency(entry)

  context.sync_managed_balance(game, player, currency)
  if game:player_balance(player, currency) < price then
    feedback.emit_buy_failed(player, entry, "insufficient_balance", player.name .. " 余额不足")
    return { ok = false, reason = "insufficient_balance", option_id = product_id }
  end

  if entry.kind == "vehicle" and player.seat_id and not opts.skip_vehicle_prompt then
    return {
      ok = false,
      intent = purchase_policy.build_vehicle_replace_intent(player, entry, price, currency),
    }
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
