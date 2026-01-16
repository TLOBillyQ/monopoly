local logger = require("src.util.logger")
local Inventory = require("src.gameplay.item_inventory")

local ChanceEffects = {}

local function apply_cash_change(player, delta)
  player:add_cash(delta)
end

local function require_service(service, name)
  assert(service, "Missing " .. name)
  return service
end

local function get_service(game, context, key)
  if context and context.services and context.services[key] then
    return context.services[key]
  end
  return game and game.services and game.services[key]
end

local function handle_bankruptcy_if_negative(game, player)
  if player.cash >= 0 then
    return
  end
  local bankruptcy = require_service(get_service(game, nil, "bankruptcy"), "BankruptcyService")
  bankruptcy.eliminate(game, player)
end

local function apply_cash_and_maybe_bankrupt(game, player, delta)
  apply_cash_change(player, delta)
  handle_bankruptcy_if_negative(game, player)
end

local function move_steps(game, player, steps)
  local movement = require_service(get_service(game, nil, "movement"), "MovementService")
  local res = movement.move(game, player, steps)
  return {
    kind = "need_landing",
    player_id = player.id,
    board_index = player.position,
    move_result = res,
  }
end

local handlers = {}

handlers.add_cash = function(game, player, card)
  if card.target == "all" then
    for _, p in ipairs(game.players) do
      if not p.eliminated then
        apply_cash_change(p, card.amount)
      end
    end
    logger.event("每人获得 " .. card.amount .. " 金币")
  else
    apply_cash_change(player, card.amount)
    logger.event(player.name .. " 获得 " .. card.amount .. " 金币")
  end
end

handlers.pay_cash = function(game, player, card)
  if card.target == "all" then
    for _, p in ipairs(game.players) do
      if not p.eliminated then
        apply_cash_and_maybe_bankrupt(game, p, -card.amount)
      end
    end
    logger.event("每人支付 " .. card.amount .. " 金币")
  else
    apply_cash_and_maybe_bankrupt(game, player, -card.amount)
    logger.event(player.name .. " 支付 " .. card.amount .. " 金币")
  end
end

handlers.percent_pay_cash = function(game, player, card)
  if card.target == "all" then
    for _, p in ipairs(game.players) do
      if not p.eliminated then
        local fee = math.floor(p.cash * (card.percent / 100))
        apply_cash_and_maybe_bankrupt(game, p, -fee)
      end
    end
    logger.event("每人按比例支付 " .. card.percent .. "% 金币")
  else
    local fee = math.floor(player.cash * (card.percent / 100))
    apply_cash_and_maybe_bankrupt(game, player, -fee)
    logger.event(player.name .. " 按比例支付 " .. fee .. " 金币")
  end
end

handlers.pay_others = function(game, player, card)
  for _, other in ipairs(game.players) do
    if other.id ~= player.id and not other.eliminated then
      local fee = card.amount
      if player:has_deity("poor") then
        fee = fee * 2
      end
      if not other:is_in_mountain(game) then
        apply_cash_and_maybe_bankrupt(game, player, -fee)
        apply_cash_change(other, fee)
      end
    end
  end
  logger.event(player.name .. " 向每位玩家支付 " .. card.amount)
end

handlers.collect_from_others = function(game, player, card)
  for _, other in ipairs(game.players) do
    if other.id ~= player.id and not other.eliminated then
      local fee = card.amount
      if player:has_deity("rich") then
        fee = fee * 2
      end
      if not player:is_in_mountain(game) then
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

handlers.set_vehicle = function(game, player, card)
  game:set_player_seat(player, card.vehicle_id)
  logger.event(player.name .. " 获得座驾 " .. tostring(card.vehicle_id))
end

handlers.destroy_buildings_on_path = function(game, _, _, context)
  if context and context.visited then
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      local snap = (game.store and game.store:get({ "board", "tiles", t.id })) or nil
      local lvl = (type(snap) == "table" and snap.level) or 0
      if t.type == "land" and lvl > 0 then
        if game and game.set_tile_level then
          game:set_tile_level(t, 0)
        elseif game and game.store and t and t.id then
          game.store:set({ "board", "tiles", t.id, "level" }, 0)
        end
        logger.event("台风摧毁 " .. t.name .. " 上的建筑")
      end
    end
  end
end

handlers.reset_tiles_on_path = function(game, _, _, context)
  if context and context.visited then
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      if t.type == "land" then
        game:reset_tile(t)
        logger.event("强制征地重置 " .. t.name)
      end
    end
  end
end

handlers.move_backward = function(game, player, card)
  return move_steps(game, player, -(card.steps or 0))
end

handlers.move_forward = function(game, player, card)
  return move_steps(game, player, card.steps or 0)
end

handlers.grant_item = function(game, player, card)
  local ok = Inventory.give(player, card.item_id)
  if ok == false then
    return { intent = { kind = "push_popup", payload = { title = "道具卡已满", body = "道具卡已满，无法获得。" } } }
  end
end

handlers.discard_items = function(_, player, card)
  local to_drop = card.count
  if to_drop == 0 then
    to_drop = player.inventory:count()
  end
  local dropped_names = {}
  for _ = 1, to_drop do
    if player.inventory:count() == 0 then
      break
    end
    local item = player.inventory:remove_by_index(1)
    table.insert(dropped_names, Inventory.item_name(item.id))
  end
  if #dropped_names > 0 then
    logger.event(player.name .. " 丢弃道具 " .. #dropped_names .. " 张: " .. table.concat(dropped_names, "、"))
  else
    logger.event(player.name .. " 丢弃道具 0 张")
  end
end

handlers.discard_properties = function(game, player, card)
  local to_drop = card.count
  for tile_id in pairs(player.properties) do
    local tile = game.board:get_tile_by_id(tile_id)
    if tile then
      game:reset_tile(tile)
      logger.event(player.name .. " 丢失地块 " .. tile.name)
    end
    game:set_player_property(player, tile_id, false)
    to_drop = to_drop - 1
    if to_drop == 0 then
      break
    end
  end
end

handlers.forced_move = function(game, player, card, context)
  if card.destination_tile_id then
    local idx = game.board:index_of_tile_id(card.destination_tile_id)
    if idx then
      game:update_player_position(player, idx)
      if game.set_player_status then
        game:set_player_status(player, "move_dir", nil)
      end
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
  end
  if card.destination == "hospital" then
    player:send_to_hospital(game)
  elseif card.destination == "mountain" then
    player:send_to_mountain(game)
  elseif card.destination == "tax" then
    local idx = game.board:find_first_by_type("tax")
    if idx then
      game:update_player_position(player, idx)
      if game.set_player_status then
        game:set_player_status(player, "move_dir", nil)
      end
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
  elseif card.destination == "market" then
    local idx = game.board:find_first_by_type("market")
    if idx then
      game:update_player_position(player, idx)
      if game.set_player_status then
        game:set_player_status(player, "move_dir", nil)
      end
      local market_service = require_service(get_service(game, context, "market"), "MarketService")
      market_service.auto_buy(game, player)
    end
  end
end

function ChanceEffects.resolve(game, player, card, context)

  if card.negative and player:has_angel() then
    logger.event(player.name .. " 有天使附身，负面机会卡无效")
    return nil
  end

  local handler = handlers[card.effect]
  if not handler then
    logger.warn("未知机会卡效果:" .. tostring(card.effect))
    return nil
  end

  return handler(game, player, card, context)
end

return ChanceEffects
