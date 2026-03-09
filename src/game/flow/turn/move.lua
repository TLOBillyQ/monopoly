local movement = require("src.game.systems.movement")
local vehicle_feature = require("src.game.systems.vehicle")
local move_followup = require("src.game.flow.turn.move_followup")

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

    local anim_gate_port = assert(game.anim_gate_port, "missing anim_gate_port")
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
        next_state = "move_followup",
        next_args = _build_move_args(player, raw_total, {
          mode = "resume_turn_move",
          move_result = move_result,
          raw_total = raw_total,
        }),
      }
    end
    return move_followup.run(turn_mgr, {
      mode = "resume_turn_move",
      player = player,
      raw_total = raw_total,
      move_result = move_result,
    })
  end

  return move_followup.run(turn_mgr, {
    mode = "resume_turn_move",
    player = player,
    raw_total = raw_total,
    move_result = move_result,
  })
end

return _phase_move
