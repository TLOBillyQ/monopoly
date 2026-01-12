local Effect = {}
local logger = require("src.util.logger")
local constants = require("src.config.constants")
local BankruptcyService = require("src.gameplay.services.bankruptcy_service")
local StatusService = require("src.gameplay.services.status_service")

-- Optional: buy land if unowned and player has cash
local function can_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  return tile.type == "land" and tile.owner_id == nil and player.cash >= tile.price
end

local function apply_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  player:deduct_cash(tile.price)
  tile.owner_id = player.id
  player.properties[tile.id] = true
  logger.event(player.name .. " 购买 " .. tile.name .. " 花费 " .. tile.price)
end

-- Optional: upgrade own land if possible and affordable
local function can_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  if tile.type ~= "land" or tile.owner_id ~= player.id or not tile:can_upgrade() then
    return false
  end
  local cost = tile:next_upgrade_cost()
  return cost and player.cash >= cost
end

local function apply_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  local cost = tile:next_upgrade_cost()
  player:deduct_cash(cost)
  tile.level = tile.level + 1
  logger.event(player.name .. " 为 " .. tile.name .. " 加盖，花费 " .. cost)
end

-- Mandatory: start tile reward on landing
local function can_start_reward(ctx)
  return ctx.tile.type == "start" and ctx.on_landing
end

local function apply_start_reward(ctx)
  local player = ctx.player
  player:add_cash(constants.pass_start_bonus)
  logger.event(player.name .. " 停在起点，获得 " .. constants.pass_start_bonus .. " 金币")
end

Effect.defs = {
  { id = "start_reward", mandatory = true, can_apply = can_start_reward, apply = apply_start_reward },
  { id = "buy_land", label = "购买地块", mandatory = false, can_apply = can_buy, apply = apply_buy },
  { id = "upgrade_land", label = "加盖建筑", mandatory = false, can_apply = can_upgrade, apply = apply_upgrade },
  {
    id = "pay_rent",
    mandatory = true,
    can_apply = function(ctx)
      local tile = ctx.tile
      local player = ctx.player
      return tile.type == "land" and tile.owner_id and tile.owner_id ~= player.id
    end,
    apply = function(ctx)
      local tile = ctx.tile
      local player = ctx.player
      local owner = ctx.game.players[tile.owner_id]
      if not owner or owner.eliminated then
        tile.owner_id = nil
        return
      end
      -- 强征卡
      local total_value = tile:total_invested()
      local strong_idx = player.inventory and player.inventory:find_index(function(it)
        return it.id == 2009
      end)
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
      if StatusService.is_in_mountain(ctx.game, owner) then
        logger.event(owner.name .. " 在深山，租金不收取")
        return
      end
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

      local board = ctx.game.board
      local idx = board:index_of_tile_id(tile.id) or 1
      local function contiguous_rent(board, index, owner_id)
        local length = board:length()
        local rent_sum = 0
        local i = index
        while i >= 1 do
          local t = board:get_tile(i)
          if t.type == "land" and t.owner_id == owner_id then
            rent_sum = rent_sum + t:current_rent()
            i = i - 1
          else
            break
          end
        end
        i = index + 1
        while i <= length do
          local t = board:get_tile(i)
          if t.type == "land" and t.owner_id == owner_id then
            rent_sum = rent_sum + t:current_rent()
            i = i + 1
          else
            break
          end
        end
        return rent_sum
      end

      local rent = contiguous_rent(board, idx, owner.id)
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
        BankruptcyService.eliminate(ctx.game, player)
      end
    end,
  },
  {
    id = "tax",
    mandatory = true,
    can_apply = function(ctx)
      return ctx.tile.type == "tax"
    end,
    apply = function(ctx)
      local player = ctx.player
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
        BankruptcyService.eliminate(ctx.game, player)
      end
    end,
  },
}

return Effect
