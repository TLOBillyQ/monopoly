local auto_play_port = require("src.rules.ports.auto_play")
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
  if auto_play_port.is_auto_player(game, player) then
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

function move_followup.run(turn_mgr, args)
  local game = assert(turn_mgr and turn_mgr.game, "missing move followup game")
  args = args or {}
  _clear_pending_flag(game)

  local mode = args.mode
  if mode == "resume_turn_move" then
    return _handle_resume_turn_move(game, args)
  end
  if mode == "resolve_landing" then
    return _handle_resolve_landing(game, args)
  end
  if mode == "apply_location_effects" then
    return _handle_apply_location_effects(game, args)
  end
  error("unknown move followup mode: " .. tostring(mode))
end

return move_followup

--[[ mutate4lua-manifest
version=2
projectHash=892143e19f88568b
scope.0.id=chunk:src/turn/phases/move_followup.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=149
scope.0.semanticHash=6f8ae19ee5fbd92f
scope.0.lastMutatedAt=2026-05-30T04:00:21Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=13
scope.0.lastMutationKilled=13
scope.1.id=function:_market:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=27b97988b8220f2b
scope.1.lastMutatedAt=2026-05-30T04:00:21Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_clear_pending_flag:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=24
scope.2.semanticHash=f944ffae682d46d8
scope.2.lastMutatedAt=2026-05-30T04:00:21Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:_resolve_player:26
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=34
scope.3.semanticHash=0f10f82d7d1255dc
scope.3.lastMutatedAt=2026-05-30T04:00:21Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:_build_resume_move_args:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=46
scope.4.semanticHash=d094916a069fe50a
scope.4.lastMutatedAt=2026-05-30T04:00:21Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_resolve_auto_play_market:48
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=54
scope.5.semanticHash=113dc17dd197975f
scope.5.lastMutatedAt=2026-05-30T04:00:21Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=7
scope.5.lastMutationKilled=7
scope.6.id=function:_resolve_choice_wait:56
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=62
scope.6.semanticHash=5b5ad9fcd5a88a47
scope.6.lastMutatedAt=2026-05-30T04:00:21Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=4
scope.6.lastMutationKilled=4
scope.7.id=function:_resolve_human_market:64
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=73
scope.7.semanticHash=591f9433c591ede9
scope.7.lastMutatedAt=2026-05-30T04:00:21Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=4
scope.7.lastMutationKilled=4
scope.8.id=function:_resolve_market_interrupt_wait:75
scope.8.kind=function
scope.8.startLine=75
scope.8.endLine=80
scope.8.semanticHash=bcbb0db4124d7f2c
scope.8.lastMutatedAt=2026-05-30T04:00:21Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=3
scope.8.lastMutationKilled=3
scope.9.id=function:_handle_resume_turn_move:82
scope.9.kind=function
scope.9.startLine=82
scope.9.endLine=101
scope.9.semanticHash=72e23c6388d82681
scope.9.lastMutatedAt=2026-05-30T04:00:21Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=6
scope.9.lastMutationKilled=6
scope.10.id=function:_handle_resolve_landing:103
scope.10.kind=function
scope.10.startLine=103
scope.10.endLine=111
scope.10.semanticHash=a781c2c6d4dd2493
scope.10.lastMutatedAt=2026-05-30T04:00:21Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=3
scope.10.lastMutationKilled=3
scope.11.id=function:move_followup.run:130
scope.11.kind=function
scope.11.startLine=130
scope.11.endLine=146
scope.11.semanticHash=4fd2759071afe51e
scope.11.lastMutatedAt=2026-05-30T04:00:21Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=13
scope.11.lastMutationKilled=13
]]
