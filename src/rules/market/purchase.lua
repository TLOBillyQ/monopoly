local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local paid_purchase_gateway = require("src.rules.ports.paid_purchase")
local market_query = require("src.rules.market.query")
local market_choice = require("src.rules.market.choice")
local paid_purchase_flow = require("src.rules.market.paid_purchase_flow")
local fulfillment = require("src.rules.market.purchase_fulfillment")

local query_context = market_query.context
local choice_feedback = market_choice.feedback
local choice_session = market_choice.session

local policy = {}

function policy.validate_entry(game, player, entry)
  local product_id = entry.product_id
  if not query_context.entry_market_enabled(entry) then
    return {
      ok = false,
      reason = "disabled",
      body = player.name .. " 该商品暂不可购买",
    }
  end
  if entry.kind ~= "item" then
    return {
      ok = false,
      reason = "unsupported_kind",
      body = player.name .. " 该商品类型暂不支持购买",
    }
  end
  local remaining = query_context.remaining_global_limit(game, product_id)
  if remaining <= 0 then
    return {
      ok = false,
      reason = "sold_out",
      body = player.name .. " 该商品已售罄",
    }
  end
  return { ok = true }
end

local local_purchase = {}

function local_purchase.execute(game, player, entry)
  local product_id = entry.product_id
  local price = query_context.entry_price(entry)
  local currency = query_context.entry_currency(entry)

  if game:player_balance(player, currency) < price then
    choice_feedback.emit_buy_failed(player, entry, "insufficient_balance", player.name .. " 余额不足")
    return { ok = false, reason = "insufficient_balance", option_id = product_id }
  end

  local result = fulfillment.apply(game, player, entry, {
    skip_charge = false,
    price = price,
    currency = currency,
    priced_text = true,
  })
  if not result.ok then
    choice_feedback.emit_buy_failed(player, entry, result.reason, result.body)
    return { ok = false, reason = result.reason }
  end
  return result
end

local paid_fulfillment = {}

function paid_fulfillment.fulfill_entry(game, player, entry)
  local price = query_context.entry_price(entry)
  local currency = query_context.entry_currency(entry)
  local decision = policy.validate_entry(game, player, entry)
  if not decision.ok then
    choice_feedback.emit_buy_failed(player, entry, decision.reason, decision.body)
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
  choice_feedback.emit_buy_failed(player, entry, result.reason, result.body)
  return false
end

local paid_purchase_callback = {}

function paid_purchase_callback.handle(game, player, entry)
  paid_purchase_flow.clear_in_flight(game, player, entry)
  local ok = paid_fulfillment.fulfill_entry(game, player, entry)
  if ok then
    choice_session.refresh_after_paid_callback(game, player, entry)
  end
  return ok
end

local purchase = {}

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
  local decision = policy.validate_entry(game, player, entry)
  if not decision.ok then
    choice_feedback.emit_buy_failed(player, entry, decision.reason, decision.body)
    return false, decision.reason
  end
  return true
end

local function _handle_paid_purchase(game, player, entry, product_id)
  return paid_purchase_flow.handle(game, player, entry, product_id, purchase.setup_for_game)
end

function purchase.execute(game, player, product_id)
  local resolved_product_id = _resolve_product_id(product_id)
  if resolved_product_id == nil then
    logger.warn("invalid market product id:", tostring(product_id))
    return false
  end
  product_id = resolved_product_id

  local entry = query_context.entry_by_id(product_id)
  assert(entry ~= nil, "missing market entry: " .. tostring(product_id))

  local ok, reason = _validate_purchase_entry(game, player, entry)
  if not ok then
    return { ok = false, reason = reason }
  end

  local currency = query_context.entry_currency(entry)
  if query_context.is_paid_currency(currency) then
    return _handle_paid_purchase(game, player, entry, product_id)
  end
  return local_purchase.execute(game, player, entry)
end

return {
  execute = purchase.execute,
  setup_for_game = purchase.setup_for_game,
}

--[[ mutate4lua-manifest
version=2
projectHash=264951b13c6ea6ce
scope.0.id=chunk:src/rules/market/purchase.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=275
scope.0.semanticHash=b1b5685941eda255
scope.0.lastMutatedAt=2026-05-25T07:29:28Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=11
scope.0.lastMutationKilled=11
scope.1.id=function:policy.validate_entry:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=43
scope.1.semanticHash=b661f107a86239e6
scope.1.lastMutatedAt=2026-05-25T07:29:28Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=17
scope.1.lastMutationKilled=17
scope.2.id=function:_emit_bought_item:48
scope.2.kind=function
scope.2.startLine=48
scope.2.endLine=54
scope.2.semanticHash=81f8274a3eb0c61d
scope.2.lastMutatedAt=2026-05-25T07:29:28Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:_success_text:56
scope.3.kind=function
scope.3.startLine=56
scope.3.endLine=62
scope.3.semanticHash=ab1cd5216d5f318d
scope.3.lastMutatedAt=2026-05-25T07:29:28Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:_charge_if_needed:64
scope.4.kind=function
scope.4.startLine=64
scope.4.endLine=71
scope.4.semanticHash=8139cff35dd5f0a7
scope.4.lastMutatedAt=2026-05-25T07:29:28Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
scope.5.id=function:_fulfill_item:73
scope.5.kind=function
scope.5.startLine=73
scope.5.endLine=96
scope.5.semanticHash=85584e771f94e5cc
scope.5.lastMutatedAt=2026-05-25T07:29:28Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=16
scope.5.lastMutationKilled=16
scope.6.id=function:fulfillment.apply:98
scope.6.kind=function
scope.6.startLine=98
scope.6.endLine=106
scope.6.semanticHash=6714636abdd27495
scope.6.lastMutatedAt=2026-05-25T07:29:28Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=9
scope.6.lastMutationKilled=9
scope.7.id=function:local_purchase.execute:110
scope.7.kind=function
scope.7.startLine=110
scope.7.endLine=131
scope.7.semanticHash=19bb5518fc7f6322
scope.7.lastMutatedAt=2026-05-25T07:29:28Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=11
scope.7.lastMutationKilled=11
scope.8.id=function:paid_fulfillment.fulfill_entry:135
scope.8.kind=function
scope.8.startLine=135
scope.8.endLine=155
scope.8.semanticHash=497c9c1b34ec0c9c
scope.8.lastMutatedAt=2026-05-25T07:29:28Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=10
scope.8.lastMutationKilled=10
scope.9.id=function:_clear_in_flight:161
scope.9.kind=function
scope.9.startLine=161
scope.9.endLine=166
scope.9.semanticHash=93ec0d952aae98fe
scope.9.lastMutatedAt=2026-05-25T07:29:28Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=3
scope.9.lastMutationKilled=3
scope.10.id=function:paid_purchase_callback.handle:168
scope.10.kind=function
scope.10.startLine=168
scope.10.endLine=175
scope.10.semanticHash=4785ac6a5756b443
scope.10.lastMutatedAt=2026-05-25T07:29:28Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=3
scope.10.lastMutationKilled=3
scope.11.id=function:_in_flight_key:181
scope.11.kind=function
scope.11.startLine=181
scope.11.endLine=183
scope.11.semanticHash=4b5ca6357fa72b8a
scope.11.lastMutatedAt=2026-05-25T07:29:28Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=3
scope.11.lastMutationKilled=3
scope.12.id=function:purchase.setup_for_game:185
scope.12.kind=function
scope.12.startLine=185
scope.12.endLine=187
scope.12.semanticHash=062ee2e3c9a2e1f2
scope.12.lastMutatedAt=2026-05-25T07:29:28Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:_resolve_product_id:189
scope.13.kind=function
scope.13.startLine=189
scope.13.endLine=195
scope.13.semanticHash=26c5527149581a05
scope.13.lastMutatedAt=2026-05-25T07:29:28Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=5
scope.13.lastMutationKilled=5
scope.14.id=function:_validate_purchase_entry:197
scope.14.kind=function
scope.14.startLine=197
scope.14.endLine=204
scope.14.semanticHash=e4477002e27f58c3
scope.14.lastMutatedAt=2026-05-25T07:29:28Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=5
scope.14.lastMutationKilled=5
scope.15.id=function:anonymous@233:233
scope.15.kind=function
scope.15.startLine=233
scope.15.endLine=238
scope.15.semanticHash=d8a93e4649fd95d2
scope.15.lastMutatedAt=2026-05-25T07:29:28Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=no_sites
scope.15.lastMutationSites=0
scope.15.lastMutationKilled=0
scope.16.id=function:_handle_paid_purchase:206
scope.16.kind=function
scope.16.startLine=206
scope.16.endLine=246
scope.16.semanticHash=915baafe3bf65f4f
scope.16.lastMutatedAt=2026-05-25T07:29:28Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=17
scope.16.lastMutationKilled=17
scope.17.id=function:purchase.execute:248
scope.17.kind=function
scope.17.startLine=248
scope.17.endLine=269
scope.17.semanticHash=385c11d52b1a77ac
scope.17.lastMutatedAt=2026-05-25T07:29:28Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=13
scope.17.lastMutationKilled=13
]]
