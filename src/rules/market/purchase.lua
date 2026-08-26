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
  -- 非付费币种只允许默认金币：未知币种在读扣余额前硬失败，不得静默按金币成交。
  query_context.assert_cash_currency(currency)

  if game:player_cash(player) < price then
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
version=4
projectHash=fbc1d0321bc3d70c
scope.0.id=chunk:src/rules/market/purchase.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=158
scope.0.semanticHash=c8227c5930712e52
scope.1.id=function:policy.validate_entry
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=40
scope.1.semanticHash=b75a15b6139b2063
scope.2.id=function:local_purchase.execute
scope.2.kind=function
scope.2.startLine=44
scope.2.endLine=67
scope.2.semanticHash=104e0e70cdca3a4c
scope.3.id=function:paid_fulfillment.fulfill_entry
scope.3.kind=function
scope.3.startLine=71
scope.3.endLine=91
scope.3.semanticHash=8b5816c22121bbc8
scope.4.id=function:paid_purchase_callback.handle
scope.4.kind=function
scope.4.startLine=95
scope.4.endLine=102
scope.4.semanticHash=8262bce10b2a924f
scope.5.id=function:purchase.setup_for_game
scope.5.kind=function
scope.5.startLine=106
scope.5.endLine=108
scope.5.semanticHash=8d859da6107a3d00
scope.6.id=function:_resolve_product_id
scope.6.kind=function
scope.6.startLine=110
scope.6.endLine=116
scope.6.semanticHash=d4e8b68c227e888e
scope.7.id=function:_validate_purchase_entry
scope.7.kind=function
scope.7.startLine=118
scope.7.endLine=125
scope.7.semanticHash=f28a699ee2cee66a
scope.8.id=function:_handle_paid_purchase
scope.8.kind=function
scope.8.startLine=127
scope.8.endLine=129
scope.8.semanticHash=2bee49689c692a47
scope.9.id=function:purchase.execute
scope.9.kind=function
scope.9.startLine=131
scope.9.endLine=152
scope.9.semanticHash=c7fd7e934004baab
]]
