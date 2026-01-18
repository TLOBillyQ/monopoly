local LandActions = {}
local logger = require("src.util.logger")
local constants = require("src.config.constants")
local Tile = require("src.core.tile")
local BoardUtils = require("src.gameplay.item_board_utils")
local Pricing = require("src.gameplay.land_pricing")

local tile_state = Tile.get_state

function LandActions.safe_tile_state(game, tile)
  local ok, st = pcall(tile_state, game, tile)
  if not ok or type(st) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = st.owner_id, level = st.level or 0 }
end

function LandActions.resolve_rent_owner(game, tile, state_fn)
  local st = state_fn and state_fn(game, tile) or LandActions.safe_tile_state(game, tile)
  local owner = st.owner_id and game.players[st.owner_id] or nil
  if not owner or owner.eliminated then
    game:set_tile_owner(tile, nil)
    return nil, st
  end

  if owner:is_in_mountain(game) then
    logger.event(owner.name .. " 在深山，租金不收取")
    return nil, st
  end

  return owner, st
end

-- 计算连续地块租金（图邻接）
local function contiguous_rent(game, board, index, owner_id)
  local map = board and board.map
  local neighbors = map and map.neighbors
  if not neighbors then
    local length = board:length()
    local rent_sum = 0
    local i = index
    while i >= 1 do
      local t = board:get_tile(i)
      if t.type == "land" then
        local st2 = LandActions.safe_tile_state(game, t)
        if st2.owner_id == owner_id then
          rent_sum = rent_sum + Pricing.rent_for_level(t, st2.level or 0)
          i = i - 1
        else
          break
        end
      else
        break
      end
    end
    i = index + 1
    while i <= length do
      local t = board:get_tile(i)
      if t.type == "land" then
        local st2 = LandActions.safe_tile_state(game, t)
        if st2.owner_id == owner_id then
          rent_sum = rent_sum + Pricing.rent_for_level(t, st2.level or 0)
          i = i + 1
        else
          break
        end
      else
        break
      end
    end
    return rent_sum
  end

  local start_tile = board:get_tile(index)
  if not start_tile or start_tile.type ~= "land" then
    return 0
  end
  local start_state = LandActions.safe_tile_state(game, start_tile)
  if start_state.owner_id ~= owner_id then
    return 0
  end

  local rent_sum = 0
  local visited = {}
  local queue = { start_tile.id }
  visited[start_tile.id] = true

  while #queue > 0 do
    local tile_id = table.remove(queue, 1)
    local tile = board:get_tile_by_id(tile_id)
    if tile and tile.type == "land" then
      local st2 = LandActions.safe_tile_state(game, tile)
      if st2.owner_id == owner_id then
        rent_sum = rent_sum + Pricing.rent_for_level(tile, st2.level or 0)
        local neigh = neighbors[tile_id] or {}
        for _, next_id in pairs(neigh) do
          if not visited[next_id] then
            visited[next_id] = true
            table.insert(queue, next_id)
          end
        end
      end
    end
  end

  return rent_sum
end

-- 执行强征卡效果（由 choice_service 调用）
function LandActions.execute_strong_card(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  if not player or not tile then return false end

  local st = LandActions.safe_tile_state(game, tile)
  local owner = st.owner_id and game.players[st.owner_id] or nil
  if not owner then return false end

  local total_value = BoardUtils.total_invested(tile, st.level)
  local strong_idx = player.inventory and player.inventory:find_index(function(it) return it.id == 2009 end)

  if not strong_idx or player.cash < total_value then return false end

  player.inventory:remove_by_index(strong_idx)
  player:deduct_cash(total_value)
  owner:add_cash(total_value)
  game:set_tile_owner(tile, player.id)
  game:set_player_property(owner, tile.id, false)
  game:set_player_property(player, tile.id, true)
  logger.event(player.name .. " 使用强征卡，支付 " .. total_value .. " 强制购入 " .. tile.name)
  return true
end

-- 执行免费卡（免租）效果（由 choice_service 调用）
function LandActions.execute_free_card(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  if not player or not tile then return false end

  local free_idx = player.inventory and player.inventory:find_index(function(it) return it.id == 2001 end)
  if not free_idx then return false end

  player.inventory:remove_by_index(free_idx)
  logger.event(player.name .. " 出示免费卡，免租 " .. tile.name)
  return true
end

-- 执行租金支付（由 choice_service 调用，当用户跳过所有卡牌选项后）
function LandActions.execute_pay_rent(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  if not player or not tile then return false end

  local owner, st = LandActions.resolve_rent_owner(game, tile)
  if not owner then
    return true
  end

  local board = game.board
  local idx = board:index_of_tile_id(tile.id) or 1
  local rent = contiguous_rent(game, board, idx, owner.id)

  if player:has_deity("poor") then rent = rent * 2 end
  if owner:has_deity("rich") then rent = rent * 2 end

  if player.cash >= rent then
    player:deduct_cash(rent)
    owner:add_cash(rent)
    logger.event(player.name .. " 向 " .. owner.name .. " 支付租金 " .. rent)
    if player.cash <= 0 then
      local bankruptcy = game and game.get_service and game:get_service("bankruptcy")
      if bankruptcy and bankruptcy.eliminate then
        bankruptcy.eliminate(game, player)
      end
    end
  else
    local paid = player.cash
    owner:add_cash(paid)
    player:set_cash(0)
    logger.event(player.name .. " 资金不足，支付剩余 " .. paid .. " 后破产")
    local bankruptcy = game and game.get_service and game:get_service("bankruptcy")
    if bankruptcy and bankruptcy.eliminate then
      bankruptcy.eliminate(game, player)
    end
  end
  return true
end

-- 执行免税卡效果（由 choice_service 调用）
function LandActions.execute_tax_free_card(game, player_id)
  local player = game.players[player_id]
  if not player then return false end

  local tax_idx = player.inventory and player.inventory:find_index(function(it) return it.id == 2010 end)
  if not tax_idx then return false end

  player.inventory:remove_by_index(tax_idx)
  logger.event(player.name .. " 出示免税卡，本次免税")
  return true
end

-- 执行税金支付（由 choice_service 调用，当用户跳过免税卡后）
function LandActions.execute_pay_tax(game, player_id)
  local player = game.players[player_id]
  if not player then return false end

  local fee = math.floor(player.cash * constants.tax_rate)
  if player.cash < fee then fee = player.cash end

  player:deduct_cash(fee)
  logger.event(player.name .. " 在税务局支付税金 " .. fee)

  if player.cash <= 0 then
    local bankruptcy = game and game.get_service and game:get_service("bankruptcy")
    if bankruptcy and bankruptcy.eliminate then
      bankruptcy.eliminate(game, player)
    end
  end
  return true
end

return LandActions
