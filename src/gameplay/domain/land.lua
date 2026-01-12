local Effect = {}
local logger = require("src.util.logger")
local constants = require("src.config.constants")

local MAX_LEVEL = 3

local function tile_state(game, tile)
  if not game or not game.store or not tile or tile.type ~= "land" then
    return { owner_id = nil, level = 0 }
  end
  local s = game.store:get({ "board", "tiles", tile.id })
  if type(s) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = s.owner_id, level = s.level or 0 }
end

local function next_upgrade_cost(tile, level)
  local target_level = (level or 0) + 1
  return (tile.price or 0) * (2 ^ target_level)
end

local function current_rent(tile, level)
  local exponent = level or 0
  return (tile.price or 0) * (2 ^ exponent) * 0.5
end

local function total_invested(tile, owner_id, level)
  if not owner_id then
    return 0
  end
  level = level or 0
  local price = tile.price or 0
  -- price * (2^(level+1) - 1)
  return price * ((2 ^ (level + 1)) - 1)
end

local function get_service(game, key)
  return game and game.services and game.services[key]
end

-- Optional: buy land if unowned and player has cash
local function can_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  local st = tile_state(ctx.game, tile)
  return tile.type == "land" and st.owner_id == nil and player.cash >= tile.price
end

local function apply_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  player:deduct_cash(tile.price)
  ctx.game:set_tile_owner(tile, player.id)
  ctx.game:set_player_property(player, tile.id, true)
  logger.event(player.name .. " 购买 " .. tile.name .. " 花费 " .. tile.price)
end

-- Optional: upgrade own land if possible and affordable
local function can_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  local st = tile_state(ctx.game, tile)
  if tile.type ~= "land" or st.owner_id ~= player.id then
    return false
  end
  if (st.level or 0) >= MAX_LEVEL then
    return false
  end
  local cost = next_upgrade_cost(tile, st.level)
  return player.cash >= cost
end

local function apply_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  local st = tile_state(ctx.game, tile)
  local cost = next_upgrade_cost(tile, st.level)
  player:deduct_cash(cost)
  ctx.game:set_tile_level(tile, (st.level or 0) + 1)
  logger.event(player.name .. " 为 " .. tile.name .. " 加盖，花费 " .. cost)
end

-- Mandatory: start tile reward on landing
Effect.defs = {
  { id = "buy_land", label = "购买地块", mandatory = false, can_apply = can_buy, apply = apply_buy },
  { id = "upgrade_land", label = "加盖建筑", mandatory = false, can_apply = can_upgrade, apply = apply_upgrade },
  {
    id = "pay_rent",
    mandatory = true,
    can_apply = function(ctx)
      local tile = ctx.tile
      local player = ctx.player
      local st = tile_state(ctx.game, tile)
      return tile.type == "land" and st.owner_id and st.owner_id ~= player.id
    end,
    apply = function(ctx)
      local tile = ctx.tile
      local player = ctx.player
      local st = tile_state(ctx.game, tile)
      local owner = st.owner_id and ctx.game.players[st.owner_id] or nil
      if not owner or owner.eliminated then
        ctx.game:set_tile_owner(tile, nil)
        return
      end
      -- 强征卡
      local total_value = total_invested(tile, st.owner_id, st.level)
      local strong_idx = player.inventory and player.inventory:find_index(function(it)
        return it.id == 2009
      end)
      if strong_idx and player.cash >= total_value then
        player.inventory:remove_by_index(strong_idx)
        player:deduct_cash(total_value)
        owner:add_cash(total_value)
        ctx.game:set_tile_owner(tile, player.id)
        ctx.game:set_player_property(owner, tile.id, false)
        ctx.game:set_player_property(player, tile.id, true)
        logger.event(player.name .. " 使用强征卡，支付 " .. total_value .. " 强制购入 " .. tile.name)
        return
      end
      local status = get_service(ctx.game, "status")
      if status and status.is_in_mountain and status.is_in_mountain(ctx.game, owner) then
        logger.event(owner.name .. " 在深山，租金不收取")
        return
      end
      if player.status.pending_free_rent then
        ctx.game:set_player_status(player, "pending_free_rent", false)
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
          if t.type == "land" then
            local st2 = tile_state(ctx.game, t)
            if st2.owner_id == owner_id then
              rent_sum = rent_sum + current_rent(t, st2.level)
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
            local st2 = tile_state(ctx.game, t)
            if st2.owner_id == owner_id then
              rent_sum = rent_sum + current_rent(t, st2.level)
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
        player:set_cash(0)
        logger.event(player.name .. " 资金不足，支付剩余 " .. paid .. " 后破产")
        local bankruptcy = get_service(ctx.game, "bankruptcy")
        if bankruptcy and bankruptcy.eliminate then
          bankruptcy.eliminate(ctx.game, player)
        else
          logger.warn("缺少 BankruptcyService，无法处理破产")
        end
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
        ctx.game:set_player_status(player, "pending_tax_free", false)
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
        local bankruptcy = get_service(ctx.game, "bankruptcy")
        if bankruptcy and bankruptcy.eliminate then
          bankruptcy.eliminate(ctx.game, player)
        else
          logger.warn("缺少 BankruptcyService，无法处理破产")
        end
      end
    end,
  },
}

return Effect
