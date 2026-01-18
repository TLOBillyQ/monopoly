local Land = {}
local logger = require("src.util.logger")
local Tile = require("src.core.tile")
local BoardUtils = require("src.gameplay.item_board_utils")
local Pricing = require("src.gameplay.land_pricing")
local LandActions = require("src.gameplay.land_actions")
local LandChoiceSpecs = require("src.gameplay.land_choice_specs")

local tile_state = Tile.get_state

local function can_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  if tile.type ~= "land" then
    return false
  end
  local st = LandActions.safe_tile_state(ctx.game, tile)
  return st.owner_id == nil
end

local function apply_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  if player.cash < tile.price then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "购买失败", body = player.name .. " 余额不足" },
      },
    }
  end
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
  local st = LandActions.safe_tile_state(ctx.game, tile)
  if st.owner_id ~= player.id then
    return false
  end
  if (st.level or 0) >= Pricing.max_level(tile) then
    return false
  end
  return true
end

local function apply_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  local st = LandActions.safe_tile_state(ctx.game, tile)
  local cost = Pricing.upgrade_cost(tile, st.level or 0)
  if player.cash < cost then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "升级失败", body = player.name .. " 余额不足" },
      },
    }
  end
  player:deduct_cash(cost)
  ctx.game:set_tile_level(tile, (st.level or 0) + 1)
  logger.event(player.name .. " 为 " .. tile.name .. " 加盖，花费 " .. cost)
end

local function can_pay_rent(ctx)
  local tile = ctx.tile
  local player = ctx.player
  if tile.type ~= "land" then
    return false
  end
  local st = LandActions.safe_tile_state(ctx.game, tile)
  return st.owner_id and st.owner_id ~= player.id
end

local function apply_pay_rent(ctx)
  local tile = ctx.tile
  local player = ctx.player
  if tile.type ~= "land" then
    return
  end
  local owner, st = LandActions.resolve_rent_owner(ctx.game, tile, tile_state)
  if not owner then
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
        choice_spec = LandChoiceSpecs.rent_prompt(player.id, tile.id, "strong", total_value, tile.name),
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
        choice_spec = LandChoiceSpecs.rent_prompt(player.id, tile.id, "free", nil, tile.name),
      },
    }
  end

  -- 无卡可用，直接支付租金
  LandActions.execute_pay_rent(ctx.game, player.id, tile.id)
end

local function can_tax(ctx)
  return ctx.tile.type == "tax"
end

local function apply_tax(ctx)
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
        choice_spec = LandChoiceSpecs.tax_prompt(player.id),
      },
    }
  end

  -- 无免税卡，直接支付税金
  LandActions.execute_pay_tax(ctx.game, player.id)
end

Land.executors = {
  buy_land = { can_apply = can_buy, apply = apply_buy },
  upgrade_land = { can_apply = can_upgrade, apply = apply_upgrade },
  pay_rent = { can_apply = can_pay_rent, apply = apply_pay_rent },
  tax = { can_apply = can_tax, apply = apply_tax },
}

return Land
