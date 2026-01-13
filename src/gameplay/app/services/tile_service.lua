local logger = require("src.util.logger")
local Choice = require("src.gameplay.app.choice")
local Services = require("src.util.services")
local Errors = require("src.util.error_handling")
local UI = require("src.gameplay.ports.ui_port")

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

local function handle_market(game, player, tile)
  if not game or not game.store or not player or not tile then
    return nil
  end

  local prompted = game.store:get({ "turn", "market_prompt" })
  if prompted and prompted.player_id == player.id and prompted.tile_id == tile.id then
    return nil
  end

  local market = Services.market(game)
  if not market then
    logger.warn("缺少 MarketService，无法打开黑市")
    return nil
  end

  if player.inventory and player.inventory.is_full and player.inventory:is_full() then
    UI.push_popup(game, { title = "黑市", body = player.name .. " 卡槽已满，无法购买" })
    game.store:set({ "turn", "market_prompt" }, { player_id = player.id, tile_id = tile.id })
    return nil
  end

  local spec = market.build_choice_spec and market.build_choice_spec(game, player) or nil
  if not spec then
    game.store:set({ "turn", "market_prompt" }, { player_id = player.id, tile_id = tile.id })
    return nil
  end

  Choice.open(game, spec)
  game.store:set({ "turn", "market_prompt" }, { player_id = player.id, tile_id = tile.id })
  return { waiting = true, reason = "market_choice" }
end

local function check_mine(game, player)
  local overlay = Services.overlay(game)
  if overlay and overlay.has_mine(game, player.position) then
    local status = Services.status(game)
    if not status then
      return missing_service("StatusService")
    end
    if status.has_angel(player) then
      logger.event(player.name .. " 天使保护，地雷无效")
      overlay.clear_mine(game, player.position)
      return
    end
    overlay.clear_mine(game, player.position)
    game:set_player_seat(player, nil)
    logger.event(player.name .. " 触发地雷，座驾被摧毁并送医")
    status.send_to_hospital(game, player)
  end
end


function TileService.resolve(game, player, tile, context)
  
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

  local out = nil

  if tile.type == "hospital" then
    handle_hospital(game, player)
  elseif tile.type == "mountain" then
    handle_mountain(game, player)
  elseif tile.type == "market" then
    out = handle_market(game, player, tile)
  end

  check_mine(game, player)

  return out
end

return TileService
