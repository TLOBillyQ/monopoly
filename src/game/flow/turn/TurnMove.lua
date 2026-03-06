local steal = require("src.game.systems.items.ItemSteal")
local movement = require("src.game.systems.movement.Movement")
local market_service = require("src.game.systems.market.MarketService")
local intent_dispatcher = require("src.game.flow.intent.IntentDispatcher")
local vehicle_feature = require("src.game.systems.vehicle.VehicleFeature")

local function _build_move_args(player, raw_total, extra)
  local out = {
    player = player,
    raw_total = raw_total,
  }
  if not extra then
    return out
  end
  for key, value in pairs(extra) do
    out[key] = value
  end
  return out
end

local function _build_interrupt_args(player, raw_total, interrupt, source_flag)
  return _build_move_args(player, raw_total, {
    [source_flag] = true,
    remaining_steps = interrupt.remaining_steps,
    facing = interrupt.facing,
    branch_parity = interrupt.branch_parity,
  })
end

local function _phase_move(turn_mgr, args)
  local player = args.player
  local total = args.total
  local raw_total = args.raw_total
  assert(turn_mgr.game ~= nil, "missing game")
  local move_result = args.move_result
  local game = turn_mgr.game

  local pending_multiplier = player.status.pending_dice_multiplier
  if pending_multiplier and pending_multiplier > 1 then
    if raw_total ~= nil and total == raw_total then
      total = raw_total * pending_multiplier
    end
    game:set_player_status(player, "pending_dice_multiplier", 1)
    if game.last_turn then
      game.last_turn.total = total
    end
  end

  local move_opts = { branch_parity = raw_total }
  if args.continue_from_market or args.continue_from_steal then
    total = args.remaining_steps
    move_opts.direction = args.facing
    move_opts.branch_parity = args.branch_parity
  end

  if not move_result then
    local start_index = player.position
    move_result = movement.move(turn_mgr.game, player, total, move_opts)
    turn_mgr.game.last_turn.move_result = move_result

    local anim_gate_port = assert(game.anim_gate_port or game["ui_port"], "missing anim_gate_port")
    if anim_gate_port.wait_move_anim == true then
      local seq = (game.turn.move_anim_seq or 0) + 1
      game.turn.move_anim_seq = seq
      game.turn.move_anim = {
        seq = seq,
        player_id = player.id,
        from_index = start_index,
        to_index = player.position,
        visited = move_result.visited,
        steps = move_result.steps,
        vehicle_id = vehicle_feature.resolve_seat_id(player.seat_id),
        stopped_on_roadblock = move_result.stopped_on_roadblock == true,
        market_interrupt = move_result.market_interrupt and true or false,
        steal_interrupt = move_result.steal_interrupt and true or false,
      }
      game.dirty.turn = true
      game.dirty.any = true
      return "wait_move_anim", {
        next_state = "move",
        next_args = _build_move_args(player, raw_total, {
          total = total,
          move_result = move_result,
        }),
      }
    end
  else
    turn_mgr.game.last_turn.move_result = move_result
  end

  if move_result.stopped_on_roadblock then
    local stay = player.status.stay_turns or 0
    if stay < 1 then
      turn_mgr.game:set_player_status(player, "stay_turns", 1)
    end
  end

  if move_result.steal_interrupt then
    local interrupt = move_result.steal_interrupt
    local res = steal.handle_pass_players(turn_mgr.game, player, interrupt.encountered_ids or {})
    if res and res.intent then
      intent_dispatcher.dispatch(turn_mgr.game, res.intent)
    end
    if res and res.waiting then
      return "wait_choice", {
        next_state = "move",
        next_args = _build_interrupt_args(player, raw_total, interrupt, "continue_from_steal"),
      }
    end
    if interrupt.remaining_steps and interrupt.remaining_steps > 0 then
      return "move", _build_interrupt_args(player, raw_total, interrupt, "continue_from_steal")
    end
    move_result.encountered_players = {}
  end

  if move_result.market_interrupt then
    local spec, intent = market_service.choice.build(player, turn_mgr.game)
    if spec then
      intent_dispatcher.dispatch(turn_mgr.game, { kind = "need_choice", choice_spec = spec })
      return "wait_choice", {
        next_state = "move",
        next_args = _build_interrupt_args(
          player,
          raw_total,
          move_result.market_interrupt,
          "continue_from_market"
        ),
      }
    end
    if intent then
      intent_dispatcher.dispatch(turn_mgr.game, intent)
    end
  end

  return "landing", { player = player, move_result = move_result }
end

return _phase_move
