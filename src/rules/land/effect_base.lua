local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local tile_mod = require("src.rules.board.tile")
local land_actions = require("src.rules.land.actions")
local land_choice_specs = require("src.rules.land.choice_specs")
local rent_resolver = require("src.rules.land.rent_resolver")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_feed = require("src.rules.ports.event_feed")
local inventory = require("src.rules.items.inventory")
local use_broadcast = require("src.rules.items.use_broadcast")
local pricing = require("src.rules.land.pricing")
local board_utils = require("src.rules.land.board_utils")
local monopoly_event = require("src.foundation.events")
local action_anim_port = require("src.foundation.ports.action_anim")
local number_utils = require("src.foundation.number")

local tile_state = tile_mod.get_state
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local M = {}

local function _record_contiguous_if_reached(game, player, tile)
  local board = game and game.board or nil
  if not (board and tile and tile.id ~= nil) then
    return
  end
  local tile_index = board:index_of_tile_id(tile.id)
  if tile_index == nil then
    return
  end
  local count = rent_resolver.contiguous_count(game, board, tile_index, player.id)
  if count >= 3 then
    achievement_progress.contiguous_lands(game, player)
  end
end

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
  achievement_progress.land_purchased(ctx.game, player)
  _record_contiguous_if_reached(ctx.game, player, t)
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
  achievement_progress.building_upgraded(ctx.game, player, new_level)
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

--[[ mutate4lua-manifest
version=2
projectHash=9f02146f6e0ea20a
scope.0.id=chunk:src/rules/land/effect_base.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=232
scope.0.semanticHash=163e42151cecd54c
scope.1.id=function:_notify_tile_upgraded_direct:22
scope.1.kind=function
scope.1.startLine=22
scope.1.endLine=35
scope.1.semanticHash=c55b1abda1a36f09
scope.2.id=function:_can_buy:37
scope.2.kind=function
scope.2.startLine=37
scope.2.endLine=43
scope.2.semanticHash=ef3fe6bd5ca19125
scope.3.id=function:_apply_buy:45
scope.3.kind=function
scope.3.startLine=45
scope.3.endLine=63
scope.3.semanticHash=ea9abbaaceb82f93
scope.4.id=function:_can_upgrade:65
scope.4.kind=function
scope.4.startLine=65
scope.4.endLine=74
scope.4.semanticHash=02eb5dbd75da99ee
scope.5.id=function:_apply_upgrade:76
scope.5.kind=function
scope.5.startLine=76
scope.5.endLine=114
scope.5.semanticHash=73d56b4b106bb3f2
scope.6.id=function:_can_pay_rent:116
scope.6.kind=function
scope.6.startLine=116
scope.6.endLine=123
scope.6.semanticHash=1ae425e3a50fdf89
scope.7.id=function:_can_use_strong_card:139
scope.7.kind=function
scope.7.startLine=139
scope.7.endLine=141
scope.7.semanticHash=d0e13c69dc7554b7
scope.8.id=function:_build_rent_choice_intent:143
scope.8.kind=function
scope.8.startLine=143
scope.8.endLine=152
scope.8.semanticHash=de0acb9d2ca66d2f
scope.9.id=function:_apply_pay_rent:154
scope.9.kind=function
scope.9.startLine=154
scope.9.endLine=184
scope.9.semanticHash=748ee1816a2d0696
scope.10.id=function:_can_tax:186
scope.10.kind=function
scope.10.startLine=186
scope.10.endLine=189
scope.10.semanticHash=4b6591ac510635ed
scope.11.id=function:_apply_tax:191
scope.11.kind=function
scope.11.startLine=191
scope.11.endLine=222
scope.11.semanticHash=8aa7657b32b07955
]]
