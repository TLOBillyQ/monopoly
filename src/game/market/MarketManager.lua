local market_cfg = require("Config.Generated.Market")
local items_cfg = require("Config.Generated.Items")
local vehicles_cfg = require("Config.Generated.Vehicles")
local logger = require("src.core.Logger")
local inventory = require("src.game.item.ItemInventory")
local agent = require("src.game.game.Agent")
local land_choice_specs = require("src.game.land.LandChoiceSpecs")
local monopoly_event = require("src.game.game.MonopolyEvents")
local market_manager = {}
local _emit_event = monopoly_event.emit

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

local function _remaining_global_limit(game, product_id)
  assert(game ~= nil, "missing game")
  assert(game.store ~= nil, "missing game.store")
  assert(product_id ~= nil, "missing product_id")
  return game.store:get({ "market", "global_limits", product_id })
end

local function _can_buy_entry(game, player, entry)
  if entry.kind == "item" and inventory.is_full(player) then
    return false
  end
  local remaining = _remaining_global_limit(game, entry.product_id)
  if remaining <= 0 then
    return false
  end
  local price = _entry_price(entry)
  return player:balance(_entry_currency(entry)) >= price
end

function market_manager.list_buyable(player, game)
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

function market_manager.build_choice_spec(player, game)
  local options = {}
  local body_lines = {}
  for _, entry in ipairs(market_manager.list_buyable(player, game)) do
    local name = _entry_name(entry)
    local price = _entry_price(entry)
    local currency = _entry_currency(entry)
    local label = name .. " - " .. price .. " " .. currency
    table.insert(body_lines, label)
    table.insert(options, { id = entry.product_id, label = label })
  end

  if #options == 0 then
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
  assert(game.store ~= nil, "missing game.store")
  assert(product_id ~= nil, "missing product_id")
  local remaining = assert(_remaining_global_limit(game, product_id), "missing global limit")
  local next_remaining = remaining - 1
  if next_remaining < 0 then
    next_remaining = 0
  end
  game.store:set({ "market", "global_limits", product_id }, next_remaining)
end

function market_manager.buy_with_opts(game, player, product_id, opts)
  opts = opts or {}
  if type(product_id) ~= "number" or product_id <= 0 then
    logger.warn("invalid market product id:", tostring(product_id))
    return false
  end
  local entry = entries_by_id[product_id]
  assert(entry ~= nil, "missing market entry: " .. tostring(product_id))

  local remaining = _remaining_global_limit(game, product_id)
  if remaining <= 0 then
    _emit_event(monopoly_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "sold_out",
      popup = { title = "黑市", body = player.name .. " 该商品已售罄" },
    })
    return { ok = false }
  end

  local price = _entry_price(entry)
  local currency = _entry_currency(entry)
  if player:balance(currency) < price then
    _emit_event(monopoly_event.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "insufficient_balance",
      popup = { title = "黑市", body = player.name .. " 余额不足" },
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
    player:deduct_balance(currency, price)
    inventory.give(player, product_id)
    _consume_global_limit(game, product_id)
    _emit_event(monopoly_event.market.bought_item, {
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

  player:deduct_balance(currency, price)

  assert(game ~= nil, "missing game")
  assert(game.set_player_seat ~= nil, "missing game.SetPlayerSeat")
  game:set_player_seat(player, product_id)
  _consume_global_limit(game, product_id)
  _emit_event(monopoly_event.market.bought_vehicle, {
    player = player,
    entry = entry,
    price = price,
    currency = currency,
    text = player.name .. " 在黑市购买座驾 " .. _entry_name(entry) .. " 花费 " .. price .. " " .. currency,
  })
  return true
end

function market_manager.auto_buy(game, player)
  if agent.is_auto_player(player) then
    _emit_event(monopoly_event.market.auto_skip, {
      player = player,
      text = player.name .. " (AI) 到达黑市，选择不购买",
    })
    return
  end

  local list = market_manager.list_buyable(player, game)
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
      market_manager.buy_with_opts(game, player, chosen.product_id, { skip_vehicle_prompt = true })
    end
  end
end

return market_manager


