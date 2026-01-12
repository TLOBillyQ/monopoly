local chance_cfg = require("src.config.chance_cards")
local random = require("src.util.random")
local LandResolver = require("src.gameplay.land_resolver")
local logger = require("src.util.logger")
local constants = require("src.config.constants")

local ChanceService = {}

local cfg_by_id = {}
for _, cfg in ipairs(chance_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local function get_service(game, key)
  if game and game.services then
    return game.services[key]
  end
end

local function missing_service(name)
  logger.warn("缺少 " .. name .. "，跳过处理")
end

function ChanceService.draw_card(rng)
  return random.weighted_choice(chance_cfg, "weight", rng)
end

local function apply_cash_change(player, delta)
  player.cash = player.cash + delta
end

local effect_handlers = {}

effect_handlers.add_cash = function(_, player, card)
  apply_cash_change(player, card.amount)
  logger.event(player.name .. " 获得 " .. card.amount .. " 金币")
end

effect_handlers.pay_cash = function(game, player, card)
  apply_cash_change(player, -card.amount)
  logger.event(player.name .. " 支付 " .. card.amount .. " 金币")
  if player.cash < 0 then
    local bankruptcy = get_service(game, "bankruptcy")
    if not bankruptcy then
      return missing_service("BankruptcyService")
    end
    bankruptcy.eliminate(game, player)
  end
end

effect_handlers.percent_pay_cash = function(game, player, card)
  local fee = math.floor(player.cash * (card.percent / 100))
  apply_cash_change(player, -fee)
  logger.event(player.name .. " 按比例支付 " .. fee .. " 金币")
  if player.cash < 0 then
    local bankruptcy = get_service(game, "bankruptcy")
    if not bankruptcy then
      return missing_service("BankruptcyService")
    end
    bankruptcy.eliminate(game, player)
  end
end

effect_handlers.pay_others = function(game, player, card)
  local status = get_service(game, "status")
  if not status then
    return missing_service("StatusService")
  end
  for _, other in ipairs(game.players) do
    if other.id ~= player.id and not other.eliminated then
      local fee = card.amount
      if player:has_deity("poor") then
        fee = fee * 2
      end
      if not status.is_in_mountain(game, other) then
        apply_cash_change(player, -fee)
        apply_cash_change(other, fee)
      end
    end
  end
  logger.event(player.name .. " 向每位玩家支付 " .. card.amount)
  if player.cash < 0 then
    local bankruptcy = get_service(game, "bankruptcy")
    if not bankruptcy then
      return missing_service("BankruptcyService")
    end
    bankruptcy.eliminate(game, player)
  end
end

effect_handlers.collect_from_others = function(game, player, card)
  local status = get_service(game, "status")
  if not status then
    return missing_service("StatusService")
  end
  for _, other in ipairs(game.players) do
    if other.id ~= player.id and not other.eliminated then
      local fee = card.amount
      if player:has_deity("rich") then
        fee = fee * 2
      end
      if not status.is_in_mountain(game, player) then
        if other.cash < fee then
          fee = other.cash
        end
        apply_cash_change(other, -fee)
        apply_cash_change(player, fee)
      end
    end
  end
  logger.event(player.name .. " 收取每位玩家 " .. card.amount)
end

effect_handlers.set_vehicle = function(_, player, card)
  player.seat_id = card.vehicle_id
  logger.event(player.name .. " 获得座驾 " .. tostring(card.vehicle_id))
end

effect_handlers.destroy_buildings_on_path = function(game, _, _, context)
  if context and context.visited then
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      if t.type == "land" and t.level > 0 then
        t.level = 0
        logger.event("台风摧毁 " .. t.name .. " 上的建筑")
      end
    end
  end
end

effect_handlers.reset_tiles_on_path = function(game, _, _, context)
  if context and context.visited then
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      if t.type == "land" then
        t:reset()
        logger.event("强制征地重置 " .. t.name)
      end
    end
  end
end

effect_handlers.move_backward = function(game, player, card)
  local movement = get_service(game, "movement")
  if not movement then
    return missing_service("MovementService")
  end
  local res = movement.move(game, player, card.steps)
  local tile = game.board:get_tile(player.position)
  local tile_service = get_service(game, "tile")
  if not tile_service then
    logger.warn("缺少 TileService，无法结算机会卡移动")
    return
  end
  local out = tile_service.resolve(game, player, tile, res)
  if out and out.waiting then
    return out
  end
  local land_out = LandResolver.resolve(game, player, tile, res)
  if land_out and land_out.waiting then
    return land_out
  end
end

effect_handlers.move_forward = function(game, player, card)
  local movement = get_service(game, "movement")
  if not movement then
    return missing_service("MovementService")
  end
  local res = movement.move(game, player, card.steps)
  local tile = game.board:get_tile(player.position)
  local tile_service = get_service(game, "tile")
  if not tile_service then
    logger.warn("缺少 TileService，无法结算机会卡移动")
    return
  end
  local out = tile_service.resolve(game, player, tile, res)
  if out and out.waiting then
    return out
  end
  local land_out = LandResolver.resolve(game, player, tile, res)
  if land_out and land_out.waiting then
    return land_out
  end
end

effect_handlers.grant_item = function(game, player, card)
  local item = get_service(game, "item")
  if not item then
    return missing_service("ItemService")
  end
  item.give_item(player, card.item_id)
end

effect_handlers.discard_items = function(_, player, card)
  local to_drop = card.count
  if to_drop == 0 then
    to_drop = player.inventory:count()
  end
  for i = 1, to_drop do
    if player.inventory:count() == 0 then
      break
    end
    player.inventory:remove_by_index(1)
  end
  logger.event(player.name .. " 丢弃道具 " .. to_drop .. " 张")
end

effect_handlers.discard_properties = function(game, player, card)
  local to_drop = card.count
  for tile_id in pairs(player.properties) do
    local tile = game.board:get_tile_by_id(tile_id)
    if tile then
      tile:reset()
    end
    player.properties[tile_id] = nil
    to_drop = to_drop - 1
    if to_drop == 0 then
      break
    end
  end
  logger.event(player.name .. " 丢失地块 " .. card.count .. " 块")
end

effect_handlers.forced_move = function(game, player, card, context)
  local status = get_service(game, "status")
  if not status then
    return missing_service("StatusService")
  end
  if card.destination == "hospital" then
    status.send_to_hospital(game, player, { skip_fee = true })
  elseif card.destination == "mountain" then
    status.send_to_mountain(game, player)
  elseif card.destination == "tax" then
    local idx = game.board:find_first_by_type("tax")
    if idx then
      game:update_player_position(player, idx)
      local tile_service = get_service(game, "tile")
      if tile_service then
        local out = tile_service.resolve(game, player, game.board:get_tile(idx), context)
        if out and out.waiting then
          return out
        end
        local land_out = LandResolver.resolve(game, player, game.board:get_tile(idx), context)
        if land_out and land_out.waiting then
          return land_out
        end
      else
        logger.warn("缺少 TileService，无法结算税务格子")
      end
    end
  elseif card.destination == "market" then
    local idx = game.board:find_first_by_type("market")
    if idx then
      game:update_player_position(player, idx)
      local market_service = get_service(game, "market")
      if market_service then
        market_service.auto_buy(game, player)
      else
        logger.warn("缺少 MarketService，无法自动购买")
      end
    end
  end
end

function ChanceService.resolve(game, player, card, context)
  local status = get_service(game, "status")
  if not status then
    return missing_service("StatusService")
  end
  if card.negative and status.has_angel(player) then
    logger.event(player.name .. " 有天使附身，负面机会卡无效")
    return
  end

  local effect = card.effect
  local handler = effect_handlers[effect]
  if not handler then
    logger.warn("未知机会卡效果:" .. tostring(effect))
    return
  end
  return handler(game, player, card, context)
end

return ChanceService
