local Effect = {}
local logger = require("src.util.logger")
local constants = require("src.config.constants")
local Tile = require("src.core.tile")
local BoardUtils = require("src.gameplay.item_board_utils")
local Pricing = require("src.gameplay.land_pricing")

local tile_state = Tile.get_state

local function next_upgrade_cost(tile, level)
  return Pricing.upgrade_cost(tile, level or 0)
end

local function current_rent(tile, level)
  return Pricing.rent_for_level(tile, level or 0)
end

local function max_level(tile)
  return Pricing.max_level(tile)
end

-- 计算连续地块租金
local function contiguous_rent(game, board, index, owner_id)
  local length = board:length()
  local rent_sum = 0
  local i = index
  while i >= 1 do
    local t = board:get_tile(i)
    if t.type == "land" then
      local st2 = tile_state(game, t)
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
      local st2 = tile_state(game, t)
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

-- 执行强征卡效果（由 choice_resolver 调用）
function Effect.execute_strong_card(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  if not player or not tile then return false end

  local st = tile_state(game, tile)
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

-- 执行免费卡（免租）效果（由 choice_resolver 调用）
function Effect.execute_free_card(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  if not player or not tile then return false end

  local free_idx = player.inventory and player.inventory:find_index(function(it) return it.id == 2001 end)
  if not free_idx then return false end

  player.inventory:remove_by_index(free_idx)
  logger.event(player.name .. " 出示免费卡，免租 " .. tile.name)
  return true
end

-- 执行租金支付（由 choice_resolver 调用，当用户跳过所有卡牌选项后）
function Effect.execute_pay_rent(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  if not player or not tile then return false end

  local st = tile_state(game, tile)
  local owner = st.owner_id and game.players[st.owner_id] or nil
  if not owner or owner.eliminated then
    game:set_tile_owner(tile, nil)
    return true
  end

  if owner.is_in_mountain and owner:is_in_mountain(game) then
    logger.event(owner.name .. " 在深山，租金不收取")
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
  else
    local paid = player.cash
    owner:add_cash(paid)
    player:set_cash(0)
    logger.event(player.name .. " 资金不足，支付剩余 " .. paid .. " 后破产")
    local bankruptcy = game.services and game.services.bankruptcy
    if bankruptcy and bankruptcy.eliminate then
      bankruptcy.eliminate(game, player)
    end
  end
  return true
end

-- 执行免税卡效果（由 choice_resolver 调用）
function Effect.execute_tax_free_card(game, player_id)
  local player = game.players[player_id]
  if not player then return false end

  local tax_idx = player.inventory and player.inventory:find_index(function(it) return it.id == 2010 end)
  if not tax_idx then return false end

  player.inventory:remove_by_index(tax_idx)
  logger.event(player.name .. " 出示免税卡，本次免税")
  return true
end

-- 执行税金支付（由 choice_resolver 调用，当用户跳过免税卡后）
function Effect.execute_pay_tax(game, player_id)
  local player = game.players[player_id]
  if not player then return false end

  local fee = math.floor(player.cash * constants.tax_rate)
  if player.cash < fee then fee = player.cash end

  player:deduct_cash(fee)
  logger.event(player.name .. " 在税务局支付税金 " .. fee)

  if player.cash <= 0 then
    local bankruptcy = game.services and game.services.bankruptcy
    if bankruptcy and bankruptcy.eliminate then
      bankruptcy.eliminate(game, player)
    end
  end
  return true
end


local function can_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  if tile.type ~= "land" then
    return false
  end
  local st = tile_state(ctx.game, tile)
  return st.owner_id == nil and player.cash >= tile.price
end

local function apply_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  player:deduct_cash(tile.price)
  ctx.game:set_tile_owner(tile, player.id)
  ctx.game:set_player_property(player, tile.id, true)
  logger.event(player.name .. " 购买 " .. tile.name .. " 花费 " .. tile.price)
end


local function can_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  if tile.type ~= "land" then
    return false
  end
  local st = tile_state(ctx.game, tile)
  if st.owner_id ~= player.id then
    return false
  end
  if (st.level or 0) >= max_level(tile) then
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


Effect.defs = {
  { id = "buy_land", label = "购买地块", mandatory = false, can_apply = can_buy, apply = apply_buy },
  { id = "upgrade_land", label = "加盖建筑", mandatory = false, can_apply = can_upgrade, apply = apply_upgrade },
  {
    id = "pay_rent",
    mandatory = true,
    can_apply = function(ctx)
      local tile = ctx.tile
      local player = ctx.player
      if tile.type ~= "land" then
        return false
      end
      local st = tile_state(ctx.game, tile)
      return st.owner_id and st.owner_id ~= player.id
    end,
    apply = function(ctx)
      local tile = ctx.tile
      local player = ctx.player
      if tile.type ~= "land" then
        return
      end
      local st = tile_state(ctx.game, tile)
      local owner = st.owner_id and ctx.game.players[st.owner_id] or nil
      if not owner or owner.eliminated then
        ctx.game:set_tile_owner(tile, nil)
        return
      end

      -- 检查深山状态
      if owner.is_in_mountain and owner:is_in_mountain(ctx.game) then
        logger.event(owner.name .. " 在深山，租金不收取")
        return
      end

      -- 检查预置免租状态
      if player.status.pending_free_rent then
        ctx.game:set_player_status(player, "pending_free_rent", false)
        logger.event(player.name .. " 使用免费卡，免租 " .. tile.name)
        return
      end

      -- 检查强征卡
      local total_value = BoardUtils.total_invested(tile, st.level)
      local strong_idx = player.inventory and player.inventory:find_index(function(it) return it.id == 2009 end)
      if strong_idx and player.cash >= total_value then
        return {
          waiting = true,
          reason = "rent_choice",
          intent = {
            kind = "need_choice",
            choice_spec = {
              kind = "rent_card_prompt",
              title = "是否使用强征卡",
              body_lines = { "支付 " .. tostring(total_value) .. " 强制购入 " .. tile.name },
              options = {
                { id = "use", label = "使用" },
                { id = "skip", label = "放弃" },
              },
              allow_cancel = false,
              meta = { player_id = player.id, tile_id = tile.id, card_kind = "strong" },
            },
          },
        }
      end

      -- 检查免费卡
      local free_idx = player.inventory and player.inventory:find_index(function(it) return it.id == 2001 end)
      if free_idx then
        return {
          waiting = true,
          reason = "rent_choice",
          intent = {
            kind = "need_choice",
            choice_spec = {
              kind = "rent_card_prompt",
              title = "是否使用免费卡",
              body_lines = { "免除本次租金" },
              options = {
                { id = "use", label = "使用" },
                { id = "skip", label = "放弃" },
              },
              allow_cancel = false,
              meta = { player_id = player.id, tile_id = tile.id, card_kind = "free" },
            },
          },
        }
      end

      -- 无卡可用，直接支付租金
      Effect.execute_pay_rent(ctx.game, player.id, tile.id)
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

      -- 检查预置免税状态
      if player.status.pending_tax_free then
        logger.event(player.name .. " 使用免税卡，本次免税")
        ctx.game:set_player_status(player, "pending_tax_free", false)
        return
      end

      -- 检查免税卡
      local tax_idx = player.inventory and player.inventory:find_index(function(it) return it.id == 2010 end)
      if tax_idx then
        return {
          waiting = true,
          reason = "tax_choice",
          intent = {
            kind = "need_choice",
            choice_spec = {
              kind = "tax_card_prompt",
              title = "是否使用免税卡",
              body_lines = { "使用免税卡可免除本次税金" },
              options = {
                { id = "use", label = "使用" },
                { id = "skip", label = "放弃" },
              },
              allow_cancel = false,
              meta = { player_id = player.id },
            },
          },
        }
      end

      -- 无免税卡，直接支付税金
      Effect.execute_pay_tax(ctx.game, player.id)
    end,
  },
}

return Effect
