local logger = require("src.core.Logger")
local gameplay_rules = require("Config.GameplayRules")
local tile = require("src.game.systems.board.Tile")
local land_actions = require("src.game.systems.land.LandActions")
local land_choice_specs = require("src.game.systems.land.LandChoiceSpecs")
local inventory = require("src.game.systems.items.ItemInventory")
local pricing = require("src.game.systems.land.LandPricing")
local board_utils = require("src.game.systems.land.LandBoardUtils")
local monopoly_event = require("src.core.events.MonopolyEvents")
local action_anim_port = require("src.core.ActionAnimPort")

local tile_state = tile.get_state
local item_ids = gameplay_rules.item_ids
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

local M = {}

local function _can_buy(ctx)
  local t = ctx.tile
  assert(t ~= nil, "missing tile")
  if t.type ~= "land" then return false end
  local st = land_actions.safe_tile_state(ctx.game, t)
  return not st.owner_id
end

local function _apply_buy(ctx)
  local t = ctx.tile
  local player = ctx.player
  if ctx.game:player_balance(player, "金币") < t.price then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "购买失败", body = player.name .. " 余额不足" },
      },
    }
  end
  ctx.game:deduct_player_cash(player, t.price)
  ctx.game:set_tile_owner(t, player.id)
  ctx.game:set_player_property(player, t.id, true)
  logger.event(player.name .. " 购买 " .. t.name .. " 花费 " .. t.price)
end

local function _can_upgrade(ctx)
  local t = ctx.tile
  local player = ctx.player
  assert(t ~= nil, "missing tile")
  if t.type ~= "land" then return false end
  local st = land_actions.safe_tile_state(ctx.game, t)
  if st.owner_id ~= player.id then return false end
  if (st.level or 0) >= pricing.max_level(t) then return false end
  return true
end

local function _apply_upgrade(ctx)
  local t = ctx.tile
  local player = ctx.player
  local st = land_actions.safe_tile_state(ctx.game, t)
  local cost = pricing.upgrade_cost(t, st.level or 0)
  if ctx.game:player_balance(player, "金币") < cost then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "升级失败", body = player.name .. " 余额不足" },
      },
    }
  end
  ctx.game:deduct_player_cash(player, cost)
  local new_level = (st.level or 0) + 1
  ctx.game:set_tile_level(t, new_level)
  monopoly_event.emit(monopoly_event.land.tile_upgraded, {
    tile_id = t.id,
    level = new_level,
  })
  logger.event(player.name .. " 为 " .. t.name .. " 加盖，花费 " .. cost)
  local tile_index = ctx.game.board:index_of_tile_id(t.id)
  if tile_index then
    action_anim_port.queue(ctx.game, {
      kind = "upgrade_land",
      player_id = player.id,
      tile_index = tile_index,
      duration = action_anim_duration,
    })
  end
end

local function _can_pay_rent(ctx)
  local t = ctx.tile
  local player = ctx.player
  assert(t ~= nil, "missing tile")
  if t.type ~= "land" then return false end
  local st = land_actions.safe_tile_state(ctx.game, t)
  return st.owner_id and st.owner_id ~= player.id
end

local function _apply_pay_rent(ctx)
  local t = ctx.tile
  local player = ctx.player
  assert(t ~= nil and t.type == "land", "invalid land tile")
  local owner, st = land_actions.resolve_rent_owner(ctx.game, t, tile_state)
  if not owner then return end

  if player.status.pending_free_rent then
    ctx.game:set_player_status(player, "pending_free_rent", false)
    logger.event(player.name .. " 使用免费卡，免租 " .. t.name)
    return
  end

  local total_value = board_utils.total_invested(t, st.level)
  local strong_idx = nil
  local free_idx = nil
  for idx, it in ipairs(inventory.items(player)) do
    if it.id == item_ids.strong then
      strong_idx = idx
      if free_idx then break end
    elseif it.id == item_ids.free_rent then
      free_idx = idx
      if strong_idx then break end
    end
  end
  local can_use_strong = strong_idx and ctx.game:player_balance(player, "金币") >= total_value
  if can_use_strong then
    return {
      waiting = true,
      reason = "rent_choice",
      intent = {
        kind = "need_choice",
        choice_spec = land_choice_specs.rent_prompt(player.id, t.id, "strong", total_value, t.name),
      },
    }
  end

  if free_idx then
    land_actions.execute_free_card(ctx.game, player.id, t.id)
    return
  end

  land_actions.execute_pay_rent(ctx.game, player.id, t.id)
end

local function _can_tax(ctx)
  assert(ctx.tile ~= nil, "missing tile")
  return ctx.tile.type == "tax"
end

local function _apply_tax(ctx)
  local player = ctx.player

  if player.status.pending_tax_free then
    logger.event(player.name .. " 使用免税卡，本次免税")
    ctx.game:set_player_status(player, "pending_tax_free", false)
    return
  end

  local tax_idx = inventory.find_index(player, item_ids.tax_free)
  if tax_idx then
    return {
      waiting = true,
      reason = "tax_choice",
      intent = {
        kind = "need_choice",
        choice_spec = land_choice_specs.tax_prompt(player.id),
      },
    }
  end

  land_actions.execute_pay_tax(ctx.game, player.id)
end

M.executors = {
  buy_land = { can_apply = _can_buy, apply = _apply_buy },
  upgrade_land = { can_apply = _can_upgrade, apply = _apply_upgrade },
  pay_rent = { can_apply = _can_pay_rent, apply = _apply_pay_rent },
  tax = { can_apply = _can_tax, apply = _apply_tax },
}

return M

