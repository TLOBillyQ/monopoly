local items_cfg = require("src.config.items")
local logger = require("src.util.logger")
local Choice = require("src.gameplay.app.choice")
local Inventory = require("src.gameplay.domain.item_inventory")

local MarketService = {}

local function buyable_with_cash(cfg)
  return cfg.shop_currency == "金币" or cfg.shop_price == 0
end

local function find_cfg(item_id)
  for _, cfg in ipairs(items_cfg) do
    if cfg.id == item_id then
      return cfg
    end
  end
  return nil
end

function MarketService.list_buyable(player)
  local list = {}
  for _, cfg in ipairs(items_cfg) do
    if buyable_with_cash(cfg) and player.cash >= (cfg.shop_price or 0) then
      table.insert(list, cfg)
    end
  end
  table.sort(list, function(a, b)
    return (a.shop_price or 0) < (b.shop_price or 0)
  end)
  return list
end

function MarketService.build_choice_spec(game, player)
  if not player then return nil end

  if player.inventory:is_full() then
    return nil, { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 卡槽已满，无法购买" } }
  end

  local options = {}
  local body_lines = {}
  for _, cfg in ipairs(MarketService.list_buyable(player)) do
    local label = cfg.name .. " - " .. (cfg.shop_price or 0) .. " 金币"
    table.insert(body_lines, label)
    table.insert(options, { id = cfg.id, label = label })
  end

  if #options == 0 then
    return nil, { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 金币不足，暂无可购买道具" } }
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

function MarketService.buy(game, player, item_id)
  if not player or not item_id then return false end
  local cfg = find_cfg(item_id)
  if not cfg or not buyable_with_cash(cfg) then return false end

  if player.inventory:is_full() then
    return { ok = false, intent = { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 卡槽已满" } } }
  end

  local price = cfg.shop_price or 0
  if player.cash < price then
    return { ok = false, intent = { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 金币不足" } } }
  end

  player:deduct_cash(price)
  Inventory.give(player, cfg.id)
  logger.event(player.name .. " 在黑市购买 " .. cfg.name .. " 花费 " .. price)
  return true
end

-- 机会卡传送到黑市时使用：AI自动购买最便宜的一个
function MarketService.auto_buy(game, player)
  -- AI玩家不主动购买，避免破产
  if player.is_ai or player.auto then
    logger.event(player.name .. " (AI) 到达黑市，选择不购买")
    return
  end
  if player.inventory:is_full() then
    logger.warn(player.name .. " 卡槽已满，无法在黑市购买")
    return
  end
  local list = MarketService.list_buyable(player)
  if #list > 0 then
    MarketService.buy(game, player, list[1].id)
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

  local item_id = as_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  if player and item_id then
    MarketService.buy(game, player, item_id)
  end
  Choice.clear(game)
  return { stay = false }
end

return MarketService
