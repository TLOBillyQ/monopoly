local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local land_actions = require("src.rules.land.actions")
local achievement_hooks = require("src.rules.land.achievement_hooks")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_feed = require("src.rules.ports.event_feed")
local effect_payments = require("src.rules.land.effect_payments")
local pricing = require("src.rules.land.pricing")
local monopoly_event = require("src.foundation.events")
local action_anim_port = require("src.foundation.ports.action_anim")
local number_utils = require("src.foundation.number")

local action_anim_duration = timing.action_anim_default_seconds

local M = {}

local function _resolve_tile_feedback_port(game)
  if game == nil then
    return nil
  end
  return game.tile_feedback_port
end

local function _notify_tile_upgraded_direct(game, tile_id, level)
  local tile_feedback_port = _resolve_tile_feedback_port(game)
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
  if ctx.game:player_cash(player) < t.price then
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
  achievement_hooks.record_contiguous_if_reached(ctx.game, player, t)
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
  if ctx.game:player_cash(player) < cost then
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

M.executors = {
  buy_land = { can_apply = _can_buy, apply = _apply_buy },
  upgrade_land = { can_apply = _can_upgrade, apply = _apply_upgrade },
  pay_rent = effect_payments.executors.pay_rent,
  tax = effect_payments.executors.tax,
}

return M

--[[ mutate4lua-manifest
version=4
projectHash=a7292454c195e0e7
scope.0.id=chunk:src/rules/land/effect_base.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=126
scope.0.semanticHash=76e46755e8a5bcd0
scope.1.id=function:_resolve_tile_feedback_port
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=22
scope.1.semanticHash=fecf6e8094b12276
scope.2.id=function:_notify_tile_upgraded_direct
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=34
scope.2.semanticHash=1448ae307acb2912
scope.3.id=function:_can_buy
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=42
scope.3.semanticHash=82fb99fe89ac4fc1
scope.4.id=function:_apply_buy
scope.4.kind=function
scope.4.startLine=44
scope.4.endLine=64
scope.4.semanticHash=3c4655fc61f2b358
scope.5.id=function:_can_upgrade
scope.5.kind=function
scope.5.startLine=66
scope.5.endLine=75
scope.5.semanticHash=2d98dc17c6f89c8e
scope.6.id=function:_apply_upgrade
scope.6.kind=function
scope.6.startLine=77
scope.6.endLine=116
scope.6.semanticHash=6021e14ad2d58a99
]]
