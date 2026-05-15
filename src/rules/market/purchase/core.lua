local logger = require("src.foundation.log")
local context = require("src.rules.market.query.context")
local market_feedback = require("src.rules.market.choice.feedback")
local purchase_policy = require("src.rules.market.purchase.policy")
local local_purchase = require("src.rules.market.purchase.local_purchase")
local paid_purchase_callback = require("src.rules.market.purchase.paid_purchase_callback")
local paid_purchase_gateway = require("src.rules.ports.paid_purchase")
local number_utils = require("src.foundation.number")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local purchase = {}

local IN_FLIGHT_FIELD = "_market_paid_in_flight"
local IN_FLIGHT_TIMEOUT = 12.0

local function _in_flight_key(player_id, product_id)
  return tostring(player_id) .. ":" .. tostring(product_id)
end

function purchase.setup_for_game(game)
  paid_purchase_gateway.setup_for_game(game, paid_purchase_callback.handle)
end

local function _resolve_product_id(product_id)
  local resolved = number_utils.to_integer(product_id)
  if resolved == nil or resolved <= 0 then
    return nil
  end
  return resolved
end

local function _validate_purchase_entry(game, player, entry)
  local decision = purchase_policy.validate_entry(game, player, entry)
  if not decision.ok then
    market_feedback.emit_buy_failed(player, entry, decision.reason, decision.body)
    return false, decision.reason
  end
  return true
end

local function _handle_paid_purchase(game, player, entry, product_id)
  local in_flight = game[IN_FLIGHT_FIELD]
  if not in_flight then
    in_flight = {}
    game[IN_FLIGHT_FIELD] = in_flight
  end
  local key = _in_flight_key(player.id, product_id)
  if in_flight[key] then
    market_feedback.emit_buy_failed(player, entry, "purchase_in_flight", player.name .. " 正在购买中，请稍候")
    return { ok = false, reason = "purchase_in_flight" }
  end
  in_flight[key] = true

  purchase.setup_for_game(game)
  local ok_start, reason = paid_purchase_gateway.start(game, player, entry)
  if not ok_start then
    in_flight[key] = nil
    logger.warn(
      "market paid purchase blocked:",
      "product_id=" .. tostring(product_id),
      "name=" .. tostring(entry.name or ""),
      "reason=" .. tostring(reason or "unknown")
    )
    market_feedback.emit_buy_failed(player, entry, reason or "paid_purchase_start_failed", player.name .. " 购买通道暂不可用")
    return { ok = false, reason = reason or "paid_purchase_start_failed" }
  end

  runtime_ports.schedule(IN_FLIGHT_TIMEOUT, function()
    local map = game[IN_FLIGHT_FIELD]
    if map then
      map[key] = nil
    end
  end)

  return {
    ok = true,
    kind = entry.kind,
    product_id = product_id,
    deferred_fulfillment = true,
  }
end

function purchase.execute(game, player, product_id, _opts)
  local resolved_product_id = _resolve_product_id(product_id)
  if resolved_product_id == nil then
    logger.warn("invalid market product id:", tostring(product_id))
    return false
  end
  product_id = resolved_product_id

  local entry = context.entry_by_id(product_id)
  assert(entry ~= nil, "missing market entry: " .. tostring(product_id))

  local ok, reason = _validate_purchase_entry(game, player, entry)
  if not ok then
    return { ok = false, reason = reason }
  end

  local currency = context.entry_currency(entry)
  if context.is_paid_currency(currency) then
    return _handle_paid_purchase(game, player, entry, product_id)
  end
  return local_purchase.execute(game, player, entry)
end

return purchase
