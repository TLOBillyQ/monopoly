local logger = require("src.util.logger")
local Choice = require("src.gameplay.app.choice")
local Services = require("src.util.services")
local Errors = require("src.util.error_handling")

local TileService = {}

local function missing_service(name)
  Errors.missing_service(name)
end

local function handle_hospital(game, player)
  local status = Services.status(game)
  if not status then
    return missing_service("StatusService")
  end
  status.send_to_hospital(game, player)
end

local function handle_mountain(game, player)
  local status = Services.status(game)
  if not status then
    return missing_service("StatusService")
  end
  status.send_to_mountain(game, player)
end

local function handle_market(game, player)
  local market = Services.market(game)
  if market and market.auto_buy then
    market.auto_buy(game, player)
  else
    logger.warn("缺少 MarketService，跳过黑市自动购买")
  end
end

local function check_mine(game, player)
  if game.overlays.mines[player.position] then
    local status = Services.status(game)
    if not status then
      return missing_service("StatusService")
    end
    if status.has_angel(player) then
      logger.event(player.name .. " 天使保护，地雷无效")
      game.overlays.mines[player.position] = nil
      return
    end
    game.overlays.mines[player.position] = nil
    game:set_player_seat(player, nil)
    logger.event(player.name .. " 触发地雷，座驾被摧毁并送医")
    status.send_to_hospital(game, player)
  end
end

function TileService.resolve(game, player, tile, context)
  -- 路过玩家触发偷窃
  if context and context.encountered_players and not context.pass_players_checked then
    local item = Services.item(game)
    if not item then
      missing_service("ItemService")
      context.pass_players_checked = true
      return nil
    end
    local res = item.handle_pass_players(game, player, context.encountered_players)
    if res and res.waiting then
      if res.intent and res.intent.kind == "need_choice" and res.intent.choice_spec then
        Choice.open(game, res.intent.choice_spec)
      end
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
  end

  check_mine(game, player)
  return nil
end

return TileService
