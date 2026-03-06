local logger = require("src.core.Logger")
local inventory = require("src.game.systems.items.ItemInventory")
local land_choice_specs = require("src.game.systems.land.LandChoiceSpecs")
local monopoly_event = require("src.core.events.MonopolyEvents")
local context = require("src.game.systems.market.service.Context")
local paid_purchase_gateway = require("src.game.systems.market.service.PaidPurchaseGateway")
local number_utils = require("src.core.NumberUtils")
local runtime_ports = require("src.core.RuntimePorts")
local action_anim_port = require("src.core.ActionAnimPort")

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

  if entry.kind == "item" then
    if inventory.is_full(player) then
      _emit_buy_failed(player, entry, "inventory_full", player.name .. " 卡槽已满")
      return false
    end
    inventory.give(player, product_id)
    context.consume_global_limit(game, product_id)
    _emit_event(monopoly_event.market.bought_item, {
      player = player,
      entry = entry,
      price = price,
      currency = currency,
      text = player.name .. " 在黑市购买 " .. context.entry_name(entry) .. " 成功",
    })
    return true
  end

  if entry.kind == "vehicle" then
    assert(game.set_player_seat ~= nil, "missing game.SetPlayerSeat")
    game:set_player_seat(player, product_id)
    context.consume_global_limit(game, product_id)
    _emit_event(monopoly_event.market.bought_vehicle, {
      player = player,
      entry = entry,
      price = price,
      currency = currency,
      text = player.name .. " 在黑市购买座驾 " .. context.entry_name(entry) .. " 成功",
    })
    return true
  end

  if entry.kind == "skin" then
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
      text = player.name .. " 在黑市购买皮肤（占位） " .. context.entry_name(entry) .. " 成功",
    })
    return true
  end

  _emit_buy_failed(player, entry, "unsupported_kind", player.name .. " 该商品类型暂不支持购买")
  return false
end

local function _refresh_market_choice_after_paid_callback(game, player, entry)
  local pending_choice = game and game.turn and game.turn.pending_choice or nil
  if not pending_choice or pending_choice.kind ~= "market_buy" then
    return
  end
  local meta = pending_choice.meta or {}
  local owner_id = number_utils.to_integer(meta.player_id)
  if owner_id ~= player.id then
    return
  end
  local market_service = require("src.game.systems.market.MarketService")
  local rebuilt = market_service.choice.rebuild_pending(game, pending_choice, player)
  if rebuilt then
    return
  end
  logger.warn(
    "market paid callback refresh skipped:",
    "player_id=" .. tostring(player.id),
    "product_id=" .. tostring(entry and entry.product_id)
  )
end

local function _handle_paid_purchase_callback(game, player, entry)
  local ok = _fulfill_paid_goods_purchase(game, player, entry)
  if ok then
    _refresh_market_choice_after_paid_callback(game, player, entry)
  end
end

function purchase.setup_for_game(game)
  paid_purchase_gateway.setup_for_game(game, _handle_paid_purchase_callback)
end

function purchase.can_start_external_purchase(game, player, entry)
  if entry.kind == "item" and inventory.is_full(player) then
    return false, "inventory_full"
  end
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
    if entry.kind == "item" and inventory.is_full(player) then
      _emit_buy_failed(player, entry, "inventory_full", player.name .. " 卡槽已满")
      return { ok = false }
    end
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

  if entry.kind == "item" then
    if inventory.is_full(player) then
      _emit_buy_failed(player, entry, "inventory_full", player.name .. " 卡槽已满")
      return { ok = false }
    end
    if not context.try_charge_player(game, player, currency, price) then
      _emit_buy_failed(player, entry, "charge_failed", player.name .. " 支付失败")
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
    return {
      ok = true,
      kind = "item",
      product_id = product_id,
      inventory_full_after = inventory.is_full(player),
      fulfilled_now = true,
    }
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
      _emit_buy_failed(player, entry, "charge_failed", player.name .. " 支付失败")
      return { ok = false }
    end
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
    return { ok = true, fulfilled_now = true }
  end

  if entry.kind == "skin" then
    if not context.try_charge_player(game, player, currency, price) then
      _emit_buy_failed(player, entry, "charge_failed", player.name .. " 支付失败")
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
    return { ok = true, fulfilled_now = true }
  end

  _emit_buy_failed(player, entry, "unsupported_kind", player.name .. " 该商品类型暂不支持购买")
  return { ok = false }
end

return purchase
