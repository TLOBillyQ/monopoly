local inventory = require("src.game.systems.items.item_inventory")
local context = require("src.game.systems.market.service.context")
local monopoly_event = require("src.core.events.monopoly_events")
local number_utils = require("src.core.utils.number_utils")
local runtime_ports = require("src.core.ports.runtime_ports")
local action_anim_port = require("src.core.ports.action_anim_port")

local fulfillment = {}
local _emit_event = monopoly_event.emit

local function _success_text(player, entry, price, currency, priced)
  local name = context.entry_name(entry)
  if entry.kind == "vehicle" then
    if priced then
      return player.name .. " 在黑市购买座驾 " .. name .. " 花费 " .. number_utils.format_integer_part(price) .. " " .. currency
    end
    return player.name .. " 在黑市购买座驾 " .. name .. " 成功"
  end
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
  return context.try_charge_player(game, player, currency, price)
end

function fulfillment.apply(game, player, entry, opts)
  opts = opts or {}
  local product_id = entry.product_id
  local price = opts.price or context.entry_price(entry)
  local currency = opts.currency or context.entry_currency(entry)
  local priced_text = opts.priced_text == true

  if entry.kind == "item" then
    if inventory.is_full(player) then
      return { ok = false, reason = "inventory_full", body = player.name .. " 卡槽已满" }
    end
    if not _charge_if_needed(game, player, currency, price, opts) then
      return { ok = false, reason = "charge_failed", body = player.name .. " 支付失败" }
    end
    inventory.give(player, product_id)
    context.consume_global_limit(game, product_id)
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
      product_id = product_id,
      inventory_full_after = inventory.is_full(player),
      fulfilled_now = true,
    }
  end

  if entry.kind == "vehicle" then
    if not _charge_if_needed(game, player, currency, price, opts) then
      return { ok = false, reason = "charge_failed", body = player.name .. " 支付失败" }
    end
    assert(game.set_player_seat ~= nil, "missing game.SetPlayerSeat")
    game:set_player_seat(player, product_id)
    context.consume_global_limit(game, product_id)
    _emit_event(monopoly_event.market.bought_vehicle, {
      player = player,
      entry = entry,
      price = price,
      currency = currency,
      text = _success_text(player, entry, price, currency, priced_text),
    })
    return { ok = true, fulfilled_now = true }
  end

  if entry.kind == "skin" then
    if not _charge_if_needed(game, player, currency, price, opts) then
      return { ok = false, reason = "charge_failed", body = player.name .. " 支付失败" }
    end
    context.consume_global_limit(game, product_id)
    local change_skin_helper = runtime_ports.resolve_change_skin_helper()
    if change_skin_helper and type(change_skin_helper.emit_change_skin) == "function" then
      change_skin_helper.emit_change_skin(player.id, entry.product_id)
    end
    action_anim_port.queue(game, {
      kind = "change_skin",
      player_id = player.id,
      skin_id = entry.product_id,
      skin_name = context.entry_name(entry),
      duration = 1.0,
    })
    _emit_event(monopoly_event.market.bought_item, {
      player = player,
      entry = entry,
      price = price,
      currency = currency,
      text = _success_text(player, entry, price, currency, priced_text),
    })
    return { ok = true, fulfilled_now = true }
  end

  return { ok = false, reason = "unsupported_kind", body = player.name .. " 该商品类型暂不支持购买" }
end

return fulfillment
