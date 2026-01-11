local constants = require("src.config.constants")
local ItemService = require("src.gameplay.services.item_service")
local ChanceService = require("src.gameplay.services.chance_service")
local MarketService = require("src.gameplay.services.market_service")
local StatusService = require("src.gameplay.services.status_service")
local BankruptcyService = require("src.gameplay.services.bankruptcy_service")
local logger = require("src.gameplay.services.logger")

local TileService = {}

local function contiguous_rent(board, index, owner_id)
  local length = board:length()
  local rent_sum = 0
  -- 扫描左侧连续同主
  local i = index
  while i >= 1 do
    local tile = board:get_tile(i)
    if tile.type == "land" and tile.owner_id == owner_id then
      rent_sum = rent_sum + tile:current_rent()
      i = i - 1
    else
      break
    end
  end
  -- 扫描右侧连续同主（避免重复当前格，先前 i 已经停在非同主）
  i = index + 1
  while i <= length do
    local tile = board:get_tile(i)
    if tile.type == "land" and tile.owner_id == owner_id then
      rent_sum = rent_sum + tile:current_rent()
      i = i + 1
    else
      break
    end
  end
  return rent_sum
end

local function try_pay_rent(game, player, owner, rent)
  if StatusService.is_in_mountain(game, owner) then
    logger.event(owner.name .. " 在深山，租金不收取")
    return
  end
  if player:has_deity("poor") then
    rent = rent * 2
  end
  if owner:has_deity("rich") then
    rent = rent * 2
  end

  if player.cash >= rent then
    player:deduct_cash(rent)
    owner:add_cash(rent)
    logger.event(player.name .. " 向 " .. owner.name .. " 支付租金 " .. rent)
  else
    local paid = player.cash
    owner:add_cash(paid)
    player.cash = 0
    logger.event(player.name .. " 资金不足，支付剩余 " .. paid .. " 后破产")
    BankruptcyService.eliminate(game, player)
  end
end

local function buy_land(player, tile)
  tile.owner_id = player.id
  player.properties[tile.id] = true
end

local function upgrade_land(player, tile)
  tile.level = tile.level + 1
end

local function handle_land(game, player, tile, context)
  if tile.owner_id == nil then
    if player.cash >= tile.price then
      player:deduct_cash(tile.price)
      buy_land(player, tile)
      logger.event(player.name .. " 购买 " .. tile.name .. " 花费 " .. tile.price)
    else
      logger.event(player.name .. " 无法购买 " .. tile.name .. "，金币不足")
    end
    return
  end

  if tile.owner_id == player.id then
    if tile:can_upgrade() then
      local cost = tile:next_upgrade_cost()
      if cost and player.cash >= cost then
        player:deduct_cash(cost)
        upgrade_land(player, tile)
        logger.event(player.name .. " 为 " .. tile.name .. " 加盖，花费 " .. cost)
      else
        logger.event(player.name .. " 金币不足，无法加盖 " .. tile.name)
      end
    else
      logger.event(player.name .. " 已是最高级建筑，无事发生")
    end
    return
  end

  -- 他人地块
  local owner = game.players[tile.owner_id]
  if not owner or owner.eliminated then
    tile.owner_id = nil
    return handle_land(game, player, tile, context)
  end

  -- 强征卡
  local total_value = tile:total_invested()
  local strong_idx = nil
  if player.inventory then
    strong_idx = player.inventory:find_index(function(it)
      return it.id == 2009
    end)
  end
  if strong_idx and player.cash >= total_value then
    player.inventory:remove_by_index(strong_idx)
    player:deduct_cash(total_value)
    owner:add_cash(total_value)
    tile.owner_id = player.id
    owner.properties[tile.id] = nil
    player.properties[tile.id] = true
    logger.event(player.name .. " 使用强征卡，支付 " .. total_value .. " 强制购入 " .. tile.name)
    return
  end

  -- 免费卡
  if player.status.pending_free_rent then
    player.status.pending_free_rent = false
    logger.event(player.name .. " 使用免费卡，免租 " .. tile.name)
    return
  end
  local free_idx = player.inventory and player.inventory:find_index(function(it)
    return it.id == 2001
  end)
  if free_idx then
    player.inventory:remove_by_index(free_idx)
    logger.event(player.name .. " 出示免费卡，免租 " .. tile.name)
    return
  end

  local idx = game.board:index_of_tile_id(tile.id) or 1
  local rent = contiguous_rent(game.board, idx, owner.id)
  try_pay_rent(game, player, owner, rent)
end

local function handle_tax(game, player)
  if player.status.pending_tax_free then
    logger.event(player.name .. " 使用免税卡，本次免税")
    player.status.pending_tax_free = false
    return
  end
  local tax_idx = player.inventory and player.inventory:find_index(function(it)
    return it.id == 2010
  end)
  if tax_idx then
    player.inventory:remove_by_index(tax_idx)
    logger.event(player.name .. " 出示免税卡，本次免税")
    return
  end
  local fee = math.floor(player.cash * constants.tax_rate)
  if player.cash < fee then
    fee = player.cash
  end
  player:deduct_cash(fee)
  logger.event(player.name .. " 在税务局支付税金 " .. fee)
  if player.cash <= 0 then
    BankruptcyService.eliminate(game, player)
  end
end

local function handle_hospital(game, player)
  StatusService.send_to_hospital(game, player)
end

local function handle_mountain(game, player)
  StatusService.send_to_mountain(game, player)
end

local function handle_market(game, player)
  MarketService.auto_buy(game, player)
end

local function handle_chance(game, player, context)
  local card = ChanceService.draw_card(game and game.rng)
  logger.event(player.name .. " 抽到机会卡 " .. card.description)
  ChanceService.resolve(game, player, card, context)
end

local function handle_item_tile(game, player)
  ItemService.draw_and_give(player, game.rng)
end

local function check_mine(game, player)
  if game.overlays.mines[player.position] then
    if StatusService.has_angel(player) then
      logger.event(player.name .. " 天使保护，地雷无效")
      game.overlays.mines[player.position] = nil
      return
    end
    game.overlays.mines[player.position] = nil
    player.seat_id = nil
    logger.event(player.name .. " 触发地雷，座驾被摧毁并送医")
    StatusService.send_to_hospital(game, player)
  end
end

function TileService.resolve(game, player, tile, context)
  -- 路过玩家触发偷窃
  if context and context.encountered_players and not context.pass_players_checked then
    local res = ItemService.handle_pass_players(game, player, context.encountered_players)
    if res and res.waiting then
      context.pass_players_checked = true
      return res
    end
    context.pass_players_checked = true
  end

  if tile.type == "land" then
    -- 已在 effects/land.lua 处理租金/购买/升级
  elseif tile.type == "hospital" then
    handle_hospital(game, player)
  elseif tile.type == "mountain" then
    handle_mountain(game, player)
  elseif tile.type == "tax" then
    -- 已在 effects/land.lua 处理税务
  elseif tile.type == "market" then
    handle_market(game, player)
  elseif tile.type == "chance" then
    handle_chance(game, player, context)
  elseif tile.type == "item" then
    handle_item_tile(game, player)
  elseif tile.type == "start" then
    -- start 奖励在 MovementService/land effect 中处理
  end

  check_mine(game, player)
  return nil
end

return TileService
