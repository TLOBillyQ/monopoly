local constants = require("src.config.content.constants")
local timing = require("src.config.gameplay.timing")
local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.number")
local action_anim_port = require("src.foundation.ports.action_anim")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local achievement_progress = require("src.rules.ports.achievement_progress")

local events = {}

local _emit_event = monopoly_event.emit
local _other_action_prompt_text = "玩家正在行动"

local function _build_feed_event(ef_kind, payload, opts)
  local event = { kind = ef_kind, text = payload.text }
  if not (opts and opts.show_tip == true) then
    event.tip = false
  end
  if opts and opts.tip_dedupe_key ~= nil then
    event.tip_dedupe_key = opts.tip_dedupe_key
  end
  return event
end

local function _emit_text(game, mono_kind, ef_kind, payload, opts)
  _emit_event(mono_kind, payload)
  if not game then
    return
  end
  if not ef_kind then
    return
  end
  if type(payload.text) ~= "string" then
    return
  end
  local event = _build_feed_event(ef_kind, payload, opts)
  event_feed.publish(game, event)
end

function events.emit_roadblock_hit(game, player, current, tile)
  action_anim_port.queue(game, {
    kind = "roadblock_trigger",
    player_id = player.id,
    tile_index = current,
    duration = timing.action_anim_default_seconds or 1.0,
  })
  _emit_text(game, monopoly_event.movement.roadblock_hit, event_kinds.roadblock_triggered, {
    player = player,
    tile = tile,
    text = player.name .. " 触发路障，停在 " .. tile.name,
    prompt_text = _other_action_prompt_text,
  }, { show_tip = true })
end

function events.emit_market_interrupt(ctx, remaining)
  _emit_text(ctx.game, monopoly_event.movement.market_interrupt, event_kinds.market_entered, {
    player = ctx.player,
    remaining_steps = remaining,
    text = ctx.player.name .. " 经过黑市，剩余 " .. number_utils.format_integer_part(remaining) .. " 步",
    prompt_text = _other_action_prompt_text,
  })
end

local function _emit_pass_start_reward(ctx)
  local bonus = ctx.pass_start * constants.pass_start_bonus
  if ctx.game:player_has_deity(ctx.player, "rich") then
    bonus = bonus * 2
  end
  ctx.game:add_player_cash(ctx.player, bonus)
  achievement_progress.cash_received(ctx.game, ctx.player, bonus)
  local turn_count = (ctx.game and ctx.game.turn and ctx.game.turn.turn_count) or 0
  _emit_text(ctx.game, monopoly_event.movement.passed_start, event_kinds.passed_start, {
    player = ctx.player,
    count = ctx.pass_start,
    bonus = bonus,
    text = ctx.player.name .. " 经过起点，获得 " .. number_utils.format_integer_part(bonus) .. " 金币",
    prompt_text = _other_action_prompt_text,
  }, {
    show_tip = true,
    tip_dedupe_key = "passed_start:" .. tostring(ctx.player.id) .. ":" .. tostring(turn_count),
  })
end

local function _resolve_pass_start_override(ctx)
  local opts = ctx.opts or {}
  if opts.pass_start_hold_seconds == nil then
    return nil
  end
  local override = opts.pass_start_hold_seconds
  return math.max(0, override)
end

local function _cap_pass_start_hold(hold)
  local cap = timing.pass_start_hold_max_seconds
  if not cap then
    return hold
  end
  return math.min(hold, cap)
end

local function _resolve_default_pass_start_hold(ctx)
  local first_step = ctx.pass_start_at_steps[1]
  if not first_step then
    return 0
  end
  local per = timing.pass_start_hold_seconds_per_step or 0
  local hold = _cap_pass_start_hold(first_step * per)
  return hold + (timing.pass_start_hold_tail_seconds or 0)
end

local function _resolve_pass_start_hold(ctx)
  local override = _resolve_pass_start_override(ctx)
  if override ~= nil then
    return override
  end
  return _resolve_default_pass_start_hold(ctx)
end

local function _schedule_pass_start_reward(ctx)
  if ctx.pass_start < 1 then
    return
  end
  local hold = _resolve_pass_start_hold(ctx)
  if hold <= 0 then
    _emit_pass_start_reward(ctx)
    return
  end
  runtime_ports.schedule(hold, function()
    _emit_pass_start_reward(ctx)
  end)
end

function events.emit_move_completed(ctx, landing_tile)
  _emit_text(ctx.game, monopoly_event.movement.moved, event_kinds.move_completed, {
    player = ctx.player,
    from_tile = ctx.start_tile,
    to_tile = landing_tile,
    steps = ctx.steps,
    text = ctx.player.name .. " 从 " .. ctx.start_tile.name .. " 移动到 " .. landing_tile.name,
    prompt_text = _other_action_prompt_text,
  })
  _schedule_pass_start_reward(ctx)
end

return events

--[[ mutate4lua-manifest
version=4
projectHash=fbc1d0321bc3d70c
scope.0.id=chunk:src/rules/movement_events.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=148
scope.0.semanticHash=ee6158ca202b48ee
scope.1.id=function:_build_feed_event
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=25
scope.1.semanticHash=0d794f0ead30db64
scope.2.id=function:_emit_text
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=40
scope.2.semanticHash=1dd225141aa7478d
scope.3.id=function:events.emit_roadblock_hit
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=55
scope.3.semanticHash=18c455f799701f3c
scope.4.id=function:events.emit_market_interrupt
scope.4.kind=function
scope.4.startLine=57
scope.4.endLine=64
scope.4.semanticHash=4ff9aa26aecb0f9b
scope.5.id=function:_emit_pass_start_reward
scope.5.kind=function
scope.5.startLine=66
scope.5.endLine=84
scope.5.semanticHash=48dc0ff48d6b0240
scope.6.id=function:_resolve_pass_start_override
scope.6.kind=function
scope.6.startLine=86
scope.6.endLine=93
scope.6.semanticHash=869931529026cf2f
scope.7.id=function:_cap_pass_start_hold
scope.7.kind=function
scope.7.startLine=95
scope.7.endLine=101
scope.7.semanticHash=263f181e27a813d9
scope.8.id=function:_resolve_default_pass_start_hold
scope.8.kind=function
scope.8.startLine=103
scope.8.endLine=111
scope.8.semanticHash=b33f959c50443598
scope.9.id=function:_resolve_pass_start_hold
scope.9.kind=function
scope.9.startLine=113
scope.9.endLine=119
scope.9.semanticHash=c4b6c83ac8f7bb13
scope.10.id=function:_schedule_pass_start_reward
scope.10.kind=function
scope.10.startLine=121
scope.10.endLine=133
scope.10.semanticHash=3c7bb323f3927763
scope.11.id=function:<anonymous>
scope.11.kind=function
scope.11.startLine=130
scope.11.endLine=132
scope.11.semanticHash=600a75ce96a391b3
scope.12.id=function:events.emit_move_completed
scope.12.kind=function
scope.12.startLine=135
scope.12.endLine=145
scope.12.semanticHash=47ae459e9614e413
]]
