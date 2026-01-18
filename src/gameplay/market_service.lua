local market_cfg = require("src.config.market")
local items_cfg = require("src.config.items")
local vehicles_cfg = require("src.config.vehicles")
local logger = require("src.util.logger")
local Inventory = require("src.gameplay.item_inventory")
local Agent = require("src.gameplay.agent")
local LandChoiceSpecs = require("src.gameplay.land_choice_specs")
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

local function vehicle_name(seat_id)
  local cfg = seat_id and vehicles_by_id[seat_id]
  return cfg and cfg.name or (seat_id and tostring(seat_id)) or "无"
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
  if entry.kind == "item" and player.inventory and player.inventory:is_full() then
    return false
  end
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
  return MarketService.buy_with_opts(game, player, product_id, nil)
end

function MarketService.buy_with_opts(game, player, product_id, opts)
  opts = opts or {}
  if not player then return false end
  if type(product_id) ~= "number" or product_id <= 0 then
    logger.warn("invalid market product id:", tostring(product_id))
    return false
  end
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
