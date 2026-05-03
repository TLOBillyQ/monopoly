local inventory = require("src.rules.items.inventory")
local context = require("src.rules.market.query.context")
local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.lang.number")
local runtime_refs = require("src.config.content.runtime_refs")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local logger = require("src.foundation.log.logger")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")

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
  _emit_bought_item(game, {
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

local function _try_apply_skin_to_unit(player_id, creature_key)
  local role = runtime_ports.resolve_role(player_id)
  if not (role and type(role.get_ctrl_unit) == "function") then
    logger.warn("fulfill_skin: no role found for player " .. tostring(player_id))
    return
  end
  local ok_unit, unit = pcall(role.get_ctrl_unit)
  if not ok_unit then
    logger.warn("fulfill_skin: role get_ctrl_unit failed for player " .. tostring(player_id))
    unit = nil
  end
  if not (unit and type(unit.set_model_by_creature_key) == "function") then
    logger.warn("fulfill_skin: unit missing set_model_by_creature_key for player " .. tostring(player_id))
    return
  end
  if creature_key then
    local ok_change = pcall(unit.set_model_by_creature_key, creature_key, true, true, true)
      or pcall(unit.set_model_by_creature_key, unit, creature_key, true, true, true)
      or pcall(unit.set_model_by_creature_key, creature_key)
      or pcall(unit.set_model_by_creature_key, unit, creature_key)
    if not ok_change then
      logger.warn("fulfill_skin: set_model_by_creature_key failed for player " .. tostring(player_id))
    end
  else
    logger.warn("fulfill_skin: invalid product_id for player " .. tostring(player_id))
  end
end

local function _fulfill_skin(game, player, entry, opts, price, currency, priced_text)
  if not _charge_if_needed(game, player, currency, price, opts) then
    return { ok = false, reason = "charge_failed", body = player.name .. " 支付失败" }
  end
  context.consume_global_limit(game, entry.product_id)
  local product_id_key = tostring(entry.product_id)
  local creature_key = runtime_refs.skins[product_id_key]
  if creature_key == nil then
    creature_key = number_utils.to_integer(entry.product_id)
  end
  _try_apply_skin_to_unit(player.id, creature_key)
  _emit_bought_item(game, {
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
