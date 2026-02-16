local action = require("game.land.action")
local price = require("game.land.price")
local utils = require("game.land.utils")
local tile = require("game.tile")
local inventory = require("game.item.inventory")
local choice_spec = require("game.land.choice_spec")
local logger = require("core.logger")
local game_event = require("game.event")
local gameplay_rules = require("cfg.GameplayRules")

local land_effect = {}

local tile_state = tile.get_state
local item_ids = gameplay_rules.item_ids
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

local function _can_buy(ctx)
  local tile_obj = ctx.tile
  assert(tile_obj ~= nil, "missing tile")
  if tile_obj.type ~= "land" then
    return false
  end
  local st = action.safe_tile_state(ctx.game, tile_obj)
  return not st.owner_id
end

local function _apply_buy(ctx)
  local tile_obj = ctx.tile
  local player = ctx.player
  if ctx.game:player_balance(player, "金币") < tile_obj.price then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "购买失败", body = player.name .. " 余额不足" },
      },
    }
  end
  ctx.game:deduct_player_cash(player, tile_obj.price)
  ctx.game:set_tile_owner(tile_obj, player.id)
  ctx.game:set_player_property(player, tile_obj.id, true)
  logger.event(player.name .. " 购买 " .. tile_obj.name .. " 花费 " .. tile_obj.price)
end

local function _can_upgrade(ctx)
  local tile_obj = ctx.tile
  local player = ctx.player
  assert(tile_obj ~= nil, "missing tile")
  if tile_obj.type ~= "land" then
    return false
  end
  local st = action.safe_tile_state(ctx.game, tile_obj)
  if st.owner_id ~= player.id then
    return false
  end
  if (st.level or 0) >= price.max_level(tile_obj) then
    return false
  end
  return true
end

local function _apply_upgrade(ctx)
  local tile_obj = ctx.tile
  local player = ctx.player
  local st = action.safe_tile_state(ctx.game, tile_obj)
  local cost = price.upgrade_cost(tile_obj, st.level or 0)
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
  ctx.game:set_tile_level(tile_obj, new_level)
  game_event.emit(game_event.land.tile_upgraded, {
    tile_id = tile_obj.id,
    level = new_level,
  })
  logger.event(player.name .. " 为 " .. tile_obj.name .. " 加盖，花费 " .. cost)
  local ui_port = ctx.game.ui_port
  if ui_port and ui_port.wait_action_anim then
    local tile_index = ctx.game.board:index_of_tile_id(tile_obj.id)
    if tile_index then
      ctx.game:queue_action_anim({
        kind = "upgrade_land",
        player_id = player.id,
        tile_index = tile_index,
        duration = action_anim_duration,
      })
    end
  end
end

local function _can_pay_rent(ctx)
  local tile_obj = ctx.tile
  local player = ctx.player
  assert(tile_obj ~= nil, "missing tile")
  if tile_obj.type ~= "land" then
    return false
  end
  local st = action.safe_tile_state(ctx.game, tile_obj)
  return st.owner_id and st.owner_id ~= player.id
end

local function _apply_pay_rent(ctx)
  local tile_obj = ctx.tile
  local player = ctx.player
  assert(tile_obj ~= nil and tile_obj.type == "land", "invalid land tile")
  local owner, st = action.resolve_rent_owner(ctx.game, tile_obj, tile_state)
  if not owner then
    return
  end

  if player.status.pending_free_rent then
    ctx.game:set_player_status(player, "pending_free_rent", false)
    logger.event(player.name .. " 使用免费卡，免租 " .. tile_obj.name)
    return
  end

  local total_value = utils.total_invested(tile_obj, st.level)
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
        choice_spec = choice_spec.rent_prompt(player.id, tile_obj.id, "strong", total_value, tile_obj.name),
      },
    }
  end

  if free_idx then
    action.execute_free_card(ctx.game, player.id, tile_obj.id)
    return
  end

  action.execute_pay_rent(ctx.game, player.id, tile_obj.id)
end

function land_effect.buy_executor()
  return { can_apply = _can_buy, apply = _apply_buy }
end

function land_effect.upgrade_executor()
  return { can_apply = _can_upgrade, apply = _apply_upgrade }
end

function land_effect.rent_executor()
  return { can_apply = _can_pay_rent, apply = _apply_pay_rent }
end

return land_effect
