local chance_cfg = require("src.config.chance_cards")
local random = require("src.util.random")
local StatusService = require("src.gameplay.services.status_service")
local ItemService = require("src.gameplay.services.item_service")
local MovementService = require("src.gameplay.services.movement_service")
local TileService = nil -- 延迟加载以避免循环
local MarketService = nil
local logger = require("src.gameplay.services.logger")
local constants = require("src.config.constants")
local BankruptcyService = require("src.gameplay.services.bankruptcy_service")

local ChanceService = {}

local cfg_by_id = {}
for _, cfg in ipairs(chance_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local function load_services()
  if not TileService then
    TileService = require("src.gameplay.services.tile_service")
  end
  if not MarketService then
    MarketService = require("src.gameplay.services.market_service")
  end
end

function ChanceService.draw_card(rng)
  return random.weighted_choice(chance_cfg, "weight", rng)
end

local function apply_cash_change(player, delta)
  player.cash = player.cash + delta
end

function ChanceService.resolve(game, player, card, context)
  load_services()
  if card.negative and StatusService.has_angel(player) then
    logger.event(player.name .. " 有天使附身，负面机会卡无效")
    return
  end

  local effect = card.effect
  if effect == "add_cash" then
    apply_cash_change(player, card.amount)
    logger.event(player.name .. " 获得 " .. card.amount .. " 金币")
  elseif effect == "pay_cash" then
    apply_cash_change(player, -card.amount)
    logger.event(player.name .. " 支付 " .. card.amount .. " 金币")
    if player.cash < 0 then
      BankruptcyService.eliminate(game, player)
    end
  elseif effect == "percent_pay_cash" then
    local fee = math.floor(player.cash * (card.percent / 100))
    apply_cash_change(player, -fee)
    logger.event(player.name .. " 按比例支付 " .. fee .. " 金币")
    if player.cash < 0 then
      BankruptcyService.eliminate(game, player)
    end
  elseif effect == "pay_others" then
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = card.amount
        if player:has_deity("poor") then
          fee = fee * 2
        end
        if not StatusService.is_in_mountain(game, other) then
          apply_cash_change(player, -fee)
          apply_cash_change(other, fee)
        end
      end
    end
    logger.event(player.name .. " 向每位玩家支付 " .. card.amount)
    if player.cash < 0 then
      BankruptcyService.eliminate(game, player)
    end
  elseif effect == "collect_from_others" then
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = card.amount
        if player:has_deity("rich") then
          fee = fee * 2
        end
        if not StatusService.is_in_mountain(game, player) then
          if other.cash < fee then
            fee = other.cash
          end
          apply_cash_change(other, -fee)
          apply_cash_change(player, fee)
        end
      end
    end
    logger.event(player.name .. " 收取每位玩家 " .. card.amount)
  elseif effect == "set_vehicle" then
    player.seat_id = card.vehicle_id
    logger.event(player.name .. " 获得座驾 " .. tostring(card.vehicle_id))
  elseif effect == "destroy_buildings_on_path" then
    if context and context.visited then
      for _, idx in ipairs(context.visited) do
        local t = game.board:get_tile(idx)
        if t.type == "land" and t.level > 0 then
          t.level = 0
          logger.event("台风摧毁 " .. t.name .. " 上的建筑")
        end
      end
    end
  elseif effect == "reset_tiles_on_path" then
    if context and context.visited then
      for _, idx in ipairs(context.visited) do
        local t = game.board:get_tile(idx)
        if t.type == "land" then
          t:reset()
          logger.event("强制征地重置 " .. t.name)
        end
      end
    end
  elseif effect == "move_backward" then
    local res = MovementService.move(game, player, card.steps)
    local tile = game.board:get_tile(player.position)
    local out = TileService.resolve(game, player, tile, res)
    if out and out.waiting then
      return out
    end
  elseif effect == "move_forward" then
    local res = MovementService.move(game, player, card.steps)
    local tile = game.board:get_tile(player.position)
    local out = TileService.resolve(game, player, tile, res)
    if out and out.waiting then
      return out
    end
  elseif effect == "grant_item" then
    ItemService.give_item(player, card.item_id)
  elseif effect == "discard_items" then
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
  elseif effect == "discard_properties" then
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
  elseif effect == "forced_move" then
    if card.destination == "hospital" then
      StatusService.send_to_hospital(game, player, { skip_fee = true })
    elseif card.destination == "mountain" then
      StatusService.send_to_mountain(game, player)
    elseif card.destination == "tax" then
      local idx = game.board:find_first_by_type("tax")
      if idx then
        game:update_player_position(player, idx)
        local out = TileService.resolve(game, player, game.board:get_tile(idx), context)
        if out and out.waiting then
          return out
        end
      end
    elseif card.destination == "market" then
      local idx = game.board:find_first_by_type("market")
      if idx then
        game:update_player_position(player, idx)
        if MarketService then
          MarketService.auto_buy(game, player)
        end
      end
    end
  end
end

return ChanceService
