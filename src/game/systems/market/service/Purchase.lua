local logger = require("src.core.Logger")
local inventory = require("src.game.systems.items.ItemInventory")
local land_choice_specs = require("src.game.systems.land.LandChoiceSpecs")
local monopoly_event = require("src.core.events.MonopolyEvents")
local context = require("src.game.systems.market.service.Context")
local number_utils = require("src.core.NumberUtils")
local runtime_ports = require("src.core.RuntimePorts")
local action_anim_port = require("src.core.ActionAnimPort")

local purchase = {}
local _emit_event = monopoly_event.emit

local runtime_field = "__market_paid_runtime"
local panel_show_seconds = 10.0

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

local function _new_runtime()
  return {
    goods_id_by_product_id = {},
    product_id_by_goods_id = {},
    warned_missing_by_product_id = {},
    registered_role_ids = {},
    pending_by_role_id = {},
    setup_done = false,
  }
end

local function _runtime(game)
  local rt = game[runtime_field]
  if not rt then
    rt = _new_runtime()
    game[runtime_field] = rt
  end
  return rt
end

local function _resolve_role(player)
  if not player or player.id == nil then
    return nil
  end
  local ok, role = pcall(runtime_ports.resolve_role, player.id)
  if not ok then
    return nil
  end
  return role
end

local function _resolve_role_id(player, role)
  if role and type(role.get_roleid) == "function" then
    local ok, role_id = pcall(role.get_roleid)
    if ok and role_id ~= nil then
      return role_id
    end
  end
  return player and player.id or nil
end

local function _warn_mapping_missing_once(rt, entry, reason)
  local product_id = entry and entry.product_id or nil
  if product_id == nil then
    return
  end
  if rt.warned_missing_by_product_id[product_id] then
    return
  end
  rt.warned_missing_by_product_id[product_id] = true
  logger.warn(
    "market paid goods mapping missing:",
    "product_id=" .. tostring(product_id),
    "name=" .. tostring(entry and entry.name or ""),
    "currency=" .. tostring(entry and entry.currency or ""),
    "reason=" .. tostring(reason or "mapping_missing")
  )
end

local function _build_goods_mappings(game)
  local rt = _runtime(game)
  rt.goods_id_by_product_id = {}
  rt.product_id_by_goods_id = {}
  rt.warned_missing_by_product_id = {}

  local goods_by_name = {}
  local duplicate_name = {}
  local goods_list = nil
  if GameAPI and type(GameAPI.get_goods_list) == "function" then
    local ok, list = pcall(GameAPI.get_goods_list)
    if ok and type(list) == "table" then
      goods_list = list
    end
  end

  if type(goods_list) == "table" then
    for _, goods in ipairs(goods_list) do
      local name = goods and goods.name or nil
      if type(name) == "string" and name ~= "" then
        if goods_by_name[name] and goods_by_name[name] ~= goods then
          duplicate_name[name] = true
        else
          goods_by_name[name] = goods
        end
      end
    end
  end

  for _, entry in ipairs(context.entries()) do
    local currency = context.entry_currency(entry)
    if context.is_paid_currency(currency) then
      local market_name = entry and entry.name or nil
      local goods = market_name and goods_by_name[market_name] or nil
      local goods_id = goods and goods.goods_id or nil
      if goods_id ~= nil and goods_id ~= "" then
        rt.goods_id_by_product_id[entry.product_id] = goods_id
        local mapped_product_id = rt.product_id_by_goods_id[goods_id]
        if mapped_product_id == nil then
          rt.product_id_by_goods_id[goods_id] = entry.product_id
        elseif mapped_product_id ~= entry.product_id then
          logger.warn(
            "market paid goods ambiguous goods_id:",
            "goods_id=" .. tostring(goods_id),
            "product_id=" .. tostring(entry.product_id),
            "mapped_product_id=" .. tostring(mapped_product_id)
          )
        end
        if duplicate_name[market_name] then
          logger.warn(
            "market paid goods duplicate name match:",
            "name=" .. tostring(market_name),
            "product_id=" .. tostring(entry.product_id)
          )
        end
      else
        local reason = (type(goods_list) == "table") and "name_mapping_not_found" or "goods_list_unavailable"
        _warn_mapping_missing_once(rt, entry, reason)
      end
    end
  end
end

local function _resolve_goods_id(game, entry)
  local rt = _runtime(game)
  local goods_id = rt.goods_id_by_product_id[entry.product_id]
  if goods_id == nil or goods_id == "" then
    _warn_mapping_missing_once(rt, entry, "name_mapping_not_found")
    return nil, "goods_mapping_missing"
  end
  return goods_id, nil
end

local function _pending_queue(rt, role_id)
  local queue = rt.pending_by_role_id[role_id]
  if type(queue) ~= "table" then
    queue = {}
    rt.pending_by_role_id[role_id] = queue
  end
  return queue
end

local function _push_pending(rt, role_id, pending)
  local queue = _pending_queue(rt, role_id)
  queue[#queue + 1] = pending
end

local function _consume_pending(rt, role_id, goods_id)
  local queue = rt.pending_by_role_id[role_id]
  if type(queue) ~= "table" then
    return nil
  end
  local target_goods_id = tostring(goods_id)
  for index, pending in ipairs(queue) do
    if tostring(pending.goods_id) == target_goods_id then
      table.remove(queue, index)
      if #queue == 0 then
        rt.pending_by_role_id[role_id] = nil
      end
      return pending
    end
  end
  return nil
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

local function _on_purchase_event(game, data)
  local rt = _runtime(game)
  local role = data and data.role or nil
  local goods_id = data and data.goods_id or nil
  if goods_id == nil or goods_id == "" then
    logger.warn("market paid callback ignored: goods_id missing")
    return
  end
  local role_id = _resolve_role_id(nil, role)
  local pending = role_id and _consume_pending(rt, role_id, goods_id) or nil
  if not pending then
    logger.warn("market paid callback ignored: pending missing", "role_id=" .. tostring(role_id), "goods_id=" .. tostring(goods_id))
    return
  end
  local player = game:find_player_by_id(pending.player_id)
  if not player then
    logger.warn("market paid callback ignored: player missing", "player_id=" .. tostring(pending.player_id))
    return
  end
  local entry = context.entry_by_id(pending.product_id)
  if not entry then
    logger.warn("market paid callback ignored: market entry missing", "product_id=" .. tostring(pending.product_id))
    return
  end
  local ok = _fulfill_paid_goods_purchase(game, player, entry)
  if ok then
    _refresh_market_choice_after_paid_callback(game, player, entry)
  end
end

local function _register_purchase_event_for_role(game, player)
  if not RegisterTriggerEvent or not EVENT or not EVENT.SPEC_ROLE_PURCHASE_GOODS then
    return
  end
  local role = _resolve_role(player)
  if not role then
    return
  end
  local role_id = _resolve_role_id(player, role)
  if role_id == nil then
    return
  end
  local rt = _runtime(game)
  if rt.registered_role_ids[role_id] then
    return
  end
  RegisterTriggerEvent({ EVENT.SPEC_ROLE_PURCHASE_GOODS, role_id }, function(_, _, data)
    _on_purchase_event(game, data)
  end)
  rt.registered_role_ids[role_id] = true
end

function purchase.setup_for_game(game)
  local rt = _runtime(game)
  if rt.setup_done == true then
    return
  end
  _build_goods_mappings(game)
  local players = game and game.players or nil
  if type(players) ~= "table" then
    rt.setup_done = true
    return
  end
  for _, player in ipairs(players) do
    _register_purchase_event_for_role(game, player)
  end
  rt.setup_done = true
end

function purchase.can_start_external_purchase(game, player, entry)
  if entry.kind == "item" and inventory.is_full(player) then
    return false, "inventory_full"
  end
  purchase.setup_for_game(game)
  local goods_id, goods_reason = _resolve_goods_id(game, entry)
  if goods_id == nil then
    return false, goods_reason or "goods_mapping_missing"
  end
  local role = _resolve_role(player)
  if not role then
    return false, "role_unresolved"
  end
  if type(role.show_goods_purchase_panel) ~= "function" then
    return false, "purchase_api_missing"
  end
  return true, goods_id
end

local function _start_external_purchase(game, player, entry)
  local ok_ready, goods_or_reason = purchase.can_start_external_purchase(game, player, entry)
  if not ok_ready then
    return false, goods_or_reason
  end
  local goods_id = goods_or_reason
  local role = _resolve_role(player)
  if not role then
    return false, "role_unresolved"
  end
  local ok_call = pcall(role.show_goods_purchase_panel, goods_id, panel_show_seconds)
  if not ok_call then
    return false, "panel_call_failed"
  end
  local role_id = _resolve_role_id(player, role)
  if role_id == nil then
    return false, "role_id_missing"
  end
  local rt = _runtime(game)
  _push_pending(rt, role_id, {
    player_id = player.id,
    product_id = entry.product_id,
    goods_id = goods_id,
  })
  return true, nil
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
    if entry.kind == "item" and inventory.is_full(player) then
      _emit_buy_failed(player, entry, "inventory_full", player.name .. " 卡槽已满")
      return { ok = false }
    end
    local ok_start, reason = _start_external_purchase(game, player, entry)
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
