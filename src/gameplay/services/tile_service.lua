local logger = require("src.gameplay.services.logger")

local TileService = {}

local function get_service(game, key)
  if game and game.services then
    return game.services[key]
  end
end

local function missing_service(name)
  logger.warn("缺少 " .. name .. "，跳过处理")
end

local function handle_hospital(game, player)
  local status = get_service(game, "status")
  if not status then
    return missing_service("StatusService")
  end
  status.send_to_hospital(game, player)
end

local function handle_mountain(game, player)
  local status = get_service(game, "status")
  if not status then
    return missing_service("StatusService")
  end
  status.send_to_mountain(game, player)
end

local function handle_market(game, player)
  local market = get_service(game, "market")
  if market and market.auto_buy then
    market.auto_buy(game, player)
  else
    logger.warn("缺少 MarketService，跳过黑市自动购买")
  end
end

local function handle_chance(game, player, context)
  local chance = get_service(game, "chance")
  if not chance then
    return missing_service("ChanceService")
  end
  local card = chance.draw_card(game and game.rng)
  logger.event(player.name .. " 抽到机会卡 " .. card.description)
  chance.resolve(game, player, card, context)
end

local function handle_item_tile(game, player)
  local item = get_service(game, "item")
  if not item then
    return missing_service("ItemService")
  end
  item.draw_and_give(player, game.rng)
end

local function check_mine(game, player)
  if game.overlays.mines[player.position] then
    local status = get_service(game, "status")
    if not status then
      return missing_service("StatusService")
    end
    if status.has_angel(player) then
      logger.event(player.name .. " 天使保护，地雷无效")
      game.overlays.mines[player.position] = nil
      return
    end
    game.overlays.mines[player.position] = nil
    player.seat_id = nil
    logger.event(player.name .. " 触发地雷，座驾被摧毁并送医")
    status.send_to_hospital(game, player)
  end
end

function TileService.resolve(game, player, tile, context)
  -- 路过玩家触发偷窃
  if context and context.encountered_players and not context.pass_players_checked then
    local item = get_service(game, "item")
    if not item then
      missing_service("ItemService")
      context.pass_players_checked = true
      return nil
    end
    local res = item.handle_pass_players(game, player, context.encountered_players)
    if res and res.waiting then
      context.pass_players_checked = true
      return res
    end
    context.pass_players_checked = true
  end

  if tile.type == "hospital" then
    handle_hospital(game, player)
  elseif tile.type == "mountain" then
    handle_mountain(game, player)
  elseif tile.type == "market" then
    handle_market(game, player)
  elseif tile.type == "chance" then
    handle_chance(game, player, context)
  elseif tile.type == "item" then
    handle_item_tile(game, player)
  end

  check_mine(game, player)
  return nil
end

return TileService
