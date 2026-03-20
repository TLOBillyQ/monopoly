local steal = require("src.rules.items.steal")
local market_service = require("src.rules.market")
local intent_dispatcher = require("src.turn.output.intent_dispatcher")
local landing_visual_hold = require("src.state.state_access.landing_visual_hold")
local logger = require("src.core.utils.logger")

local move_followup = {}

local function _clear_pending_flag(game)
  if not (game and game.turn) then
    return
  end
  if game.turn.move_followup_pending == true then
    game.turn.move_followup_pending = false
    game.dirty.turn = true
    game.dirty.any = true
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

local function _resolve_steal_interrupt_wait(game, player, raw_total, interrupt)
  local res = steal.handle_pass_players(game, player, interrupt.encountered_ids or {})
  if res and res.intent then
    intent_dispatcher.dispatch(game, res.intent)
  end
  if res and res.waiting then
    return "wait_choice", {
      next_state = "move",
      next_args = _build_resume_move_args(player, raw_total, interrupt, "continue_from_steal"),
    }
  end
  if interrupt.remaining_steps and interrupt.remaining_steps > 0 then
    return "move", _build_resume_move_args(player, raw_total, interrupt, "continue_from_steal")
  end
  return nil
end

local function _resolve_market_interrupt_wait(game, player, raw_total, interrupt)
  local spec, intent = market_service.choice.build(player, game)
  if spec then
    intent_dispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })
    return "wait_choice", {
      next_state = "move",
      next_args = _build_resume_move_args(player, raw_total, interrupt, "continue_from_market"),
    }
  end
  if intent then
    intent_dispatcher.dispatch(game, intent)
  end
  return nil
end

local function _handle_resume_turn_move(game, args)
  local player = _resolve_player(game, args)
  local move_result = assert(args.move_result, "missing move followup move_result")
  local raw_total = args.raw_total
  game.last_turn.move_result = move_result

  if move_result.steal_interrupt then
    local interrupt = move_result.steal_interrupt
    local next_state, next_args = _resolve_steal_interrupt_wait(game, player, raw_total, interrupt)
    if next_state ~= nil then
      return next_state, next_args
    end
    move_result.encountered_players = {}
  end

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
    logger.event(entry)
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
