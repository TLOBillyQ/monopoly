local logger = require("src.core.Logger")
local inventory = require("src.game.systems.items.ItemInventory")
local agent = require("src.game.core.runtime.Agent")
local land_choice_specs = require("src.game.systems.land.LandChoiceSpecs")
local monopoly_event = require("src.core.events.MonopolyEvents")
local context = require("src.game.systems.market.service.Context")
local number_utils = require("src.core.NumberUtils")
local runtime_ports = require("src.core.RuntimePorts")
local action_anim_port = require("src.core.ActionAnimPort")

local purchase = {}
local _emit_event = monopoly_event.emit

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
    _emit_event(monopoly_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "vehicle_disabled",
      popup = { title = "黑市", body = player.name .. " 当前对局已关闭载具功能" },
    })
    return { ok = false }
  end

  if not context.entry_market_enabled(entry) then
    _emit_event(monopoly_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "disabled",
      popup = { title = "黑市", body = player.name .. " 该商品暂不可购买" },
    })
    return { ok = false }
  end

  local remaining = context.remaining_global_limit(game, product_id)
  if remaining <= 0 then
    _emit_event(monopoly_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "sold_out",
      popup = { title = "黑市", body = player.name .. " 该商品已售罄" },
    })
    return { ok = false }
  end

  local price = context.entry_price(entry)
  local currency = context.entry_currency(entry)
  context.sync_managed_balance(game, player, currency)
  if game:player_balance(player, currency) < price then
    local opened_panel = false
    if not agent.is_auto_player(player) then
      opened_panel = context.open_purchase_panel_if_needed(game, player, currency)
    end
    local body = player.name .. " 余额不足"
    if opened_panel then
      body = player.name .. " 余额不足，已打开购买面板"
    end
    _emit_event(monopoly_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "insufficient_balance",
      popup = { title = "黑市", body = body },
    })
    return { ok = false }
  end

  if entry.kind == "item" then
    if inventory.is_full(player) then
      _emit_event(monopoly_event.market.buy_failed, {
        player = player,
        entry = entry,
        reason = "inventory_full",
        popup = { title = "黑市", body = player.name .. " 卡槽已满" },
      })
      return { ok = false }
    end
    if not context.try_charge_player(game, player, currency, price) then
      _emit_event(monopoly_event.market.buy_failed, {
        player = player,
        entry = entry,
        reason = "charge_failed",
        popup = { title = "黑市", body = player.name .. " 支付失败" },
      })
      return { ok = false }
    end

    inventory.give(player, product_id)
    context.consume_global_limit(game, product_id)
    _emit_event(monopoly_event.market.bought_item, {
      player = player,
      entry = entry,
      price = price,
      currency = currency,
      text = player.name .. " 在黑市购买 " .. context.entry_name(entry) .. " 花费 " .. number_utils.format_integer_part(price) .. " " .. currency,
    })
    return true
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

    if not context.try_charge_player(game, player, currency, price) then
      _emit_event(monopoly_event.market.buy_failed, {
        player = player,
        entry = entry,
        reason = "charge_failed",
        popup = { title = "黑市", body = player.name .. " 支付失败" },
      })
      return { ok = false }
    end

    assert(game ~= nil, "missing game")
    assert(game.set_player_seat ~= nil, "missing game.SetPlayerSeat")
    game:set_player_seat(player, product_id)
    context.consume_global_limit(game, product_id)
    _emit_event(monopoly_event.market.bought_vehicle, {
      player = player,
      entry = entry,
      price = price,
      currency = currency,
      text = player.name .. " 在黑市购买座驾 " .. context.entry_name(entry) .. " 花费 " .. number_utils.format_integer_part(price) .. " " .. currency,
    })
    return true
  end

  if entry.kind == "skin" then
    if not context.try_charge_player(game, player, currency, price) then
      _emit_event(monopoly_event.market.buy_failed, {
        player = player,
        entry = entry,
        reason = "charge_failed",
        popup = { title = "黑市", body = player.name .. " 支付失败" },
      })
      return { ok = false }
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
      text = player.name .. " 在黑市购买皮肤（占位） " .. context.entry_name(entry) .. " 花费 " .. number_utils.format_integer_part(price) .. " " .. currency,
    })
    return true
  end

  _emit_event(monopoly_event.market.buy_failed, {
    player = player,
    entry = entry,
    reason = "unsupported_kind",
    popup = { title = "黑市", body = player.name .. " 该商品类型暂不支持购买" },
  })
  return { ok = false }
end

return purchase

