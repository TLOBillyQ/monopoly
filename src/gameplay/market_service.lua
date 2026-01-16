local market_cfg = require("src.config.market")
local items_cfg = require("src.config.items")
local vehicles_cfg = require("src.config.vehicles")
local logger = require("src.util.logger")
local Choice = require("src.gameplay.choice")
local Inventory = require("src.gameplay.item_inventory")
local Agent = require("src.gameplay.agent")

local MarketService = {}

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
    return (cfg and cfg.name) or entry.name or tostring(entry.product_id)
  end
  local cfg = items_by_id[entry.product_id]
  return (cfg and cfg.name) or entry.name or tostring(entry.product_id)
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

local function can_buy_entry(player, entry)
  local price = entry_price(entry)
  return player:balance(entry_currency(entry)) >= price
end

function MarketService.list_buyable(player)
  local list = {}
  for _, entry in ipairs(market_cfg) do
    if can_buy_entry(player, entry) then
      table.insert(list, entry)
    end
  end
  table.sort(list, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return list
end

function MarketService.build_choice_spec(player)
  if not player then return nil end

  local options = {}
  local body_lines = {}
  for _, entry in ipairs(MarketService.list_buyable(player)) do
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
  if not player or not product_id then return false end
  local entry = entries_by_id[product_id]
  if not entry then return false end

  local price = entry_price(entry)
  local currency = entry_currency(entry)
  if player:balance(currency) < price then
    return { ok = false, intent = { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 余额不足" } } }
  end

  if entry.kind == "item" then
    if player.inventory and player.inventory:is_full() then
      return { ok = false, intent = { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 卡槽已满" } } }
    end
    player:deduct_balance(currency, price)
    Inventory.give(player, product_id)
    logger.event(player.name .. " 在黑市购买 " .. entry_name(entry) .. " 花费 " .. price .. " " .. currency)
    return true
  end

  player:deduct_balance(currency, price)

  if game and game.set_player_seat then
    game:set_player_seat(player, product_id)
  else
    player.seat_id = product_id
  end
  logger.event(player.name .. " 在黑市购买座驾 " .. entry_name(entry) .. " 花费 " .. price .. " " .. currency)
  return true
end

-- 机会卡传送到黑市时使用：AI自动购买最便宜的一个
function MarketService.auto_buy(game, player)
  -- AI玩家不主动购买，避免破产
  if Agent.is_auto_player(player) then
    logger.event(player.name .. " (AI) 到达黑市，选择不购买")
    return
  end

  local list = MarketService.list_buyable(player)
  table.sort(list, function(a, b)
    return (entry_price(a) or 0) < (entry_price(b) or 0)
  end)
  if #list > 0 then
    MarketService.buy(game, player, list[1].product_id)
  end
end

local function as_number(v)
  return type(v) == "number" and v or tonumber(v)
end

function MarketService.handle_choice(game, choice, action)
  if not choice or choice.kind ~= "market_buy" then
    return nil
  end

  if not action or action.type == "choice_cancel" or action.option_id == nil then
    Choice.clear(game)
    return { stay = false }
  end

  local product_id = as_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  if player and product_id then
    local entry = entries_by_id[product_id]
    if entry and entry.kind == "vehicle" and player.seat_id and player.seat_id ~= product_id then
      local current_name = (player.vehicle_name and player:vehicle_name()) or tostring(player.seat_id)
      Choice.open(game, {
        kind = "market_replace_vehicle",
        title = "更换座驾",
        body_lines = { "您已经有" .. current_name .. "了，是否更换座驾" },
        options = {
          { id = "buy", label = "购买" },
          { id = "skip", label = "算了" },
        },
        allow_cancel = false,
        meta = { player_id = player.id, product_id = product_id },
      })
      return { stay = true }
    end
    MarketService.buy(game, player, product_id)
  end
  Choice.clear(game)
  return { stay = false }
end

return MarketService
