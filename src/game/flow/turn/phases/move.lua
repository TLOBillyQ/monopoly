local movement = require("src.rules.movement")
local vehicle_feature = require("src.rules.vehicle")
local move_followup = require("src.game.flow.turn.phases.move_followup")

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

local function _apply_dice_multiplier(game, player, total, raw_total)
  local pending_multiplier = player.status.pending_dice_multiplier
  if not pending_multiplier or pending_multiplier <= 1 then
    return total
  end
  if raw_total == nil or total ~= raw_total then
    return total
  end
  local new_total = raw_total * pending_multiplier
  if game.set_player_status then
    game:set_player_status(player, "pending_dice_multiplier", 1)
  else
    player.status.pending_dice_multiplier = 1
  end
  if game.last_turn then
    game.last_turn.total = new_total
  end
  return new_total
end

local function _build_move_opts(args, raw_total)
  local move_opts = { branch_parity = raw_total }
  if args.continue_from_market or args.continue_from_steal then
    move_opts.direction = args.facing
    move_opts.branch_parity = args.branch_parity
    move_opts.entered_inner = args.entered_inner
  end
  return move_opts
end

local function _resolve_move_total(args, raw_total)
  if args.continue_from_market or args.continue_from_steal then
    return args.remaining_steps
  end
  return raw_total
end

local function _build_move_anim_data(game, player, start_index, move_result)
  local seq = (game.turn.move_anim_seq or 0) + 1
  game.turn.move_anim_seq = seq
  return {
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
end

local function _queue_move_anim(game, anim_data)
  game.turn.move_anim = anim_data
  game.dirty.turn = true
  game.dirty.any = true
end

local function _build_wait_move_anim_result(player, raw_total, move_result)
  return "wait_move_anim", {
    next_state = "move_followup",
    next_args = _build_move_args(player, raw_total, {
      mode = "resume_turn_move",
      move_result = move_result,
      raw_total = raw_total,
    }),
  }
end

local function _run_move_followup(turn_mgr, player, raw_total, move_result)
  return move_followup.run(turn_mgr, {
    mode = "resume_turn_move",
    player = player,
    raw_total = raw_total,
    move_result = move_result,
  })
end

local function _perform_move(turn_mgr, game, player, total, move_opts)
  local start_index = player.position
  local move_result = movement.move(turn_mgr.game, player, total, move_opts)
  local anim_gate_port = assert(game.anim_gate_port, "missing anim_gate_port")
  if anim_gate_port.wait_move_anim == true then
    local anim_data = _build_move_anim_data(game, player, start_index, move_result)
    _queue_move_anim(game, anim_data)
    return _build_wait_move_anim_result(player, move_opts.branch_parity, move_result)
  end
  return _run_move_followup(turn_mgr, player, move_opts.branch_parity, move_result)
end

local function _phase_move(turn_mgr, args)
  local player = args.player
  local raw_total = args.raw_total
  assert(turn_mgr.game ~= nil, "missing game")
  local move_result = args.move_result
  local game = turn_mgr.game

  local total = _apply_dice_multiplier(game, player, args.total, raw_total)
  local move_opts = _build_move_opts(args, raw_total)
  total = _resolve_move_total(args, total)

  if not move_result then
    return _perform_move(turn_mgr, game, player, total, move_opts)
  end

  return _run_move_followup(turn_mgr, player, raw_total, move_result)
end

return _phase_move
