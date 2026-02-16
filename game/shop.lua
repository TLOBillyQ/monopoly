local market_cfg = require("cfg.Generated.Market")
local items_cfg = require("cfg.Generated.Items")
local vehicles_cfg = require("cfg.Generated.Vehicles")
local logger = require("core.logger")
local inventory = require("game.item.inventory")
local agent = require("game.rule.agent")
local choice_spec = require("game.land.choice_spec")
local game_event = require("game.event")
local paid_currency_bridge = require("game.commerce.paid_bridge")
local vehicle_feature = require("game.vehicle")

local shop = {}
local _emit_event = game_event.emit

local items_by_id = {}
for _, cfg in ipairs(items_cfg) do
  items_by_id[cfg.id] = cfg
end

local vehicles_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicles_by_id[cfg.id] = cfg
end

local entries_by_id = {}
for _, entry in ipairs(market_cfg) do
  entries_by_id[entry.product_id] = entry
end

local function _entry_name(entry)
  if entry.kind == "vehicle" then
    local cfg = vehicles_by_id[entry.product_id]
    if cfg then
      return cfg.name
    end
    if entry.name then
      return entry.name
    end
    return tostring(entry.product_id)
  end
  local cfg = items_by_id[entry.product_id]
  if cfg then
    return cfg.name
  end
  if entry.name then
    return entry.name
  end
  return tostring(entry.product_id)
end

local function _vehicle_name(seat_id)
  if seat_id then
    local cfg = vehicles_by_id[seat_id]
    if cfg then
      return cfg.name
    end
    return tostring(seat_id)
  end
  return "无"
end

local function _entry_price(entry)
  return entry.price or 0
end

local function _entry_currency(entry)
  local currency = entry.currency
  if currency and currency ~= "" then
    return currency
  end
  return "金币"
end

local function _entry_market_enabled(entry)
  assert(entry ~= nil, "missing market entry")
  return entry.market_enabled ~= false
end

local function _entry_vehicle_enabled(entry)
  if not vehicle_feature.is_vehicle_market_entry(entry) then
    return true
  end
  return vehicle_feature.is_enabled()
end

local function _remaining_global_limit(game, product_id)
  assert(game ~= nil, "missing game")
  assert(product_id ~= nil, "missing product_id")
  return game.market_limits[product_id]
end

local function _sync_managed_balance(game, player, currency)
  if paid_currency_bridge.is_managed_currency(game, currency) then
    paid_currency_bridge.sync_player_currency(game, player, currency)
  end
end

local function _try_charge_player(game, player, currency, price)
  if paid_currency_bridge.is_managed_currency(game, currency) then
    return paid_currency_bridge.consume_currency(game, player, currency, price)
  end
  game:deduct_player_balance(player, currency, price)
  return true
end

local function _can_buy_entry(game, player, entry)
  if not _entry_vehicle_enabled(entry) then
    return false
  end
  if not _entry_market_enabled(entry) then
    return false
  end
  if entry.kind == "item" and inventory.is_full(player) then
    return false
  end
  local remaining = _remaining_global_limit(game, entry.product_id)
  if remaining <= 0 then
    return false
  end
  local price = _entry_price(entry)
  local currency = _entry_currency(entry)
  _sync_managed_balance(game, player, currency)
  return game:player_balance(player, currency) >= price
end

function shop.list_buyable(player, game)
  local list = {}
  for _, entry in ipairs(market_cfg) do
    if _can_buy_entry(game, player, entry) then
      table.insert(list, entry)
    end
  end
  table.sort(list, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return list
end

local function _sorted_market_entries()
  local entries = {}
  for _, entry in ipairs(market_cfg) do
    table.insert(entries, entry)
  end
  table.sort(entries, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return entries
end

local function _build_visible_entries(player, game, limit)
  local buyable = {}
  local unbuyable = {}
  for _, entry in ipairs(_sorted_market_entries()) do
    if _can_buy_entry(game, player, entry) then
      buyable[#buyable + 1] = entry
    else
      unbuyable[#unbuyable + 1] = entry
    end
  end
  local visible = {}
  for _, entry in ipairs(buyable) do
    visible[#visible + 1] = { entry = entry, can_buy = true }
    if limit and #visible >= limit then
      return visible, buyable
    end
  end
  for _, entry in ipairs(unbuyable) do
    visible[#visible + 1] = { entry = entry, can_buy = false }
    if limit and #visible >= limit then
      return visible, buyable
    end
  end
  return visible, buyable
end

function shop.build_choice_spec(player, game)
  local options = {}
  local body_lines = {}
  local visible, buyable = _build_visible_entries(player, game, 10)
  for _, slot in ipairs(visible) do
    local entry = slot.entry
    local name = _entry_name(entry)
    local price = _entry_price(entry)
    local currency = _entry_currency(entry)
    local label = name .. " - " .. price .. " " .. currency
    table.insert(body_lines, label)
    table.insert(options, { id = entry.product_id, label = label, can_buy = slot.can_buy })
  end

  if #buyable == 0 then
    return nil, { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 暂无可购买商品" } }
  end

  return {
    kind = "market_buy",
    title = "黑市",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "不买",
    meta = { player_id = player.id },
  }
end

local function _consume_global_limit(game, product_id)
  assert(game ~= nil, "missing game")
  assert(product_id ~= nil, "missing product_id")
  local remaining = assert(game.market_limits[product_id], "missing global limit")
  local next_remaining = remaining - 1
  if next_remaining < 0 then
    next_remaining = 0
  end
  game.market_limits[product_id] = next_remaining
  game.dirty.market = true
  game.dirty.any = true
end

function shop.buy_with_opts(game, player, product_id, opts)
  opts = opts or {}
  if type(product_id) ~= "number" or product_id <= 0 then
    logger.warn("invalid market product id:", tostring(product_id))
    return false
  end
  local entry = entries_by_id[product_id]
  assert(entry ~= nil, "missing market entry: " .. tostring(product_id))
  if not _entry_vehicle_enabled(entry) then
    _emit_event(game_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "vehicle_disabled",
      popup = { title = "黑市", body = player.name .. " 当前对局已关闭载具功能" },
    })
    return { ok = false }
  end
  if not _entry_market_enabled(entry) then
    _emit_event(game_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "disabled",
      popup = { title = "黑市", body = player.name .. " 该商品暂不可购买" },
    })
    return { ok = false }
  end

  local remaining = _remaining_global_limit(game, product_id)
  if remaining <= 0 then
    _emit_event(game_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "sold_out",
      popup = { title = "黑市", body = player.name .. " 该商品已售罄" },
    })
    return { ok = false }
  end

  local price = _entry_price(entry)
  local currency = _entry_currency(entry)
  _sync_managed_balance(game, player, currency)
  if game:player_balance(player, currency) < price then
    local opened_panel = false
    if paid_currency_bridge.is_managed_currency(game, currency) and not agent.is_auto_player(player) then
      opened_panel = paid_currency_bridge.open_purchase_panel(game, player, currency)
    end
    local body = player.name .. " 余额不足"
    if opened_panel then
      body = player.name .. " 余额不足，已打开购买面板"
    end
    _emit_event(game_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "insufficient_balance",
      popup = { title = "黑市", body = body },
    })
    return { ok = false }
  end

  if entry.kind == "item" then
    if inventory.is_full(player) then
      _emit_event(game_event.market.buy_failed, {
        player = player,
        entry = entry,
        reason = "inventory_full",
        popup = { title = "黑市", body = player.name .. " 卡槽已满" },
      })
      return { ok = false }
    end
    if not _try_charge_player(game, player, currency, price) then
      _emit_event(game_event.market.buy_failed, {
        player = player,
        entry = entry,
        reason = "charge_failed",
        popup = { title = "黑市", body = player.name .. " 支付失败" },
      })
      return { ok = false }
    end
    inventory.give(player, product_id)
    _consume_global_limit(game, product_id)
    _emit_event(game_event.market.bought_item, {
      player = player,
      entry = entry,
      price = price,
      currency = currency,
      text = player.name .. " 在黑市购买 " .. _entry_name(entry) .. " 花费 " .. price .. " " .. currency,
    })
    return true
  end

  if player.seat_id and not opts.skip_vehicle_prompt then
    local current_name = _vehicle_name(player.seat_id)
    local next_name = _entry_name(entry)
    return {
      ok = false,
      intent = {
        kind = "need_choice",
        choice_spec = choice_spec.build_use_skip(
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

  if not _try_charge_player(game, player, currency, price) then
    _emit_event(game_event.market.buy_failed, {
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
  _consume_global_limit(game, product_id)
  _emit_event(game_event.market.bought_vehicle, {
    player = player,
    entry = entry,
    price = price,
    currency = currency,
    text = player.name .. " 在黑市购买座驾 " .. _entry_name(entry) .. " 花费 " .. price .. " " .. currency,
  })
  return true
end

function shop.auto_buy(game, player)
  if agent.is_auto_player(player) then
    _emit_event(game_event.market.auto_skip, {
      player = player,
      text = player.name .. " (AI) 到达黑市，选择不购买",
    })
    return
  end

  local list = shop.list_buyable(player, game)
  table.sort(list, function(a, b)
    return (_entry_price(a) or 0) < (_entry_price(b) or 0)
  end)
  if #list > 0 then
    local chosen = nil
    for _, entry in ipairs(list) do
      if entry.kind ~= "vehicle" or not player.seat_id then
        chosen = entry
        break
      end
    end
    if chosen then
      shop.buy_with_opts(game, player, chosen.product_id, { skip_vehicle_prompt = true })
    end
  end
end

return shop
