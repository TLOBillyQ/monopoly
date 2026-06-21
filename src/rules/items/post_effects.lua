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
    owner_turn_started_count_at_placement = player
      and player.status
      and player.status.own_turn_started_count
      or 0,
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
version=2
projectHash=e719107411126be2
scope.0.id=chunk:src/rules/items/post_effects.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=318
scope.0.semanticHash=4cf5a6a7768fafb7
scope.1.id=function:_should_emit_share_wealth_cash_receive:29
scope.1.kind=function
scope.1.startLine=29
scope.1.endLine=35
scope.1.semanticHash=2ce73e689ff694c0
scope.2.id=function:_build_exile_log_entry:37
scope.2.kind=function
scope.2.startLine=37
scope.2.endLine=44
scope.2.semanticHash=60ab27963ed998d8
scope.3.id=function:anonymous@48:48
scope.3.kind=function
scope.3.startLine=48
scope.3.endLine=50
scope.3.semanticHash=9eabf8dc7b6b8d79
scope.4.id=function:anonymous@51:51
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=53
scope.4.semanticHash=ad0b6e0179521886
scope.5.id=function:anonymous@56:56
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=62
scope.5.semanticHash=83c710d9acee46f8
scope.6.id=function:anonymous@65:65
scope.6.kind=function
scope.6.startLine=65
scope.6.endLine=89
scope.6.semanticHash=ebf909140d536d13
scope.7.id=function:anonymous@92:92
scope.7.kind=function
scope.7.startLine=92
scope.7.endLine=136
scope.7.semanticHash=6a0007c9e3577b67
scope.8.id=function:anonymous@139:139
scope.8.kind=function
scope.8.startLine=139
scope.8.endLine=163
scope.8.semanticHash=b1ae2ca363a472d3
scope.9.id=function:anonymous@166:166
scope.9.kind=function
scope.9.startLine=166
scope.9.endLine=168
scope.9.semanticHash=31b8a4007edc4314
scope.10.id=function:anonymous@169:169
scope.10.kind=function
scope.10.startLine=169
scope.10.endLine=177
scope.10.semanticHash=57bcba86e424711e
scope.11.id=function:anonymous@180:180
scope.11.kind=function
scope.11.startLine=180
scope.11.endLine=185
scope.11.semanticHash=33d86f220c5a2a8f
scope.12.id=function:anonymous@186:186
scope.12.kind=function
scope.12.startLine=186
scope.12.endLine=195
scope.12.semanticHash=a49b43f8c4804d85
scope.13.id=function:anonymous@198:198
scope.13.kind=function
scope.13.startLine=198
scope.13.endLine=205
scope.13.semanticHash=729e04ebe00244bd
scope.14.id=function:_handle_set_status:229
scope.14.kind=function
scope.14.startLine=229
scope.14.endLine=239
scope.14.semanticHash=603142f41a294b4e
scope.15.id=function:_handle_deity:241
scope.15.kind=function
scope.15.startLine=241
scope.15.endLine=250
scope.15.semanticHash=c6a1fb91387513f5
scope.16.id=function:_handle_log:252
scope.16.kind=function
scope.16.startLine=252
scope.16.endLine=259
scope.16.semanticHash=6dd7046d4f069335
scope.17.id=function:_handle_place_mine_here:261
scope.17.kind=function
scope.17.startLine=261
scope.17.endLine=285
scope.17.semanticHash=dca6334a7e99a857
scope.18.id=function:post_effects.get_target_spec:293
scope.18.kind=function
scope.18.startLine=293
scope.18.endLine=295
scope.18.semanticHash=21c477587f0f7f72
scope.19.id=function:post_effects.target_item_ids:297
scope.19.kind=function
scope.19.startLine=297
scope.19.endLine=299
scope.19.semanticHash=ca860ab0b2c2ccba
scope.20.id=function:post_effects.apply_target:301
scope.20.kind=function
scope.20.startLine=301
scope.20.endLine=308
scope.20.semanticHash=c3846984a2917a21
scope.21.id=function:post_effects.apply_post:310
scope.21.kind=function
scope.21.startLine=310
scope.21.endLine=315
scope.21.semanticHash=7aa99a20c7a05eac
]]
