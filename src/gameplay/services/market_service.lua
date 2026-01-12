local items_cfg = require("src.config.items")
local logger = require("src.gameplay.services.logger")

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

return MarketService
