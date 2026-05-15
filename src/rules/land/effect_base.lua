local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local tile_mod = require("src.rules.board.tile")
local land_actions = require("src.rules.land.actions")
local land_choice_specs = require("src.rules.land.choice_specs")
local event_feed = require("src.rules.ports.event_feed")
local inventory = require("src.rules.items.inventory")
local use_broadcast = require("src.rules.items.use_broadcast")
local angel_feedback = require("src.rules.items.angel_feedback")
local pricing = require("src.rules.land.pricing")
local board_utils = require("src.rules.land.board_utils")
local monopoly_event = require("src.foundation.events")
local action_anim_port = require("src.foundation.ports.action_anim")
local number_utils = require("src.foundation.number")

local tile_state = tile_mod.get_state
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local M = {}

local function _notify_tile_upgraded_direct(game, tile_id, level)
  local tile_feedback_port = game and game.tile_feedback_port or nil
  if tile_feedback_port == nil and game and type(game.ensure_tile_feedback_port) == "function" then
    tile_feedback_port = game:ensure_tile_feedback_port()
  end
  if not (tile_feedback_port and type(tile_feedback_port.on_tile_upgraded) == "function") then
    return false
  end
  local ok, handled = pcall(tile_feedback_port.on_tile_upgraded, tile_feedback_port, tile_id, level)
  if not ok then
    return false
  end
  return handled == true
end

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
  event_feed.publish(ctx.game, {
    kind = event_kinds.land_purchase,
    text = player.name .. " 购买 " .. t.name .. " 花费 " .. number_utils.format_integer_part(t.price),
  })
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
  local old_level = st.level or 0
  local cost = pricing.upgrade_cost(t, old_level)
  if ctx.game:player_balance(player, "金币") < cost then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "升级失败", body = player.name .. " 余额不足" },
      },
    }
  end
  ctx.game:deduct_player_cash(player, cost)
  local new_level = old_level + 1
  ctx.game:set_tile_level(t, new_level)
  local tile_index = ctx.game.board:index_of_tile_id(t.id)
  local direct_notified = _notify_tile_upgraded_direct(ctx.game, t.id, new_level)
  if not direct_notified then
    monopoly_event.emit(monopoly_event.land.tile_upgraded, {
      tile_id = t.id,
      level = new_level,
    })
  end
  event_feed.publish(ctx.game, {
    kind = event_kinds.land_upgrade,
    text = player.name .. " 为 " .. t.name .. " 加盖，花费 " .. number_utils.format_integer_part(cost),
  })
  if tile_index then
    action_anim_port.queue(ctx.game, {
      kind = "upgrade_land",
      player_id = player.id,
      tile_index = tile_index,
      level = new_level,
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

local function _find_rent_item_indices(player)
  local strong_idx, free_idx = nil, nil
  for idx, it in ipairs(inventory.items(player)) do
    if it.id == item_ids.strong then
      strong_idx = idx
      if free_idx then break end
    elseif it.id == item_ids.free_rent then
      free_idx = idx
      if strong_idx then break end
    end
  end
  return strong_idx, free_idx
end

local function _can_use_strong_card(player, strong_idx, total_value, game)
  return strong_idx and game:player_balance(player, "金币") >= total_value
end

local function _build_rent_choice_intent(player, tile, card_kind, total_value)
  return {
    waiting = true,
    reason = "rent_choice",
    intent = {
      kind = "need_choice",
      choice_spec = land_choice_specs.rent_prompt(player.id, tile.id, card_kind, total_value, tile.name),
    },
  }
end

local function _apply_pay_rent(ctx)
  local t = ctx.tile
  local player = ctx.player
  assert(t ~= nil and t.type == "land", "invalid land tile")
  local owner, st = land_actions.resolve_rent_owner(ctx.game, t, tile_state)
  if not owner then return end

  if player.status.pending_free_rent then
    ctx.game:set_player_status(player, "pending_free_rent", false)
    use_broadcast.dispatch(ctx.game, player, item_ids.free_rent)
    event_feed.publish(ctx.game, {
      kind = event_kinds.rent_immune,
      text = player.name .. " 使用免费卡，免租 " .. t.name,
    })
    return
  end

  local total_value = board_utils.total_invested(t, st.level)
  local strong_idx, free_idx = _find_rent_item_indices(player)

  if _can_use_strong_card(player, strong_idx, total_value, ctx.game) then
    return _build_rent_choice_intent(player, t, "strong", total_value)
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

  if ctx.game:player_has_angel(player) then
    angel_feedback.publish(ctx.game, player, "税务局查税", { tile_index = player.position })
    return
  end

  if player.status.pending_tax_free then
    ctx.game:set_player_status(player, "pending_tax_free", false)
    use_broadcast.dispatch(ctx.game, player, item_ids.tax_free)
    event_feed.publish(ctx.game, {
      kind = event_kinds.tax_immune,
      text = player.name .. " 使用免税卡，本次免税",
    })
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
