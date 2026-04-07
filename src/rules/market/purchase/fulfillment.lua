local inventory = require("src.rules.items.inventory")
local context = require("src.rules.market.query.context")
local monopoly_event = require("src.core.events")
local number_utils = require("src.core.utils.number_utils")
local runtime_ports = require("src.core.ports.runtime_ports")
local logger = require("src.core.utils.logger")

local fulfillment = {}
local _emit_event = monopoly_event.emit

local function _success_text(player, entry, price, currency, priced)
  local name = context.entry_name(entry)
  if entry.kind == "skin" then
    if priced then
      return player.name .. " 在黑市购买皮肤（占位） " .. name .. " 花费 " .. number_utils.format_integer_part(price) .. " " .. currency
    end
    return player.name .. " 在黑市购买皮肤（占位） " .. name .. " 成功"
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
  return context.try_charge_player(game, player, currency, price, {
    suppress_cash_receive_anim = true,
  })
end

local function _fulfill_item(game, player, entry, opts, price, currency, priced_text)
  if inventory.is_full(player) then
    return { ok = false, reason = "inventory_full", body = player.name .. " 卡槽已满" }
  end
  if not _charge_if_needed(game, player, currency, price, opts) then
    return { ok = false, reason = "charge_failed", body = player.name .. " 支付失败" }
  end
  inventory.give(player, entry.product_id)
  context.consume_global_limit(game, entry.product_id)
  _emit_event(monopoly_event.market.bought_item, {
    player = player,
    entry = entry,
    price = price,
    currency = currency,
    text = _success_text(player, entry, price, currency, priced_text),
  })
  return {
    ok = true,
    kind = "item",
    product_id = entry.product_id,
    inventory_full_after = inventory.is_full(player),
    fulfilled_now = true,
  }
end

local function _fulfill_skin(game, player, entry, opts, price, currency, priced_text)
  if not _charge_if_needed(game, player, currency, price, opts) then
    return { ok = false, reason = "charge_failed", body = player.name .. " 支付失败" }
  end
  context.consume_global_limit(game, entry.product_id)
  local role = runtime_ports.resolve_role(player.id)
  if role and type(role.get_ctrl_unit) == "function" then
    local unit = role.get_ctrl_unit()
    if unit and type(unit.change_custom_model_by_creature_key) == "function" then
      local creature_key = number_utils.to_integer(entry.product_id)
      if creature_key then
        unit.change_custom_model_by_creature_key(creature_key)
      else
        logger.warn("fulfill_skin: invalid product_id " .. tostring(entry.product_id))
      end
    else
      logger.warn("fulfill_skin: unit missing change_custom_model_by_creature_key for player " .. tostring(player.id))
    end
  else
    logger.warn("fulfill_skin: no role found for player " .. tostring(player.id))
  end
  _emit_event(monopoly_event.market.bought_item, {
    player = player,
    entry = entry,
    price = price,
    currency = currency,
    text = _success_text(player, entry, price, currency, priced_text),
  })
  return { ok = true, fulfilled_now = true }
end

function fulfillment.apply(game, player, entry, opts)
  opts = opts or {}
  local price = opts.price or context.entry_price(entry)
  local currency = opts.currency or context.entry_currency(entry)
  local priced_text = opts.priced_text == true

  if entry.kind == "item" then
    return _fulfill_item(game, player, entry, opts, price, currency, priced_text)
  end

  if entry.kind == "skin" then
    return _fulfill_skin(game, player, entry, opts, price, currency, priced_text)
  end

  return { ok = false, reason = "unsupported_kind", body = player.name .. " 该商品类型暂不支持购买" }
end

return fulfillment
