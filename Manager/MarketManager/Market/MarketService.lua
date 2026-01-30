local market_cfg = require("Config.Market")
local items_cfg = require("Config.Items")
local vehicles_cfg = require("Config.Vehicles")
local logger = require("Library.Monopoly.Logger")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")
local Agent = require("Manager.GameManager.Agent")
local LandChoiceSpecs = require("Manager.LandManager.Land.LandChoiceSpecs")
local MarketService = {}

local function emit_event(game, kind, payload)
  if game and game.events and game.events.emit then
    game.events:emit(kind, payload)
  end
end

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

local function entry_name(entry)
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

local function vehicle_name(seat_id)
  if seat_id then
    local cfg = vehicles_by_id[seat_id]
    if cfg then
      return cfg.name
    end
    return tostring(seat_id)
  end
  return "无"
end

local function entry_price(entry)
  return entry.price or 0
end

local function entry_currency(entry)
  local currency = entry.currency
  if currency == nil or currency == "" then
    return "金币"
  end
  return currency
end

local function remaining_global_limit(game, product_id)
  if not (game and game.store and product_id) then
    return nil
  end
  return game.store:get({ "market", "global_limits", product_id })
end

local function can_buy_entry(game, player, entry)
  if entry.kind == "item" and Inventory.is_full(player) then
    return false
  end
  local remaining = remaining_global_limit(game, entry.product_id)
  if remaining ~= nil and remaining <= 0 then
    return false
  end
  local price = entry_price(entry)
  return player:balance(entry_currency(entry)) >= price
end

function MarketService.list_buyable(player, game)
  local list = {}
  for _, entry in ipairs(market_cfg) do
    if can_buy_entry(game, player, entry) then
      table.insert(list, entry)
    end
  end
  table.sort(list, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return list
end

function MarketService.build_choice_spec(player, game)
  local options = {}
  local body_lines = {}
  for _, entry in ipairs(MarketService.list_buyable(player, game)) do
    local name = entry_name(entry)
    local price = entry_price(entry)
    local currency = entry_currency(entry)
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

function MarketService.buy(game, player, product_id)
  return MarketService.buy_with_opts(game, player, product_id, nil)
end

local function consume_global_limit(game, product_id)
  if not (game and game.store and product_id) then
    return
  end
  local remaining = remaining_global_limit(game, product_id)
  if remaining == nil then
    return
  end
  local next_remaining = remaining - 1
  if next_remaining < 0 then
    next_remaining = 0
  end
  game.store:set({ "market", "global_limits", product_id }, next_remaining)
end

function MarketService.buy_with_opts(game, player, product_id, opts)
  opts = opts or {}
  if type(product_id) ~= "number" or product_id <= 0 then
    logger.warn("invalid market product id:", tostring(product_id))
    return false
  end
  local entry = entries_by_id[product_id]
  if not entry then return false end

  local remaining = remaining_global_limit(game, product_id)
  if remaining ~= nil and remaining <= 0 then
    emit_event(game, "market.buy_failed", {
      player = player,
      entry = entry,
      reason = "sold_out",
      popup = { title = "黑市", body = player.name .. " 该商品已售罄" },
    })
    return { ok = false }
  end

  local price = entry_price(entry)
  local currency = entry_currency(entry)
  if player:balance(currency) < price then
    emit_event(game, "market.buy_failed", {
      player = player,
      entry = entry,
      reason = "insufficient_balance",
      popup = { title = "黑市", body = player.name .. " 余额不足" },
    })
    return { ok = false }
  end

  if entry.kind == "item" then
    if Inventory.is_full(player) then
      emit_event(game, "market.buy_failed", {
        player = player,
        entry = entry,
        reason = "inventory_full",
        popup = { title = "黑市", body = player.name .. " 卡槽已满" },
      })
      return { ok = false }
    end
    player:deduct_balance(currency, price)
    Inventory.give(player, product_id)
    consume_global_limit(game, product_id)
    emit_event(game, "market.bought_item", {
      player = player,
      entry = entry,
      price = price,
      currency = currency,
      text = player.name .. " 在黑市购买 " .. entry_name(entry) .. " 花费 " .. price .. " " .. currency,
    })
    return true
  end

  if player.seat_id and not opts.skip_vehicle_prompt then
    local current_name = vehicle_name(player.seat_id)
    local next_name = entry_name(entry)
    return {
      ok = false,
      intent = {
        kind = "need_choice",
        choice_spec = LandChoiceSpecs.build_use_skip(
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

  if game and game.set_player_seat then
    game:set_player_seat(player, product_id)
  else
    player.seat_id = product_id
  end
  consume_global_limit(game, product_id)
  emit_event(game, "market.bought_vehicle", {
    player = player,
    entry = entry,
    price = price,
    currency = currency,
    text = player.name .. " 在黑市购买座驾 " .. entry_name(entry) .. " 花费 " .. price .. " " .. currency,
  })
  return true
end

function MarketService.auto_buy(game, player)
  if Agent.is_auto_player(player) then
    emit_event(game, "market.auto_skip", {
      player = player,
      text = player.name .. " (AI) 到达黑市，选择不购买",
    })
    return
  end

  local list = MarketService.list_buyable(player, game)
  table.sort(list, function(a, b)
    return (entry_price(a) or 0) < (entry_price(b) or 0)
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
      MarketService.buy_with_opts(game, player, chosen.product_id, { skip_vehicle_prompt = true })
    end
  end
end

return MarketService

