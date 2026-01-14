local logger = require("src.util.logger")
local IntentDispatcher = require("src.gameplay.app.intent_dispatcher")
local Choice = require("src.gameplay.app.choice")

local TileService = {}

local function require_service(game, key, name)
  local svc = game and game.services and game.services[key]
  assert(svc, "Missing " .. name)
  return svc
end

local function handle_hospital(game, player)
  local status = require_service(game, "status", "StatusService")
  status.send_to_hospital(game, player)
end

local function handle_mountain(game, player)
  local status = require_service(game, "status", "StatusService")
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

  local market = require_service(game, "market", "MarketService")

  if player.inventory and player.inventory.is_full and player.inventory:is_full() then
    game.store:set({ "turn", "market_prompt" }, { player_id = player.id, tile_id = tile.id })
    return {
      intent = { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 卡槽已满，无法购买" } },
    }
  end

  local spec, market_intent = market.build_choice_spec and market.build_choice_spec(game, player) or nil
  if market_intent then
    game.store:set({ "turn", "market_prompt" }, { player_id = player.id, tile_id = tile.id })
    return { intent = market_intent }
  end
  if not spec then
    game.store:set({ "turn", "market_prompt" }, { player_id = player.id, tile_id = tile.id })
    return nil
  end

  game.store:set({ "turn", "market_prompt" }, { player_id = player.id, tile_id = tile.id })
  return {
    waiting = true,
    reason = "market_choice",
    intent = { kind = "need_choice", choice_spec = spec },
  }
end

function TileService.check_mine(game, player, idx)
  local overlay = require_service(game, "overlay", "OverlayService")
  local position = idx or player.position
  if not overlay.has_mine(game, position) then
    return false, false
  end

  local status = require_service(game, "status", "StatusService")
  if status.has_angel(player) then
    logger.event(player.name .. " 天使保护，地雷无效")
    overlay.clear_mine(game, position)
    return true, false
  end

  overlay.clear_mine(game, position)
  game:set_player_seat(player, nil)
  logger.event(player.name .. " 触发地雷，座驾被摧毁并送医")
  status.send_to_hospital(game, player)
  return true, true
end


function TileService.resolve(game, player, tile, context)
  
  if context and context.encountered_players and not context.pass_players_checked then
    local item = require_service(game, "item", "ItemService")
    local res = item.handle_pass_players(game, player, context.encountered_players, { services = game and game.services })
    if res then
      IntentDispatcher.dispatch_from_result(game, res)
    end
    if res and res.waiting then
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

  TileService.check_mine(game, player)

  return out
end

local function is_cancel(action)
  return not action or action.type == "choice_cancel" or action.option_id == nil
end

function TileService.handle_choice(game, choice, action)
  if not game or not game.store or not choice then
    return nil
  end

  if choice.kind == "rent_card_prompt" then
    local meta = choice.meta or {}
    if meta.player_id and meta.tile_id and meta.kind then
      local decision = (action and action.option_id == "use")
      if is_cancel(action) then
        decision = false
      end
      game.store:set({ "turn", "rent_prompt" }, {
        player_id = meta.player_id,
        tile_id = meta.tile_id,
        kind = meta.kind,
        decision = decision,
      })
    end
    Choice.clear(game)
    return { stay = false }
  end

  if choice.kind == "tax_card_prompt" then
    local meta = choice.meta or {}
    if meta.player_id then
      local decision = (action and action.option_id == "use")
      if is_cancel(action) then
        decision = false
      end
      game.store:set({ "turn", "tax_prompt" }, {
        player_id = meta.player_id,
        decision = decision,
      })
    end
    Choice.clear(game)
    return { stay = false }
  end

  return nil
end

return TileService
