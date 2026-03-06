local logger = require("src.core.Logger")
local context = require("src.game.systems.market.service.Context")
local market_feedback = require("src.game.systems.market.service.Feedback")
local purchase_policy = require("src.game.systems.market.service.PurchasePolicy")
local local_purchase = require("src.game.systems.market.service.LocalPurchase")
local paid_fulfillment = require("src.game.systems.market.service.PaidFulfillment")
local paid_purchase_gateway = require("src.game.systems.market.service.PaidPurchaseGateway")
local number_utils = require("src.core.NumberUtils")

local purchase = {}

local function _read_truthy_flag(raw)
  if raw == true or raw == 1 or raw == "1" or raw == "true" or raw == "TRUE" then
    return true
  end
  return false
end

local function _is_release_build()
  local globals = _G
  local raw = globals and globals.RELEASE_BUILD or nil
  return _read_truthy_flag(raw)
end

function purchase.setup_for_game(game)
  paid_purchase_gateway.setup_for_game(game, paid_fulfillment.handle_callback)
end

function purchase.can_start_external_purchase(game, player, entry)
  return paid_purchase_gateway.can_start(game, player, entry)
end

function purchase.execute(game, player, product_id, opts)
  opts = opts or {}
  local resolved_product_id = number_utils.to_integer(product_id)
  if resolved_product_id == nil or resolved_product_id <= 0 then
    logger.warn("invalid market product id:", tostring(product_id))
    return false
  end
  product_id = resolved_product_id

  local entry = context.entry_by_id(product_id)
  assert(entry ~= nil, "missing market entry: " .. tostring(product_id))

  local decision = purchase_policy.validate_entry(game, player, entry)
  if not decision.ok then
    market_feedback.emit_buy_failed(player, entry, decision.reason, decision.body)
    return { ok = false, reason = decision.reason }
  end

  local price = context.entry_price(entry)
  local currency = context.entry_currency(entry)
  if context.is_paid_currency(currency) then
    purchase.setup_for_game(game)
    local ok_start, reason = paid_purchase_gateway.start(game, player, entry)
    if not ok_start then
      if _is_release_build() then
        logger.warn(
          "market paid purchase blocked in release:",
          "product_id=" .. tostring(product_id),
          "name=" .. tostring(entry.name or ""),
          "reason=" .. tostring(reason or "unknown")
        )
      end
      market_feedback.emit_buy_failed(player, entry, reason or "paid_purchase_start_failed", player.name .. " 购买通道暂不可用")
      return { ok = false, reason = reason or "paid_purchase_start_failed" }
    end
    return {
      ok = true,
      kind = entry.kind,
      product_id = product_id,
      deferred_fulfillment = true,
    }
  end
  return local_purchase.execute(game, player, entry, opts)
end

return purchase
