local logger = require("src.foundation.log")
local inventory = require("src.rules.items.inventory")
local number_utils = require("src.foundation.number")
local monopoly_event = require("src.foundation.events")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local paid_purchase_gateway = require("src.rules.ports.paid_purchase")
local market_query = require("src.rules.market.query")
local market_choice = require("src.rules.market.choice")

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

local fulfillment = {}
local _emit_event = monopoly_event.emit

local function _emit_bought_item(game, payload)
  _emit_event(monopoly_event.market.bought_item, payload)
  if game and type(payload.text) == "string" then
    event_feed.publish(game, {
      kind = event_kinds.item_acquired,
      text = payload.text,
    })
  end
end

local function _success_text(player, entry, price, currency, priced)
  local name = query_context.entry_name(entry)
  if entry.kind == "skin" then
    if priced then
      return player.name .. " 慷慨解囊 " .. number_utils.format_integer_part(price) .. " " .. currency .. "，喜提专属皮肤【" .. name .. "】，蛋仔闪耀登场～"
    end
    return "恭喜 " .. player.name .. " 喜提专属皮肤【" .. name .. "】，蛋仔闪耀全场～"
  end
  if priced then
    return player.name .. " 在黑市购买 " .. name .. " 花费 " .. number_utils.format_integer_part(price) .. " " .. currency
  end
  return player.name .. " 在黑市购买 " .. name .. " 成功"
end

local function _charge_if_needed(game, player, currency, price, opts)
  if opts and opts.skip_charge == true then
    return true
  end
  return query_context.try_charge_player(game, player, currency, price, {
    suppress_cash_receive_anim = true,
  })
end

local function _fulfill_item(game, player, entry, opts)
  if inventory.is_full(player) then
    return { ok = false, reason = "inventory_full", body = player.name .. " 卡槽已满" }
  end
  if not _charge_if_needed(game, player, opts.currency, opts.price, opts) then
    return { ok = false, reason = "charge_failed", body = player.name .. " 支付失败" }
  end
  inventory.give(player, entry.product_id)
  query_context.consume_global_limit(game, entry.product_id)
  _emit_bought_item(game, {
    player = player,
    entry = entry,
    price = opts.price,
    currency = opts.currency,
    text = _success_text(player, entry, opts.price, opts.currency, opts.priced_text),
  })
  return {
    ok = true,
    kind = "item",
    product_id = entry.product_id,
    inventory_full_after = inventory.is_full(player),
    fulfilled_now = true,
  }
end

local function _fulfill_skin(game, player, entry, opts)
  if not _charge_if_needed(game, player, opts.currency, opts.price, opts) then
    return { ok = false, reason = "charge_failed", body = player.name .. " 支付失败" }
  end
  query_context.consume_global_limit(game, entry.product_id)
  _emit_bought_item(game, {
    player = player,
    entry = entry,
    price = opts.price,
    currency = opts.currency,
    text = _success_text(player, entry, opts.price, opts.currency, opts.priced_text),
  })
  return {
    ok = true,
    kind = "skin",
    product_id = entry.product_id,
    fulfilled_now = true,
    equipped = false,
  }
end

function fulfillment.apply(game, player, entry, opts)
  opts = opts or {}
  local resolved_opts = {
    skip_charge = opts.skip_charge == true,
    price = opts.price ~= nil and opts.price or query_context.entry_price(entry),
    currency = opts.currency ~= nil and opts.currency or query_context.entry_currency(entry),
    priced_text = opts.priced_text == true,
  }

  if entry.kind == "item" then
    return _fulfill_item(game, player, entry, resolved_opts)
  end

  if entry.kind == "skin" then
    return _fulfill_skin(game, player, entry, resolved_opts)
  end

  return { ok = false, reason = "unsupported_kind", body = player.name .. " 该商品类型暂不支持购买" }
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

local purchase = {}

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
  local decision = policy.validate_entry(game, player, entry)
  if not decision.ok then
    choice_feedback.emit_buy_failed(player, entry, decision.reason, decision.body)
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
    choice_feedback.emit_buy_failed(player, entry, "purchase_in_flight", player.name .. " 正在购买中，请稍候")
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
    choice_feedback.emit_buy_failed(player, entry, reason or "paid_purchase_start_failed", player.name .. " 购买通道暂不可用")
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
