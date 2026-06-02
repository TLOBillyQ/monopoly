local constants = require("src.config.content.constants")
local timing = require("src.config.gameplay.timing")
local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.number")
local action_anim_port = require("src.foundation.ports.action_anim")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local runtime_ports = require("src.foundation.ports.runtime_ports")

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
version=2
projectHash=627df985e4b07225
scope.0.id=chunk:src/rules/movement_events.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=146
scope.0.semanticHash=17f31e0d625d54b2
scope.0.lastMutatedAt=2026-06-02T03:41:44Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=9
scope.0.lastMutationKilled=9
scope.1.id=function:_build_feed_event:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=24
scope.1.semanticHash=6eebdae5f7a45ef6
scope.1.lastMutatedAt=2026-06-02T03:41:44Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:_emit_text:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=39
scope.2.semanticHash=ad66b45155249137
scope.2.lastMutatedAt=2026-06-02T03:41:44Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=8
scope.2.lastMutationKilled=8
scope.3.id=function:events.emit_roadblock_hit:41
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=54
scope.3.semanticHash=d4c256e4786fd708
scope.3.lastMutatedAt=2026-06-02T03:41:44Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:events.emit_market_interrupt:56
scope.4.kind=function
scope.4.startLine=56
scope.4.endLine=63
scope.4.semanticHash=8b4227175c552037
scope.4.lastMutatedAt=2026-06-02T03:41:44Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_emit_pass_start_reward:65
scope.5.kind=function
scope.5.startLine=65
scope.5.endLine=82
scope.5.semanticHash=e5ce044a0ad73cbb
scope.5.lastMutatedAt=2026-06-02T03:41:44Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=9
scope.5.lastMutationKilled=9
scope.6.id=function:_resolve_pass_start_override:84
scope.6.kind=function
scope.6.startLine=84
scope.6.endLine=91
scope.6.semanticHash=808b5e476ca6dd2d
scope.6.lastMutatedAt=2026-06-02T03:41:44Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:_cap_pass_start_hold:93
scope.7.kind=function
scope.7.startLine=93
scope.7.endLine=99
scope.7.semanticHash=df57e3008c2841a2
scope.7.lastMutatedAt=2026-06-02T03:41:44Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=2
scope.7.lastMutationKilled=2
scope.8.id=function:_resolve_default_pass_start_hold:101
scope.8.kind=function
scope.8.startLine=101
scope.8.endLine=109
scope.8.semanticHash=3b4cc48fcc920f70
scope.8.lastMutatedAt=2026-06-02T03:41:44Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=9
scope.8.lastMutationKilled=9
scope.9.id=function:_resolve_pass_start_hold:111
scope.9.kind=function
scope.9.startLine=111
scope.9.endLine=117
scope.9.semanticHash=c5e4405160ecbd86
scope.9.lastMutatedAt=2026-06-02T03:41:44Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=3
scope.9.lastMutationKilled=3
scope.10.id=function:anonymous@128:128
scope.10.kind=function
scope.10.startLine=128
scope.10.endLine=130
scope.10.semanticHash=1657e0f7425f6024
scope.10.lastMutatedAt=2026-06-02T03:41:44Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=no_sites
scope.10.lastMutationSites=0
scope.10.lastMutationKilled=0
scope.11.id=function:_schedule_pass_start_reward:119
scope.11.kind=function
scope.11.startLine=119
scope.11.endLine=131
scope.11.semanticHash=1e63fe1160de3ba8
scope.11.lastMutatedAt=2026-06-02T03:41:44Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=7
scope.11.lastMutationKilled=7
scope.12.id=function:events.emit_move_completed:133
scope.12.kind=function
scope.12.startLine=133
scope.12.endLine=143
scope.12.semanticHash=873bbfcf2d3ca97c
scope.12.lastMutatedAt=2026-06-02T03:41:44Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=2
scope.12.lastMutationKilled=2
]]
