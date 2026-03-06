local logger = require("src.core.Logger")
local land_choice_specs = require("src.game.systems.land.LandChoiceSpecs")
local monopoly_event = require("src.core.events.MonopolyEvents")
local context = require("src.game.systems.market.service.Context")
local fulfillment = require("src.game.systems.market.service.Fulfillment")
local paid_purchase_gateway = require("src.game.systems.market.service.PaidPurchaseGateway")
local number_utils = require("src.core.NumberUtils")

local purchase = {}
local _emit_event = monopoly_event.emit

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

local function _emit_buy_failed(player, entry, reason, body)
  _emit_event(monopoly_event.market.buy_failed, {
    player = player,
    entry = entry,
    reason = reason,
    popup = { title = "黑市", body = body },
  })
end

local function _fulfill_paid_goods_purchase(game, player, entry)
  local product_id = entry.product_id
  local price = context.entry_price(entry)
  local currency = context.entry_currency(entry)

  if not context.entry_vehicle_enabled(entry) then
    _emit_buy_failed(player, entry, "vehicle_disabled", player.name .. " 当前对局已关闭载具功能")
    return false
  end
  if not context.entry_market_enabled(entry) then
    _emit_buy_failed(player, entry, "disabled", player.name .. " 该商品暂不可购买")
    return false
  end
  local remaining = context.remaining_global_limit(game, product_id)
  if remaining <= 0 then
    _emit_buy_failed(player, entry, "sold_out", player.name .. " 该商品已售罄")
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
  _emit_buy_failed(player, entry, result.reason, result.body)
  return false
end

local function _handle_paid_purchase_callback(game, player, entry)
  local ok = _fulfill_paid_goods_purchase(game, player, entry)
  if ok then
    local market_choice = require("src.game.systems.market.service.Choice")
    market_choice.refresh_after_paid_callback(game, player, entry)
  end
end

function purchase.setup_for_game(game)
  paid_purchase_gateway.setup_for_game(game, _handle_paid_purchase_callback)
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

  if not context.entry_vehicle_enabled(entry) then
    _emit_buy_failed(player, entry, "vehicle_disabled", player.name .. " 当前对局已关闭载具功能")
    return { ok = false }
  end
  if not context.entry_market_enabled(entry) then
    _emit_buy_failed(player, entry, "disabled", player.name .. " 该商品暂不可购买")
    return { ok = false }
  end
  local remaining = context.remaining_global_limit(game, product_id)
  if remaining <= 0 then
    _emit_buy_failed(player, entry, "sold_out", player.name .. " 该商品已售罄")
    return { ok = false }
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
      _emit_buy_failed(player, entry, reason or "paid_purchase_start_failed", player.name .. " 购买通道暂不可用")
      return { ok = false, reason = reason or "paid_purchase_start_failed" }
    end
    return {
      ok = true,
      kind = entry.kind,
      product_id = product_id,
      deferred_fulfillment = true,
    }
  end

  context.sync_managed_balance(game, player, currency)
  if game:player_balance(player, currency) < price then
    _emit_buy_failed(player, entry, "insufficient_balance", player.name .. " 余额不足")
    return { ok = false, reason = "insufficient_balance", option_id = product_id }
  end

  if entry.kind == "vehicle" then
    if player.seat_id and not opts.skip_vehicle_prompt then
      local current_name = context.vehicle_name(player.seat_id)
      local next_name = context.entry_name(entry)
      return {
        ok = false,
        intent = {
          kind = "need_choice",
          choice_spec = land_choice_specs.build_use_skip(
            "market_vehicle_replace",
            "是否更换座驾",
            {
              "当前座驾：" .. current_name,
              "新座驾：" .. next_name,
              "价格：" .. tostring(price) .. " " .. currency,
            },
            { player_id = player.id, product_id = entry.product_id },
            { use = "更换", skip = "算了" }
          ),
        },
      }
    end
  end

  local result = fulfillment.apply(game, player, entry, {
    skip_charge = false,
    price = price,
    currency = currency,
    priced_text = true,
  })
  if not result.ok then
    _emit_buy_failed(player, entry, result.reason, result.body)
    return { ok = false, reason = result.reason }
  end
  return result
end

return purchase
