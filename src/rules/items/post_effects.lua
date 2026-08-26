local constants = require("src.config.content.constants")
local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local obstacle_clear = require("src.rules.items.obstacle_clear")
local target_effects = require("src.rules.items.target_effects")

local post_effects = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local post_effects_cfg = {

  [item_ids.free_rent] = { type = "set_status", key = "pending_free_rent", value = true, message = " 使用免费卡，下一次租金免除" },
  [item_ids.dice_multiplier] = { type = "set_status", key = "pending_dice_multiplier", value = 2, message = " 使用骰子加倍卡，本次步数翻倍" },
  [item_ids.tax_free] = { type = "set_status", key = "pending_tax_free", value = true, message = " 使用免税卡，本次征税免除" },


  [item_ids.mine] = { type = "place_mine_here" },
  [item_ids.clear_obstacles] = { type = "clear_obstacles_ahead", distance = 12 },


  [item_ids.strong] = { type = "log", message = " 准备使用强征卡（踩他人地块时触发）" },


  [item_ids.rich] = { type = "deity", deity = "rich", warn = "附身财神", log = " 使用财神卡，财神附身" },
  [item_ids.angel] = { type = "deity", deity = "angel", warn = "附身天使", log = " 使用天使卡，天使附身" },
}

local handlers = {}

local function _handle_set_status(game, player, cfg)
  local value = assert(cfg.value, "missing status value")
  game:set_player_status(player, cfg.key, value)
  if cfg.message then
    event_feed.publish(game, {
      kind = event_kinds.item_used,
      text = player.name .. cfg.message,
    })
  end
  return true
end

local function _handle_deity(game, player, cfg)
  game:set_player_deity(player, cfg.deity, constants.deity_duration_turns)
  if cfg.log then
    event_feed.publish(game, {
      kind = event_kinds.deity_attached,
      text = player.name .. cfg.log,
    })
  end
  return true
end

local function _handle_log(game, player, cfg)
  assert(cfg.message ~= nil, "missing log message")
  event_feed.publish(game, {
    kind = event_kinds.item_used,
    text = player.name .. cfg.message,
  })
  return true
end

local function _handle_place_mine_here(game, player)
  game:place_mine(player.position, {
    owner_id = player.id,
    armed = true,
    placed_turn_count = game.turn and game.turn.turn_count or nil,
    owner_turn_started_count_at_placement = game:player_own_turn_started_count(player),
  })
  event_feed.publish(game, {
    kind = event_kinds.mine_placed,
    text = player.name .. " 在脚下埋设地雷",
  })
  local queued = action_anim_port.queue(game, {
    kind = "mine",
    player_id = player.id,
    tile_index = player.position,
    duration = action_anim_duration,
  })
  if queued then
    return { ok = true, action_anim = true }
  end
  return true
end

handlers.set_status = _handle_set_status
handlers.deity = _handle_deity
handlers.log = _handle_log
handlers.place_mine_here = _handle_place_mine_here
handlers.clear_obstacles_ahead = obstacle_clear.handle

function post_effects.get_target_spec(item_id)
  return target_effects.get(item_id)
end

function post_effects.target_item_ids()
  return target_effects.ids()
end

function post_effects.apply_target(game, user, item_id, target, context)
  assert(user ~= nil and target ~= nil, "missing user/target")
  assert(user.id ~= target.id,
         "apply_target: user and target must differ (item_id=" .. tostring(item_id) .. ")")
  local spec = target_effects.get(item_id)
  assert(spec ~= nil and spec.apply ~= nil, "missing target spec: " .. tostring(item_id))
  return spec.apply(game, user, target, context)
end

function post_effects.apply_post(game, player, item_id, context)
  context = context or {}
  local cfg = assert(post_effects_cfg[item_id], "missing post effect: " .. tostring(item_id))
  local handler = assert(handlers[cfg.type], "missing post effect handler: " .. tostring(cfg.type))
  return handler(game, player, cfg, context)
end

return post_effects

--[[ mutate4lua-manifest
version=4
projectHash=f6db405ee6cab950
scope.0.id=chunk:src/rules/items/post_effects.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=119
scope.0.semanticHash=dc1f6ede196f6def
scope.1.id=function:_handle_set_status
scope.1.kind=function
scope.1.startLine=33
scope.1.endLine=43
scope.1.semanticHash=550c535cdd076736
scope.2.id=function:_handle_deity
scope.2.kind=function
scope.2.startLine=45
scope.2.endLine=54
scope.2.semanticHash=c215af37e650afe2
scope.3.id=function:_handle_log
scope.3.kind=function
scope.3.startLine=56
scope.3.endLine=63
scope.3.semanticHash=68a1dcd94338ef22
scope.4.id=function:_handle_place_mine_here
scope.4.kind=function
scope.4.startLine=65
scope.4.endLine=86
scope.4.semanticHash=f4d3bea631bd4917
scope.5.id=function:post_effects.get_target_spec
scope.5.kind=function
scope.5.startLine=94
scope.5.endLine=96
scope.5.semanticHash=f1ce1850b7232305
scope.6.id=function:post_effects.target_item_ids
scope.6.kind=function
scope.6.startLine=98
scope.6.endLine=100
scope.6.semanticHash=04a3b0c01baa0aa1
scope.7.id=function:post_effects.apply_target
scope.7.kind=function
scope.7.startLine=102
scope.7.endLine=109
scope.7.semanticHash=f2d599990cf62cb8
scope.8.id=function:post_effects.apply_post
scope.8.kind=function
scope.8.startLine=111
scope.8.endLine=116
scope.8.semanticHash=c0e5cf4d957998a7
]]
