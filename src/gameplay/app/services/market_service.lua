local items_cfg = require("src.config.items")
local logger = require("src.util.logger")
local Choice = require("src.gameplay.app.choice")

local MarketService = {}

local function buyable_with_cash(cfg)
  return cfg.shop_currency == "金币" or cfg.shop_price == 0
end


function MarketService.list_buyable(player)
  local list = {}
  for _, cfg in ipairs(items_cfg) do
    if buyable_with_cash(cfg) then
      table.insert(list, cfg)
    end
  end
  table.sort(list, function(a, b)
    return (a.shop_price or 0) < (b.shop_price or 0)
  end)
  return list
end

local function find_cfg(item_id)
  for _, cfg in ipairs(items_cfg) do
    if cfg.id == item_id then
      return cfg
    end
  end
  return nil
end

function MarketService.build_choice_spec(game, player)
  if not player then
    return nil
  end

  local options_cfg = MarketService.list_buyable(player)
  local options = {}
  local body_lines = {}
  for _, cfg in ipairs(options_cfg) do
    local price = cfg.shop_price or 0
    if player.cash >= price then
      local label = (cfg.name or tostring(cfg.id)) .. " - " .. tostring(price) .. " " .. tostring(cfg.shop_currency or "金币")
      table.insert(body_lines, label)
      table.insert(options, { id = cfg.id, label = label })
    end
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
  if not game or not player or not item_id then
    return false
  end
  local cfg = find_cfg(item_id)
  if not cfg or not buyable_with_cash(cfg) then
    return false
  end

  local item = game and game.services and game.services.item
  if not item or not item.give_item then
    logger.warn("缺少 ItemService，无法在黑市购买")
    return false
  end
  if player.inventory and player.inventory.is_full and player.inventory:is_full() then
    return { ok = false, intent = { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 卡槽已满，无法购买" } } }
  end

  local price = cfg.shop_price or 0
  if player.cash < price then
    return {
      ok = false,
      intent = {
        kind = "push_popup",
        payload = { title = "黑市", body = player.name .. " 金币不足，无法购买 " .. (cfg.name or tostring(cfg.id)) },
      },
    }
  end

  player:deduct_cash(price)
  item.give_item(player, cfg.id)
  logger.event(player.name .. " 在黑市购买 " .. (cfg.name or tostring(cfg.id)) .. " 花费 " .. tostring(price))
  return true
end


function MarketService.auto_buy(game, player)
  local item = game and game.services and game.services.item
  if not item then
    logger.warn("缺少 ItemService，无法在黑市购买")
    return
  end
  if player.inventory:is_full() then
    logger.warn(player.name .. " 卡槽已满，无法在黑市购买")
    return
  end
  local options = MarketService.list_buyable(player)
  for _, cfg in ipairs(options) do
    if player.cash >= (cfg.shop_price or 0) and not player.inventory:is_full() then
      player:deduct_cash(cfg.shop_price or 0)
      item.give_item(player, cfg.id)
    end
  end
end

local function is_cancel(action)
  return not action or action.type == "choice_cancel" or action.option_id == nil
end

local function as_number(v)
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    return tonumber(v)
  end
  return nil
end

function MarketService.handle_choice(game, choice, action)
  if not choice or choice.kind ~= "market_buy" then
    return nil
  end

  if is_cancel(action) then
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
