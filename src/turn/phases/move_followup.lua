local control = require("src.player.control")
local intent_dispatcher = require("src.turn.output.intent_dispatcher")
local landing_visual_hold = require("src.state.visual_hold")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local dirty_tracker = require("src.state.dirty_tracker")

-- Late binding: tests may reload src.rules.market, so we require it on each call
-- to avoid holding a stale reference.
local function _market()
  return require("src.rules.market")
end

local move_followup = {}

local function _clear_pending_flag(game)
  if not (game and game.turn) then
    return
  end
  if game.turn.move_followup_pending == true then
    game.turn.move_followup_pending = false
    dirty_tracker.mark(game.dirty, "turn")
  end
end

local function _resolve_player(game, args)
  local player = args.player
  if player then
    return player
  end
  local player_id = args.player_id
  assert(player_id ~= nil, "missing move followup player_id")
  return assert(game:find_player_by_id(player_id), "missing move followup player: " .. tostring(player_id))
end

local function _build_resume_move_args(player, raw_total, interrupt, continue_key)
  return {
    player = player,
    raw_total = raw_total,
    [continue_key] = true,
    remaining_steps = interrupt.remaining_steps,
    facing = interrupt.facing,
    branch_parity = interrupt.branch_parity,
    entered_inner = interrupt.entered_inner,
  }
end

local function _resolve_auto_play_market(game, player, raw_total, interrupt)
  _market().auto.execute(game, player)
  if interrupt.remaining_steps and interrupt.remaining_steps > 0 then
    return "move", _build_resume_move_args(player, raw_total, interrupt, "continue_from_market")
  end
  return nil
end

local function _resolve_choice_wait(game, player, raw_total, interrupt, spec)
  intent_dispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })
  return "wait_choice", {
    next_state = "move",
    next_args = _build_resume_move_args(player, raw_total, interrupt, "continue_from_market"),
  }
end

local function _resolve_human_market(game, player, raw_total, interrupt)
  local spec, intent = _market().choice.build(player, game)
  if spec then
    return _resolve_choice_wait(game, player, raw_total, interrupt, spec)
  end
  if intent then
    intent_dispatcher.dispatch(game, intent)
  end
  return nil
end

local function _resolve_market_interrupt_wait(game, player, raw_total, interrupt)
  if control.is_computer_controlled(player) then
    return _resolve_auto_play_market(game, player, raw_total, interrupt)
  end
  return _resolve_human_market(game, player, raw_total, interrupt)
end

local function _handle_resume_turn_move(game, args)
  local player = _resolve_player(game, args)
  local move_result = assert(args.move_result, "missing move followup move_result")
  local raw_total = args.raw_total
  game.last_turn.move_result = move_result

  if move_result.market_interrupt then
    local interrupt = move_result.market_interrupt
    local next_state, next_args = _resolve_market_interrupt_wait(game, player, raw_total, interrupt)
    if next_state ~= nil then
      return next_state, next_args
    end
  end

  landing_visual_hold.start(game)
  return "landing", {
    player = player,
    move_result = move_result,
  }
end

local function _handle_resolve_landing(game, args)
  local player = _resolve_player(game, args)
  local move_result = args.move_result
  landing_visual_hold.start(game)
  return "landing", {
    player = player,
    move_result = move_result,
  }
end

local function _handle_apply_location_effects(game, args)
  local log_entries = args.log_entries or {}
  for _, entry in ipairs(log_entries) do
    event_feed.publish(game, {
      kind = event_kinds.move_followup,
      text = entry,
      tip = true,
    })
  end
  local effects = args.effects or {}
  for _, entry in ipairs(effects) do
    local player = assert(game:find_player_by_id(entry.player_id), "missing move followup effect player")
    game:player_apply_location_effect(player, entry.effect)
  end
  return args.next_state, args.next_args
end

local _MOVE_FOLLOWUP_HANDLERS = {
  resume_turn_move = _handle_resume_turn_move,
  resolve_landing = _handle_resolve_landing,
  apply_location_effects = _handle_apply_location_effects,
}

function move_followup.run(turn_mgr, args)
  local game = assert(turn_mgr and turn_mgr.game, "missing move followup game")
  args = args or {}
  _clear_pending_flag(game)

  local mode = args.mode
  local handler = _MOVE_FOLLOWUP_HANDLERS[mode]
  if handler == nil then
    error("unknown move followup mode: " .. tostring(mode))
  end
  return handler(game, args)
end

return move_followup

--[[ mutate4lua-manifest
version=4
projectHash=7cc3b9089cffb742
scope.0.id=chunk:src/turn/phases/move_followup.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=150
scope.0.semanticHash=68ebbb3501e3db20
scope.1.id=function:_market
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=361867a8848129cb
scope.2.id=function:_clear_pending_flag
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=24
scope.2.semanticHash=4061ff26cbb88ca4
scope.3.id=function:_resolve_player
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=34
scope.3.semanticHash=894af8dcc07fafc3
scope.4.id=function:_build_resume_move_args
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=46
scope.4.semanticHash=1ab854591cd187d7
scope.5.id=function:_resolve_auto_play_market
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=54
scope.5.semanticHash=9138524a368e075e
scope.6.id=function:_resolve_choice_wait
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=62
scope.6.semanticHash=b8da166f6b23a42f
scope.7.id=function:_resolve_human_market
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=73
scope.7.semanticHash=110aba94e66d7ac7
scope.8.id=function:_resolve_market_interrupt_wait
scope.8.kind=function
scope.8.startLine=75
scope.8.endLine=80
scope.8.semanticHash=050742fb84f40bae
scope.9.id=function:_handle_resume_turn_move
scope.9.kind=function
scope.9.startLine=82
scope.9.endLine=101
scope.9.semanticHash=f7ef135e62852d56
scope.10.id=function:_handle_resolve_landing
scope.10.kind=function
scope.10.startLine=103
scope.10.endLine=111
scope.10.semanticHash=1a48a6ed9381e2cf
scope.11.id=function:_handle_apply_location_effects
scope.11.kind=function
scope.11.startLine=113
scope.11.endLine=128
scope.11.semanticHash=6d8751219924cd0c
scope.12.id=function:move_followup.run
scope.12.kind=function
scope.12.startLine=136
scope.12.endLine=147
scope.12.semanticHash=2132660c44518910
]]
